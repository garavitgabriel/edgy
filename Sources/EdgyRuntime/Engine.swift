import EdgyCore
import Foundation

/// Tells the engine which app is frontmost. The live implementation lives in EdgyApp.
public protocol FrontmostAppProviding: AnyObject, Sendable {
  var frontmostBundleID: String? { get }
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
      onQueue { running = false }
      throw error
    }
  }

  public func stop() {
    touchSource.stop()
    onQueue {
      running = false
      quiesce()
    }
  }

  public func pause() {
    onQueue {
      paused = true
      quiesce()
    }
  }

  public func resume() {
    onQueue { paused = false }
  }

  /// Adopt a new config: in-flight gestures are dropped and the next frame uses the new context.
  public func apply(_ config: EdgyConfig) {
    onQueue {
      self.config = config
      quiesce()
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
