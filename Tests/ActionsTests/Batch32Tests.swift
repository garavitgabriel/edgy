import EdgyCore
import Foundation
import Testing

@testable import Actions

// Batch 32: key sequences on Keyboard Shortcut, and Last App. Mocks only: no key event, app
// activation or workspace observer reaches the real system.

/// True when `body` throws `ActionError.unavailable` (the existing refused/invalid path).
private func refused(_ body: () throws -> Void) -> Bool {
  do {
    try body()
    return false
  } catch ActionError.unavailable {
    return true
  } catch {
    return false
  }
}

@Suite struct KeySequenceTests {
  let shortcut: ActionID = "keyboard.shortcut"
  let gap = ActionRegistry.sequenceStepGap

  @Test func gapIsFortyMilliseconds() {
    #expect(ActionRegistry.sequenceStepGap == 0.040)
    #expect(ActionRegistry.maxSequenceSteps == 4)
  }

  /// One combo: one post, no low-level events, nothing scheduled, no outcome, exactly as before.
  @Test func oneComboIsThePreBatchEventList() throws {
    let h = Harness()
    let outcome = try h.registry.performReporting(
      shortcut, input: .trigger, context: ActionContext(frontmostBundleID: nil, parameters: ["keys": "cmd+c"]))
    #expect(outcome == nil)
    #expect(h.keyboard.posted == ["cmd+c"])
    #expect(h.keyboard.events.isEmpty)
    #expect(h.scheduler.scheduled.isEmpty)
    // Today's parser trims around "+", so a spaced single combo stays one combo.
    try h.trigger(shortcut, ["keys": "cmd + v"])
    #expect(h.keyboard.posted == ["cmd+c", "cmd+v"])
    #expect(h.scheduler.scheduled.isEmpty)
  }

