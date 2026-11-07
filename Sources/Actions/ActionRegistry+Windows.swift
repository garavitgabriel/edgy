import CoreGraphics
import EdgyCore
import Foundation

/// A window action that may have to wait for the window to leave full screen.
enum WindowCommand: Equatable, Sendable {
  case snap(WindowSnap)
  case minimize
}

extension ActionRegistry {
  /// How long a window gets to leave full screen before the command is dropped. The system's
  /// exit animation takes well under a second; this leaves room for a busy machine.
  static let fullScreenExitTimeout: TimeInterval = 2.0
  /// How often the full-screen attribute is polled while waiting.
  static let fullScreenPollInterval: TimeInterval = 0.05

  /// Apps may round a requested frame (to a text grid, a minimum size), so "still where Edgy put
  /// it" allows this much slack per edge, in points.
  static let placementSlack: CGFloat = 32

  static func roughlyEqual(_ a: CGRect, _ b: CGRect) -> Bool {
    abs(a.minX - b.minX) <= placementSlack && abs(a.minY - b.minY) <= placementSlack
      && abs(a.maxX - b.maxX) <= placementSlack && abs(a.maxY - b.maxY) <= placementSlack
  }

  /// Runs `command` on the focused window. A full-screen window is first taken out of full
  /// screen; the command then runs on the waiter's queue once the window has left (or is dropped,
  /// with a log line, if it hasn't within `fullScreenExitTimeout`).
  func windowCommand(_ command: WindowCommand) throws {
    let window = try windows.focusedWindow()
    guard window.isFullScreen else { return try run(command, on: window) }

    windowLock.lock()
    let alreadyLeaving = pendingFullScreenExits[window.id] != nil
    pendingFullScreenExits[window.id] = command
    windowLock.unlock()
    // A second command while the window is still leaving just replaces what happens after.
    guard !alreadyLeaving else { return }

    do {
      try windows.exitFullScreen(window.id)
    } catch {
      windowLock.withLock { pendingFullScreenExits[window.id] = nil }
      throw error
    }
    let id = window.id
    waiter.wait(
      timeout: Self.fullScreenExitTimeout, interval: Self.fullScreenPollInterval,
      until: { [self] in (try? windows.snapshot(of: id).isFullScreen) == false },
      then: { [self] left in finishFullScreenExit(id, left: left) })
  }

  /// Runs the command waiting on `id`, on a fresh snapshot: the frame it had before full screen
  /// is what `window.restore` will return to.
  func finishFullScreenExit(_ id: WindowID, left: Bool) {
    windowLock.lock()
    defer { windowLock.unlock() }
    guard let command = pendingFullScreenExits.removeValue(forKey: id) else { return }
    guard left else {
      actionsLog.notice(
        "window still in full screen after \(Self.fullScreenExitTimeout, privacy: .public)s; dropped \(String(describing: command), privacy: .public)"
      )
      return
    }
    do {
      try run(command, on: windows.snapshot(of: id))
    } catch {
      actionsLog.error(
        "window \(String(describing: command), privacy: .public) after full screen failed: \(String(describing: error), privacy: .public)"
      )
    }
  }

  private func run(_ command: WindowCommand, on window: WindowSnapshot) throws {
    switch command {
    case .snap(let snap): try place(snap, window)
    case .minimize: try windows.minimize(window.id)
    }
  }

  private func place(_ snap: WindowSnap, _ window: WindowSnapshot) throws {
    windowLock.lock()
    defer { windowLock.unlock() }
    let target = WindowGeometry.target(for: snap, window: window.frame, visible: window.visibleFrame)
    // Remember the frame from before this chain of snaps. A window the user has moved or resized
    // since Edgy last placed it starts a new chain.
    let chained =
      snapMemory[window.id] != nil
      && lastPlaced[window.id].map { Self.roughlyEqual($0, window.frame) } == true
    if !chained { remember(window.frame, for: window.id) }
    try windows.setFrame(target, of: window.id)
    lastPlaced[window.id] = target
  }

  /// Back to the remembered pre-snap frame. Never back into full screen: a window snapped out of
  /// full screen remembers the frame it had once it left.
  func restoreWindow() throws {
    windowLock.lock()
    defer { windowLock.unlock() }
    guard !snapMemory.isEmpty else { return }
    let window = try windows.focusedWindow()
    guard let frame = snapMemory[window.id] else { return }
    try windows.setFrame(frame, of: window.id)
    forget(window.id)
  }

  private func remember(_ frame: CGRect, for window: WindowID) {
    snapOrder.removeAll { $0 == window }
    snapOrder.append(window)
    snapMemory[window] = frame
    while snapOrder.count > Self.snapMemoryLimit { forget(snapOrder[0]) }
  }

  private func forget(_ window: WindowID) {
    snapOrder.removeAll { $0 == window }
    snapMemory[window] = nil
    lastPlaced[window] = nil
  }
}
