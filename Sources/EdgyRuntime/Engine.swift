import EdgyCore
import Foundation

/// Tells the engine which app is frontmost. The live implementation lives in EdgyApp.
public protocol FrontmostAppProviding: AnyObject, Sendable {
  var frontmostBundleID: String? { get }
}

/// A snapshot of what the engine is doing, for the menu and the settings window.
public struct EngineStatus: Equatable, Sendable {
  /// Touch input started and not stopped.
  public var running: Bool
  public var paused: Bool
  /// When a timed pause ends, if the pauser said so.
  public var pausedUntil: Date?
  /// `AppSettings.enabled` of the applied config.
  public var enabled: Bool
  /// Connected multitouch devices, sorted by id.
  public var devices: [TouchDeviceInfo]
  /// Why the last `start()` failed; cleared by a successful start.
  public var lastStartError: String?
  /// Test Mode is on (`Engine.setTestMode(_:)`; never persisted).
  public var testMode: Bool

  public init(
    running: Bool = false, paused: Bool = false, pausedUntil: Date? = nil, enabled: Bool = true,
    devices: [TouchDeviceInfo] = [], lastStartError: String? = nil, testMode: Bool = false
  ) {
    self.testMode = testMode
    self.running = running
    self.paused = paused
    self.pausedUntil = pausedUntil
    self.enabled = enabled
    self.devices = devices
    self.lastStartError = lastStartError
  }

  public var deviceCount: Int { devices.count }
  public var deviceKinds: Set<TouchDeviceInfo.Kind> { Set(devices.map(\.kind)) }
  /// A built-in or external trackpad is connected.
  public var hasTrackpad: Bool { devices.contains { $0.kind == .builtInTrackpad || $0.kind == .externalTrackpad } }
  /// Gestures are being turned into actions right now.
  public var isActive: Bool { running && !paused && enabled }
}

/// Wires touch input → gesture recognizer → router → actions, and drives the pointer guard.
///
/// All mutable state, the recognizer, the router and the pointer guard are touched only on `queue`.
/// Frames from the touch source hop onto `queue`; public methods run on it synchronously.
public final class Engine: @unchecked Sendable {
  private let touchSource: TouchSource
  private let recognizer: GestureRecognizing
  private let router: Router
  private let pointerGuard: PointerGuarding
  private let typing: TypingActivitySource
  private let frontmost: FrontmostAppProviding
  private let logger: EdgyLogging
  private let queue: DispatchQueue
  private let queueKey = DispatchSpecificKey<UUID>()
  private let queueToken = UUID()

  // Confined to `queue`.
  private var config: EdgyConfig
  private var devices: [UInt64: TouchDeviceInfo] = [:]
  private var running = false
  private var paused = false
  private var guardEngaged = false
  private var lastGuardEngage: Double?
  private var pausedUntil: Date?
  private var lastStartError: String?
  private var lastStatus: EngineStatus?
  private var statusHandler: (@Sendable (EngineStatus) -> Void)?
  /// Frontmost app of the last processed frame (`.none` before the first one).
  private var lastFrontmost: String?? = .none
  private var testMode = false
  /// Internal (not private) so tests can see it stays empty without observers.
  var feed = LiveFeedState()

  /// The touch mirror gets at most one frame per device per this many seconds (60 Hz), measured
  /// on the device clock. Decisions are never throttled.
  public static let feedTouchInterval: TimeInterval = 1.0 / 60

  public init(
    touchSource: TouchSource, recognizer: GestureRecognizing, actions: ActionPerforming,
    pointerGuard: PointerGuarding, typing: TypingActivitySource, frontmost: FrontmostAppProviding,
    config: EdgyConfig, logger: EdgyLogging, queue: DispatchQueue
  ) {
    self.touchSource = touchSource
    self.recognizer = recognizer
    self.router = Router(actions: actions, logger: logger)
    self.pointerGuard = pointerGuard
    self.typing = typing
    self.frontmost = frontmost
    self.config = config
    self.logger = logger
    self.queue = queue
    queue.setSpecific(key: queueKey, value: queueToken)
  }

  public var isPaused: Bool { onQueue { paused } }

  public var status: EngineStatus { onQueue { makeStatus() } }

  /// Calls `handler` on the engine queue whenever `status` changes (start, stop, pause, resume,
  /// device hot-plug, enabled toggled). Replaces any previous handler.
  public func onStatusChange(_ handler: @escaping @Sendable (EngineStatus) -> Void) {
    onQueue {
      statusHandler = handler
      lastStatus = makeStatus()
    }
  }

