import EdgyCore
import Foundation

/// What the event tap saw.
public enum TapEventKind: Sendable, Equatable {
  /// Mouse moved / dragged with any button.
  case pointerMotion
  /// The system disabled the tap because a callback took too long.
  case disabledByTimeout
  /// The system disabled the tap because of user input (e.g. secure input).
  case disabledByUserInput
  case other
}

public enum TapVerdict: Sendable, Equatable {
  case pass
  case swallow
}

/// An active event tap on pointer-motion events. Behind a protocol so tests never create one.
public protocol EventTapping: AnyObject, Sendable {
  /// Installs the tap. Returns false if it could not be created (usually missing Accessibility).
  /// The handler gets the event kind and, for pointer motion, the event's own location (the
  /// position the cursor is about to move to; the global cursor position still lags behind).
  func install(handler: @escaping @Sendable (TapEventKind, Point2D?) -> TapVerdict) -> Bool
  func setEnabled(_ enabled: Bool)
}

/// Reading and warping the on-screen cursor. Behind a protocol so tests never move it.
public protocol CursorControlling: AnyObject, Sendable {
  func position() -> Point2D?
  func warp(to point: Point2D)
}

public protocol GuardCancellable: Sendable {
  func cancel()
}

public protocol GuardScheduling: AnyObject, Sendable {
  func schedule(after seconds: TimeInterval, _ work: @escaping @Sendable () -> Void) -> any GuardCancellable
}

/// The pointer-guard state machine.
///
/// - `engage()`: remember where the cursor is, start swallowing pointer motion, arm the safety
///   timeout. Engaging while engaged keeps the original point and only re-arms the timeout.
/// - `release()`: stop swallowing and warp the cursor back to the engage point. Releasing while
///   idle does nothing.
/// - Safety timeout: if `release()` never arrives, the guard releases itself so the cursor can
///   never stay stuck.
/// - If the system disables the tap, it is re-enabled immediately.
/// - Lookback: the gesture layer only claims a finger after its intent gate (dwell or along-axis
///   motion), so the cursor has already drifted by then. While idle, the guard keeps a short
///   history of cursor positions and engages at the oldest one inside `lookback`.
/// - Pinning (`pinWhileEngaged`): every swallowed motion event also warps the cursor back to the
///   engage point, so it stays put even where swallowing alone does not stop it on screen.
public final class PointerGuardCore: PointerGuarding, @unchecked Sendable {
  public static let defaultSafetyTimeout: TimeInterval = 3

  private let tap: EventTapping
  private let cursor: CursorControlling
  private let scheduler: GuardScheduling
  private let safetyTimeout: TimeInterval
  private let lookback: TimeInterval
  private let pinWhileEngaged: Bool
  private let now: @Sendable () -> TimeInterval
  private var history: [(time: TimeInterval, point: Point2D)] = []

  private let lock = NSLock()
  private var engaged = false
  private var engagePoint: Point2D?
  private var generation = 0
  private var timer: (any GuardCancellable)?
  private var tapInstalled = false
  private var installing = false
  private var _reEnableCount = 0
  private var _timeoutReleaseCount = 0
  private var _swallowedCount = 0
  private var _pinCount = 0
  private var swallowedAtEngage = 0
  private var pinsAtEngage = 0

  public init(
    tap: EventTapping, cursor: CursorControlling, scheduler: GuardScheduling,
    safetyTimeout: TimeInterval = PointerGuardCore.defaultSafetyTimeout,
    lookback: TimeInterval = 0, pinWhileEngaged: Bool = false,
    now: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
  ) {
    self.tap = tap
    self.cursor = cursor
    self.scheduler = scheduler
    self.safetyTimeout = safetyTimeout
    self.lookback = lookback
    self.pinWhileEngaged = pinWhileEngaged
    self.now = now
  }

  /// Installs the tap ahead of the first engage so the lookback history is already filling.
  public func prepare() { installTapIfNeeded() }

  public var isEngaged: Bool { lock.withLock { engaged } }
  public var isTapInstalled: Bool { lock.withLock { tapInstalled } }
  public var reEnableCount: Int { lock.withLock { _reEnableCount } }
  public var timeoutReleaseCount: Int { lock.withLock { _timeoutReleaseCount } }
  public var swallowedCount: Int { lock.withLock { _swallowedCount } }

