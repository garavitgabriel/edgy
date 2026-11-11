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
    // An app in front with no window of its own (an overlay helper) isn't where the user is: the
    // app they are in is the most recent remembered one, so that one is skipped instead.
    let overlayInFront = front.map { $0.isRegular && !$0.hasWindowOnScreen && $0.pid != apps.ownPID } ?? false
    let current = overlayInFront ? appHistory.recent.first?.pid : front?.pid
    let target = appHistory.previous(frontmostPID: current, isRunning: apps.isRunning)
    let remembered = appHistory.recent.prefix(4).map { $0.bundleID ?? "pid \($0.pid)" }.joined(separator: " > ")
    appHistoryLock.unlock()
    actionsLog.notice(
      "last app: front \(front?.bundleID ?? "none", privacy: .public), remembered \(remembered, privacy: .public), going to \(target?.bundleID ?? "nothing", privacy: .public)"
    )
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