  public func start() throws {
    let alreadyRunning = onQueue { () -> Bool in
      if running { return true }
      setDevices(touchSource.devices)
      running = true
      return false
    }
    guard !alreadyRunning else { return }
    do {
      try touchSource.start(
        onFrame: { [weak self] frame in
          guard let self else { return }
          self.queue.async { self.handle(frame) }
        },
        onDevicesChanged: { [weak self] devices in
          guard let self else { return }
          self.queue.async { self.setDevices(devices) }
        })
    } catch {
      onQueue {
        running = false
        lastStartError = String(describing: error)
        publishStatus()
      }
      throw error
    }
    onQueue {
      lastStartError = nil
      publishStatus()
    }
  }

  public func stop() {
    touchSource.stop()
    onQueue {
      running = false
      quiesce()
      publishStatus()
    }
  }

  /// Stops turning gestures into actions. `until` is recorded for `status` only: the caller owns
  /// the timer that calls `resume()`.
  public func pause(until: Date? = nil) {
    onQueue {
      paused = true
      pausedUntil = until
      quiesce()
      publishStatus()
    }
  }

  public func resume() {
    onQueue {
      paused = false
      pausedUntil = nil
      publishStatus()
    }
  }

  /// Adopt a new config: in-flight gestures are dropped and the next frame uses the new context.
  public func apply(_ config: EdgyConfig) {
    onQueue {
      self.config = config
      router.actions.apply(settings: config.app)
      quiesce()
      publishStatus()
    }
  }

  // MARK: Test Mode

  public var isTestMode: Bool { onQueue { testMode } }

  /// Test Mode: gestures are recognized and routed as usual but no action runs (holds press and
  /// release nothing); each would-be action gives the "caught" haptic and a `wouldRun` decision in
  /// the feed. Not persisted. Switching either way drops in-flight gestures, like a config apply:
  /// a hold already pressed is released, a slide in progress ends where it is, and the pointer
  /// guard lets go. A finger still down is judged afresh under the new mode.
  public func setTestMode(_ on: Bool) {
    onQueue {
      guard testMode != on else { return }
      testMode = on
      quiesce()
      router.testMode = on
      logger.log(.info, "Test Mode \(on ? "on" : "off")")
      publishStatus()
    }
  }

  // MARK: Live feed

  /// Starts the live touch / decision feed for the settings window's trackpad mirror and Test
  /// Mode. `handler` runs on `queue` (main by default) with value snapshots: touches at most
  /// `feedTouchInterval` apart per device, decisions as they happen. The feed runs only while the
  /// engine is active (running, not paused, enabled) and costs nothing while nobody observes.
  /// Keep the token for `removeFeedObserver(_:)`.
  @discardableResult
  public func observeFeed(on queue: DispatchQueue = .main, _ handler: @escaping @Sendable (LiveFeedUpdate) -> Void)
    -> UUID
  {
    let id = UUID()
    onQueue {
      feed.observers[id] = (queue, handler)
      router.onDecision = { [weak self] in self?.feed.decisions.append($0) }
    }
    return id
  }

  public func removeFeedObserver(_ id: UUID) {
    onQueue {
      feed.observers[id] = nil
      guard !feed.isActive else { return }
      router.onDecision = nil
      feed.clearTracking()
    }
  }

  /// Swap the action registry (e.g. after HUD or haptics settings change).
  public func replaceActions(_ actions: ActionPerforming) {
    onQueue {
      router.replaceActions(actions)
      router.testMode = testMode
    }
  }

  // MARK: Queue-confined

  private func handle(_ frame: TouchFrame) {
    guard running, !paused, config.app.enabled else { return }
    guard let device = devices[frame.deviceID] else { return }
    let bundleID = frontmost.frontmostBundleID
    if case .some(let previous) = lastFrontmost, previous != bundleID {
      // The profile may have changed under a held key: let go now rather than at lift.
      router.releaseHolds(reason: "frontmost app changed")
    }
    lastFrontmost = .some(bundleID)
    let profile = config.profile(for: bundleID)
    let context = GestureContext(
      settings: config.gestures,
      enabledZones: profile.disabled ? [] : Set(profile.bindings.map(\.zone)),
      secondsSinceLastKeyPress: typing.secondsSinceLastKeyPress,
      slideZones: zones(bound: .slide, in: profile),
      longPressZones: zones(bound: .longPress, in: profile),
      doubleTapZones: zones(bound: .doubleTap, in: profile))
    let output = recognizer.process(frame, device: device, context: context)
    updatePointerGuard(claimed: !output.claimedContactIDs.isEmpty, at: frame.timestamp)
    for (contactID, reason) in output.rejections where reason != .startedOutsideZone {
      logger.log(.info, "Rejected contact \(contactID): \(reason)")
    }
    let feeding = feed.isActive
    if feeding { recordRejections(output, frame: frame, device: device, context: context) }
    for event in output.events {
      if feeding && !(event.kind == .slide && event.phase == .changed) {
        feed.decisions.append(
          .recognized(zone: event.zone, kind: event.kind, phase: event.phase, deviceID: event.deviceID))
      }
      router.route(event, config: config, frontmostBundleID: bundleID)
    }
    if feeding { deliverFeed(frame, claimed: output.claimedContactIDs) }
  }