  public func engage() {
    installTapIfNeeded()
    let position = cursor.position()
    let at = now()
    lock.lock()
    var pinTo: Point2D?
    if !engaged {
      engaged = true
      swallowedAtEngage = _swallowedCount
      pinsAtEngage = _pinCount
      let earliest = lookback > 0 ? history.first(where: { at - $0.time <= lookback })?.point : nil
      engagePoint = earliest ?? position
      history.removeAll()
      if pinWhileEngaged, let earliest, earliest != position { pinTo = earliest }
    }
    generation += 1
    let token = generation
    timer?.cancel()
    timer = nil
    lock.unlock()

    if let pinTo { cursor.warp(to: pinTo) }
    let newTimer = scheduler.schedule(after: safetyTimeout) { [weak self] in self?.timeoutFired(token: token) }
    lock.lock()
    if engaged && generation == token {
      timer = newTimer
      lock.unlock()
    } else {
      lock.unlock()
      newTimer.cancel()
    }
  }

  public func release() {
    releaseIfCurrent(token: nil)
  }

  private func timeoutFired(token: Int) {
    if releaseIfCurrent(token: token) {
      lock.withLock { _timeoutReleaseCount += 1 }
      TouchKitLog.pointer.notice("pointer guard released by safety timeout")
    }
  }

  @discardableResult
  private func releaseIfCurrent(token: Int?) -> Bool {
    lock.lock()
    guard engaged, token == nil || token == generation else {
      lock.unlock()
      return false
    }
    engaged = false
    generation += 1
    let point = engagePoint
    engagePoint = nil
    let pending = timer
    timer = nil
    let swallowed = _swallowedCount - swallowedAtEngage
    let pins = _pinCount - pinsAtEngage
    let installed = tapInstalled
    lock.unlock()
    TouchKitLog.pointer.info(
      "pointer guard released: tap \(installed ? "on" : "off"), swallowed \(swallowed), pinned \(pins)")

    pending?.cancel()
    if let point { cursor.warp(to: point) }
    return true
  }

  private func installTapIfNeeded() {
    let shouldInstall = lock.withLock { () -> Bool in
      guard !tapInstalled, !installing else { return false }
      installing = true
      return true
    }
    guard shouldInstall else { return }
    let ok = tap.install { [weak self] kind, location in self?.handleTap(kind, location: location) ?? .pass }
    lock.withLock {
      tapInstalled = ok
      installing = false
    }
    if ok {
      TouchKitLog.pointer.info("pointer guard: event tap installed")
    } else {
      TouchKitLog.pointer.error("pointer guard: event tap unavailable (Accessibility not granted?)")
    }
  }

  /// Called by the tap for every event it sees.
  func handleTap(_ kind: TapEventKind, location: Point2D? = nil) -> TapVerdict {
    switch kind {
    case .disabledByTimeout, .disabledByUserInput:
      let first = lock.withLock { () -> Bool in
        _reEnableCount += 1
        return _reEnableCount == 1
      }
      tap.setEnabled(true)
      if first {
        TouchKitLog.pointer.notice(
          "pointer guard: the system turned the tap off (\(kind == .disabledByTimeout ? "timeout" : "user input", privacy: .public)); turned it back on (logged once)"
        )
      }
      return .pass
    case .pointerMotion:
      let wantsHistory = lookback > 0
      let position = (wantsHistory || pinWhileEngaged) ? (location ?? cursor.position()) : nil
      let at = now()
      let (swallow, pinTo) = lock.withLock { () -> (Bool, Point2D?) in
        if engaged {
          _swallowedCount += 1
          return (true, pinWhileEngaged ? engagePoint : nil)
        }
        if wantsHistory, let position {
          history.append((at, position))
          history.removeAll(where: { at - $0.time > lookback })
        }
        return (false, nil)
      }
      if let pinTo, let position, position != pinTo {
        lock.withLock { _pinCount += 1 }
        cursor.warp(to: pinTo)
      }
      return swallow ? .swallow : .pass
    case .other:
      return .pass
    }
  }
}
