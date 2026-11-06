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

  public init(
    running: Bool = false, paused: Bool = false, pausedUntil: Date? = nil, enabled: Bool = true,
    devices: [TouchDeviceInfo] = [], lastStartError: String? = nil
  ) {
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

  /// Swap the action registry (e.g. after HUD or haptics settings change).
  public func replaceActions(_ actions: ActionPerforming) {
    onQueue { router.replaceActions(actions) }
  }

  // MARK: Queue-confined

  private func handle(_ frame: TouchFrame) {
    guard running, !paused, config.app.enabled else { return }
    guard let device = devices[frame.deviceID] else { return }
    let bundleID = frontmost.frontmostBundleID
    let profile = config.profile(for: bundleID)
    let context = GestureContext(
      settings: config.gestures,
      enabledZones: profile.disabled ? [] : Set(profile.bindings.map(\.zone)),
      secondsSinceLastKeyPress: typing.secondsSinceLastKeyPress,
      slideZones: zones(bound: .slide, in: profile),
      longPressZones: zones(bound: .longPress, in: profile))
    let output = recognizer.process(frame, device: device, context: context)
    updatePointerGuard(claimed: !output.claimedContactIDs.isEmpty, at: frame.timestamp)
    for (contactID, reason) in output.rejections where reason != .startedOutsideZone {
      logger.log(.info, "Rejected contact \(contactID): \(reason)")
    }
    for event in output.events {
      router.route(event, config: config, frontmostBundleID: bundleID)
    }
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
      devices: devices.values.sorted { $0.id < $1.id }, lastStartError: lastStartError)
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