  /// One combo keeps its pre-batch errors.
  @Test func oneComboKeepsItsErrors() {
    let h = Harness()
    #expect(throws: ActionError.missingParameter(shortcut, name: "keys")) { try h.trigger(shortcut) }
    #expect(throws: ActionError.unavailable(shortcut, reason: "keys: \"zz\" is not a key combination")) {
      try h.trigger(shortcut, ["keys": "zz"])
    }
    h.keyboard.failure = OutputError("no events")
    #expect(throws: ActionError.unavailable(shortcut, reason: "no events")) {
      try h.trigger(shortcut, ["keys": "cmd+c"])
    }
    #expect(h.keyboard.events.isEmpty)
  }

  @Test func twoCombosInOrderWithTheGap() throws {
    let h = Harness()
    try h.trigger(shortcut, ["keys": "ctrl+b n"])
    #expect(h.keyboard.posted == ["ctrl+b"])
    #expect(h.scheduler.pending.map(\.delay) == [gap])
    h.scheduler.advance(by: gap - 0.001)
    #expect(h.keyboard.posted == ["ctrl+b"])
    h.scheduler.advance(by: 0.001)
    #expect(h.keyboard.posted == ["ctrl+b", "n"])
    #expect(h.scheduler.pending.isEmpty)
    #expect(h.keyboard.allReleased)
  }

  @Test func fourCombosInOrderWithTheGap() throws {
    let h = Harness()
    let tokens = ["cmd+a", "shift+b", "c", "ctrl+opt+d"]
    let expected = tokens.map { KeyCombo($0)!.description }
    try h.trigger(shortcut, ["keys": tokens.joined(separator: " ")])
    for sent in 1...4 {
      #expect(h.keyboard.posted == Array(expected.prefix(sent)))
      h.scheduler.advance(by: gap)
    }
    #expect(h.keyboard.posted == expected)
    #expect(h.scheduler.scheduled.map(\.delay) == [gap, gap, gap])
    #expect(h.scheduler.pending.isEmpty)
    #expect(h.keyboard.events.isEmpty)
  }

  /// A step that breaks halfway: its key and modifiers come back up, the rest is dropped, and
  /// the action works again afterwards.
  @Test func failureMidSequenceReleasesEverythingAndStops() throws {
    let h = Harness()
    h.keyboard.failOnPost = "ctrl+x"
    try h.trigger(shortcut, ["keys": "ctrl+b ctrl+x y"])
    h.scheduler.advance(by: gap)
    #expect(h.keyboard.posted == ["ctrl+b"])
    #expect(h.keyboard.allReleased)
    #expect(h.keyboard.events == ["x up", "ctrl up"])
    #expect(h.scheduler.pending.isEmpty)
    h.scheduler.advance(by: 1)
    #expect(h.keyboard.posted == ["ctrl+b"])
    // Not stuck "sending".
    try h.trigger(shortcut, ["keys": "ctrl+b n"])
    h.scheduler.advance(by: gap)
    #expect(h.keyboard.posted == ["ctrl+b", "ctrl+b", "n"])
  }

  @Test func failureOnTheFirstStepThrowsReleasesAndStops() throws {
    let h = Harness()
    h.keyboard.failOnPost = "ctrl+b"
    #expect(refused { try h.trigger(shortcut, ["keys": "ctrl+b n"]) })
    #expect(h.keyboard.allReleased)
    #expect(h.keyboard.posted.isEmpty)
    #expect(h.scheduler.scheduled.isEmpty)
    try h.trigger(shortcut, ["keys": "ctrl+b n"])
    h.scheduler.advance(by: gap)
    #expect(h.keyboard.posted == ["ctrl+b", "n"])
  }

  /// A second trigger while a sequence sends is ignored (no error, no interleaving), from this
  /// binding or another Keyboard Shortcut; once it is sent, triggers work again.
  @Test func retriggerWhileSendingIsIgnored() throws {
    let h = Harness()
    try h.trigger(shortcut, ["keys": "ctrl+b n"])
    try h.trigger(shortcut, ["keys": "ctrl+b n"])
    try h.trigger(shortcut, ["keys": "cmd+c"])
    #expect(h.keyboard.posted == ["ctrl+b"])
    #expect(h.scheduler.pending.count == 1)
    h.scheduler.advance(by: gap)
    #expect(h.keyboard.posted == ["ctrl+b", "n"])
    try h.trigger(shortcut, ["keys": "cmd+c"])
    #expect(h.keyboard.posted == ["ctrl+b", "n", "cmd+c"])
  }

  @Test(arguments: [
    "a b c d e",  // five combos
    "ctrl+b zz",  // an unparseable step
    "ctrl+b ctrl",  // a modifier-only step
    "fn n",  // a modifier-only first step
    "ctrl+b  n",  // two spaces: an empty step
  ])
  func refusedSequences(keys: String) {
    let h = Harness()
    #expect(refused { try h.trigger(shortcut, ["keys": keys]) })
    #expect(h.keyboard.posted.isEmpty)
    #expect(h.keyboard.events.isEmpty)
    #expect(h.scheduler.scheduled.isEmpty)
    // Nothing is left "sending".
    #expect(h.registry.keySequence == nil)
  }

  @Test func holdAndSlideStepsRefuseASpace() {
    let h = Harness()
    #expect(refused { try h.press("keyboard.hold", down: true, ["keys": "ctrl+b n"]) })
    #expect(refused { try h.press("keyboard.hold", down: true, ["keys": "ctrl + b"]) })
    #expect(h.keyboard.events.isEmpty)
    #expect(h.keyboard.allReleased)
    #expect(h.scheduler.scheduled.isEmpty)
    let slide = ["upKeys": "cmd+equal", "downKeys": "cmd+minus", "step": "0.1"]
    var spacedUp = slide
    spacedUp["upKeys"] = "cmd+equal n"
    var spacedDown = slide
    spacedDown["downKeys"] = "ctrl+b cmd+minus"
    #expect(refused { try h.slide("keyboard.slideSteps", 0.3, phase: .began, spacedUp) })
    #expect(refused { try h.slide("keyboard.slideSteps", -0.3, phase: .began, spacedDown) })
    #expect(h.keyboard.posted.isEmpty)
    // One combo still works on both.
    #expect(throws: Never.self) { try h.slide("keyboard.slideSteps", 0.3, phase: .began, slide) }
    #expect(!h.keyboard.posted.isEmpty)
    #expect(throws: Never.self) { try h.press("keyboard.hold", down: true, ["keys": "ctrl+b"]) }
    #expect(throws: Never.self) { try h.press("keyboard.hold", down: false, ["keys": "ctrl+b"]) }
    #expect(h.keyboard.allReleased)
  }
}

@Suite struct LastAppTests {
  let last: ActionID = "app.last"
  let a = AppActivation(pid: 101, bundleID: "com.example.wayfare", isRegular: true)
  let b = AppActivation(pid: 102, bundleID: "com.example.huddle", isRegular: true)
  let c = AppActivation(pid: 103, bundleID: "com.example.ledger", isRegular: true)

  @Test func catalogEntry() throws {
    let all = Harness().registry.available
    let index = try #require(all.firstIndex { $0.id == last })
    #expect(all[index - 1].id == BuiltInAction.openApp)
    #expect(all[index].displayName == "Last App")
    #expect(all[index].category == .apps)
    #expect(all[index].shape == .trigger)
    #expect(all[index].parameters.isEmpty)
    #expect(BuiltInAction.lastApp == last)
  }

  /// A → B, trigger → A; trigger again → B (recorded at trigger time, so it works before the
  /// system's activation notification arrives).
  @Test func togglesBetweenTheLastTwoApps() throws {
    let h = Harness()
    h.apps.userActivates(a)
    h.apps.userActivates(b)
    try h.trigger(last)
    #expect(h.apps.activated == [a.pid])
    #expect(h.apps.front == a)
    try h.trigger(last)
    #expect(h.apps.activated == [a.pid, b.pid])
    #expect(h.apps.front == b)
    #expect(h.keyboard.posted.isEmpty)
  }

