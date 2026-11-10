import EdgyCore
import Foundation

extension ActionRegistry {
  /// An app came to the front (from the activation tracker, on any thread).
  func appActivated(_ app: AppActivation) {
    appHistoryLock.lock()
    defer { appHistoryLock.unlock() }
    appHistory.record(app, ownPID: apps.ownPID)
  }

  /// `app.last`: brings back the app that was in front before the current one.
  ///
  /// The path: activate the most recent regular app that is still running and isn't in front now
  /// (Edgy itself never counts; apps that quit are skipped). Only if the system refuses that
  /// activation does one quick press of the app switcher shortcut (command-tab) do it instead. No
  /// previous app → nothing happens, and that is not an error.
  func performLastApp(_ id: ActionID) throws {
    let front = apps.frontmost()
    appHistoryLock.lock()
    if let front { appHistory.record(front, ownPID: apps.ownPID) }
    let target = appHistory.previous(frontmostPID: front?.pid, isRunning: apps.isRunning)
    appHistoryLock.unlock()
    guard let target else {
      actionsLog.info("last app: no previous app; nothing to do")
      return
    }
    // Activate outside the lock: the tracker may record from another thread meanwhile.
    if apps.activate(target) {
      // Recorded now, not when the notification arrives, so a quick second trigger goes back.
      appActivated(target)
      return
    }
    actionsLog.notice(
      "last app: activating \(target.bundleID ?? "pid \(target.pid)", privacy: .public) was refused; pressing the switcher shortcut"
    )
    try unavailable(id) { try keyboard.post(KeyCombo(modifiers: [Self.switcherModifier], key: Self.switcherKey)) }
  }
}
