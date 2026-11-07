import AppKit
import EdgyCore
import Foundation

/// Watches clicks, pointer movement and Escape while the app switcher lingers between strokes,
/// through listen-only global event monitors (they observe; they never block or change events).
/// Installed on the main thread by `start`, removed by `stop`; nothing runs while no session
/// lingers.
///
/// Pointer movement counts only past `pointerThresholdPt` of accumulated travel: the next stroke's
/// finger moves the pointer a little before the recognizer claims it, and that must not select.
final class LiveSwitcherInputMonitor: SwitcherInputMonitor, @unchecked Sendable {
  /// Accumulated pointer travel (points) that counts as "moved the pointer".
  static let pointerThresholdPt = 40.0
  /// The Escape key's virtual key code.
  static let escapeKeyCode: UInt16 = 53

  private let lock = NSLock()
  private var monitors: [Any] = []
  private var generation = 0

  func start(_ handler: @escaping @Sendable (SwitcherInterrupt) -> Void) {
    let current = bump()
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.lock.lock()
      defer { self.lock.unlock() }
      // A `stop` (or a newer `start`) got here first.
      guard current == self.generation else { return }
      self.removeMonitors()
      let travel = Travel()
      let pointer = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { event in
        if travel.add((event.deltaX * event.deltaX + event.deltaY * event.deltaY).squareRoot())
          >= Self.pointerThresholdPt
        {
          handler(.pointerMoved)
        }
      }
      let clicks = NSEvent.addGlobalMonitorForEvents(
        matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
      ) { _ in handler(.click) }
      let keys = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { event in
        if event.keyCode == Self.escapeKeyCode { handler(.escape) }
      }
      self.monitors = [pointer, clicks, keys].compactMap { $0 }
    }
  }

  func stop() {
    let current = bump()
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.lock.lock()
      defer { self.lock.unlock() }
      guard current == self.generation else { return }
      self.removeMonitors()
    }
  }

  private func bump() -> Int {
    lock.lock()
    defer { lock.unlock() }
    generation += 1
    return generation
  }

  /// Caller holds `lock`, on the main thread.
  private func removeMonitors() {
    for monitor in monitors { NSEvent.removeMonitor(monitor) }
    monitors = []
  }

  func switcherAppCount() -> Int? {
    let count = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }.count
    return count > 0 ? count : nil
  }

  /// Pointer travel since the monitor was installed (main thread only).
  private final class Travel: @unchecked Sendable {
    private var total = 0.0
    func add(_ distance: Double) -> Double {
      total += distance
      return total
    }
  }
}