  /// The tracker's notification arriving after the trigger doesn't double-count.
  @Test func lateNotificationKeepsTheToggle() throws {
    let h = Harness()
    h.apps.userActivates(a)
    h.apps.userActivates(b)
    try h.trigger(last)
    h.apps.userActivates(a)
    try h.trigger(last)
    #expect(h.apps.activated == [a.pid, b.pid])
  }

  @Test func previousAppQuitGoesToTheOneBefore() throws {
    let h = Harness()
    h.apps.userActivates(c)
    h.apps.userActivates(a)
    h.apps.userActivates(b)
    h.apps.quit(a)
    try h.trigger(last)
    #expect(h.apps.activated == [c.pid])
    #expect(h.apps.front == c)
  }

  @Test func previousAppQuitWithNoneBeforeIsANoOp() throws {
    let h = Harness()
    h.apps.userActivates(a)
    h.apps.userActivates(b)
    h.apps.quit(a)
    let outcome = try h.registry.performReporting(
      last, input: .trigger, context: ActionContext(frontmostBundleID: nil, parameters: [:]))
    #expect(outcome == nil)
    #expect(h.apps.activated.isEmpty)
    #expect(h.keyboard.posted.isEmpty)
  }

  /// Edgy's own windows never count: in front, Last App goes to the app before them; in the
  /// history, they are skipped. Apps that aren't regular don't count either.
  @Test func edgysOwnWindowsNeverCount() throws {
    let h = Harness()
    let edgy = AppActivation(pid: h.apps.ownPID, bundleID: "com.garavit.edgy", isRegular: true)
    let agent = AppActivation(pid: 200, bundleID: "com.example.agent", isRegular: false)
    h.apps.userActivates(a)
    h.apps.userActivates(edgy)
    h.apps.userActivates(agent)
    h.apps.userActivates(b)
    try h.trigger(last)
    #expect(h.apps.activated == [a.pid])
    h.apps.userActivates(edgy)
    try h.trigger(last)
    // From Edgy's window: back to A, the app in front before Edgy.
    #expect(h.apps.activated == [a.pid, a.pid])
    #expect(!h.apps.activated.contains(edgy.pid))
    #expect(!h.apps.activated.contains(agent.pid))
  }

  /// An app that comes forward showing no window of its own (a dictation bar's helper, on every
  /// Space change) is not an app the user was in: it never becomes the target and never pushes
  /// the real previous app down (owner report 2026-11-10).
  @Test func appsThatComeForwardWithoutAWindowNeverCount() throws {
    let h = Harness()
    let overlay = AppActivation(pid: 300, bundleID: "com.example.overlay", isRegular: true, hasWindowOnScreen: false)
    h.apps.userActivates(a)
    h.apps.userActivates(overlay)
    h.apps.userActivates(b)
    h.apps.userActivates(overlay)
    try h.trigger(last)
    #expect(h.apps.activated == [a.pid])
    h.apps.userActivates(overlay)
    try h.trigger(last)
    #expect(h.apps.activated == [a.pid, b.pid])
    #expect(!h.apps.activated.contains(overlay.pid))
  }

  /// With Edgy in front, Last App goes back to the app that was in front before it.
  @Test func fromEdgysWindowGoesToTheAppBeforeIt() throws {
    let h = Harness()
    let edgy = AppActivation(pid: h.apps.ownPID, bundleID: "com.garavit.edgy", isRegular: true)
    h.apps.userActivates(a)
    h.apps.userActivates(b)
    h.apps.userActivates(edgy)
    try h.trigger(last)
    #expect(h.apps.activated == [b.pid])
  }

  @Test func noHistoryIsANoOp() throws {
    let h = Harness()
    let outcome = try h.registry.performReporting(
      last, input: .trigger, context: ActionContext(frontmostBundleID: nil, parameters: [:]))
    #expect(outcome == nil)
    #expect(h.apps.activated.isEmpty)
    #expect(h.keyboard.posted.isEmpty)
    // Only the current app known: still nothing to go back to.
    h.apps.userActivates(a)
    try h.trigger(last)
    #expect(h.apps.activated.isEmpty)
    #expect(h.keyboard.posted.isEmpty)
  }

  /// The fallback: only when the system refuses the activation, one quick switcher press.
  @Test func refusedActivationFallsBackToOneSwitcherPress() throws {
    let h = Harness()
    h.apps.userActivates(a)
    h.apps.userActivates(b)
    h.apps.refuses = true
    try h.trigger(last)
    #expect(h.apps.activated == [a.pid])
    #expect(h.keyboard.posted == ["cmd+tab"])
    #expect(h.keyboard.allReleased)
  }

  @Test func registryObservesFromTheStart() {
    let h = Harness()
    #expect(h.apps.handler != nil)
  }

  @Test func historyIsBounded() {
    var history = AppHistory()
    for pid in 1...40 { history.record(AppActivation(pid: Int32(pid), bundleID: nil, isRegular: true), ownPID: 999) }
    #expect(history.recent.count == AppHistory.limit)
    #expect(history.recent.first?.pid == 40)
  }
}
