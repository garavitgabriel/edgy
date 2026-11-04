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
  func install(handler: @escaping @Sendable (TapEventKind) -> TapVerdict) -> Bool
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
public final class PointerGuardCore: PointerGuarding, @unchecked Sendable {
  public static let defaultSafetyTimeout: TimeInterval = 3

  private let tap: EventTapping
  private let cursor: CursorControlling
  private let scheduler: GuardScheduling
  private let safetyTimeout: TimeInterval

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

  public init(
    tap: EventTapping, cursor: CursorControlling, scheduler: GuardScheduling,
    safetyTimeout: TimeInterval = PointerGuardCore.defaultSafetyTimeout
  ) {
    self.tap = tap
    self.cursor = cursor
    self.scheduler = scheduler
    self.safetyTimeout = safetyTimeout
  }

  public var isEngaged: Bool { lock.withLock { engaged } }
  public var isTapInstalled: Bool { lock.withLock { tapInstalled } }
  public var reEnableCount: Int { lock.withLock { _reEnableCount } }
  public var timeoutReleaseCount: Int { lock.withLock { _timeoutReleaseCount } }
  public var swallowedCount: Int { lock.withLock { _swallowedCount } }

  public func engage() {
    installTapIfNeeded()
    let position = cursor.position()
    lock.lock()
    if !engaged {
      engaged = true
      engagePoint = position
    }
    generation += 1
    let token = generation
    timer?.cancel()
    timer = nil
    lock.unlock()

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
    lock.unlock()

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
    let ok = tap.install { [weak self] kind in self?.handleTap(kind) ?? .pass }
    lock.withLock {
      tapInstalled = ok
      installing = false
    }
    if !ok { TouchKitLog.pointer.error("pointer guard: event tap unavailable (Accessibility not granted?)") }
  }

  /// Called by the tap for every event it sees.
  func handleTap(_ kind: TapEventKind) -> TapVerdict {
    switch kind {
    case .disabledByTimeout, .disabledByUserInput:
      lock.withLock { _reEnableCount += 1 }
      tap.setEnabled(true)
      return .pass
    case .pointerMotion:
      let swallow = lock.withLock { () -> Bool in
        if engaged { _swallowedCount += 1 }
        return engaged
      }
      return swallow ? .swallow : .pass
    case .other:
      return .pass
    }
  }
}