  private func recordRejections(
    _ output: GestureOutput, frame: TouchFrame, device: TouchDeviceInfo, context: GestureContext
  ) {
    for contact in frame.contacts where LiveFeedState.isOnPad(contact) {
      let key = LiveFeedState.ContactKey(deviceID: frame.deviceID, id: contact.id)
      if feed.landing[key] == nil { feed.landing[key] = contact.position }
    }
    for (contactID, reason) in output.rejections where reason != .startedOutsideZone {
      let key = LiveFeedState.ContactKey(deviceID: frame.deviceID, id: contactID)
      guard feed.rejected.insert(key).inserted else { continue }
      let zone = feed.landing[key].flatMap {
        LiveFeedState.zone(at: $0, device: device, settings: context.settings, enabled: context.enabledZones)
      }
      feed.decisions.append(.rejected(contactID: contactID, zone: zone, reason: reason, deviceID: frame.deviceID))
    }
  }

  private func deliverFeed(_ frame: TouchFrame, claimed: Set<Int32>) {
    let onPad = frame.contacts.filter(LiveFeedState.isOnPad)
    let present = Set(onPad.map(\.id))
    // Forget fingers that left this device.
    feed.rejected = feed.rejected.filter { $0.deviceID != frame.deviceID || present.contains($0.id) }
    feed.landing = feed.landing.filter { $0.key.deviceID != frame.deviceID || present.contains($0.key.id) }

    var touches: LiveTouchFrame?
    let last = feed.lastSent[frame.deviceID]
    let due = last.map { frame.timestamp - $0.timestamp >= Self.feedTouchInterval - 1e-9 } ?? true
    let cleared = onPad.isEmpty && last?.hadTouches == true
    if (due && !onPad.isEmpty) || cleared {
      touches = LiveTouchFrame(
        deviceID: frame.deviceID, timestamp: frame.timestamp,
        touches: onPad.map { contact in
          let state: LiveTouch.State =
            claimed.contains(contact.id)
            ? .claimed
            : feed.rejected.contains(.init(deviceID: frame.deviceID, id: contact.id)) ? .rejected : .down
          return LiveTouch(id: contact.id, position: contact.position, state: state)
        })
      feed.lastSent[frame.deviceID] = (frame.timestamp, !onPad.isEmpty)
    }
    guard touches != nil || !feed.decisions.isEmpty else { return }
    let update = LiveFeedUpdate(touches: touches, decisions: feed.decisions)
    feed.decisions.removeAll()
    for (queue, handler) in feed.observers.values { queue.async { handler(update) } }
  }

  private func zones(bound kind: GestureKind, in profile: Profile) -> Set<Zone> {
    profile.disabled ? [] : Set(profile.bindings.filter { $0.gesture == kind }.map(\.zone))
  }

  private func setDevices(_ list: [TouchDeviceInfo]) {
    devices = Dictionary(list.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
    logger.log(.info, "Touch devices: \(list.map { "\($0.kind.rawValue)#\($0.id)" }.joined(separator: ", "))")
    publishStatus()
  }

  private func makeStatus() -> EngineStatus {
    EngineStatus(
      running: running, paused: paused, pausedUntil: pausedUntil, enabled: config.app.enabled,
      devices: devices.values.sorted { $0.id < $1.id }, lastStartError: lastStartError, testMode: testMode)
  }

  private func publishStatus() {
    let status = makeStatus()
    guard status != lastStatus else { return }
    lastStatus = status
    statusHandler?(status)
  }

  /// While a claim lasts, re-engage this often so the guard's safety timeout never ends a long slide.
  static let guardKeepAliveS: Double = 1

  private func updatePointerGuard(claimed: Bool, at timestamp: Double? = nil) {
    if claimed && !guardEngaged {
      guardEngaged = true
      lastGuardEngage = timestamp
      pointerGuard.engage()
    } else if claimed, let timestamp, let last = lastGuardEngage, timestamp - last >= Self.guardKeepAliveS {
      lastGuardEngage = timestamp
      pointerGuard.engage()
    } else if !claimed && guardEngaged {
      guardEngaged = false
      pointerGuard.release()
    }
  }

  private func quiesce() {
    updatePointerGuard(claimed: false)
    recognizer.reset()
    router.reset()
  }

  private func onQueue<T>(_ body: () throws -> T) rethrows -> T {
    if DispatchQueue.getSpecific(key: queueKey) == queueToken { return try body() }
    return try queue.sync(execute: body)
  }
}
