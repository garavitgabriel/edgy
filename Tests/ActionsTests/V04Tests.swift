import CoreGraphics
import EdgyCore
import Foundation
import Testing

@testable import Actions

// v0.4: "Do nothing", modifier-only hold, watchdogs. Every test runs on recording mocks; nothing
// reaches the real keyboard.

@Suite struct DoNothingTests {
  @Test func descriptorIsAParameterlessSystemTrigger() {
    let descriptor = Harness().registry.available.first { $0.id == ActionID.doNothing }
    #expect(descriptor?.id.rawValue == "edgy.none")
    #expect(descriptor?.displayName == "Do nothing")
    #expect(descriptor?.category == .system)
    #expect(descriptor?.shape == .trigger)
    #expect(descriptor?.parameters == [])
    #expect(BuiltInAction.doNothing == ActionID.doNothing)
  }

  @Test func alwaysAvailable() {
    let h = Harness()
    #expect(h.registry.availability(of: .doNothing) == .available)
    // Even on a Mac with nothing: no backlight, no built-in panel, no monitors.
    h.backlight.isAvailable = false
    h.display.isAvailable = false
    #expect(h.registry.availability(of: .doNothing) == .available)
  }

  @Test func performingTouchesNothing() throws {
    let h = Harness()
    try h.trigger(.doNothing)
    try h.trigger(.doNothing, ["keys": "cmd+q"])
    #expect(h.keyboard.posted.isEmpty && h.keyboard.events.isEmpty)
    #expect(h.media.keys.isEmpty && h.system.commands.isEmpty && h.shortcuts.ran.isEmpty)
    #expect(h.workspace.calls.isEmpty && h.windows.log.isEmpty && h.hud.shown.isEmpty)
    #expect(h.haptics.ticks == 0 && h.haptics.strongTicks == 0)
    #expect(h.audio.setVolumeCalls.isEmpty && h.audio.setMutedCalls.isEmpty)
  }

  @Test func wrongShapeStillRejected() {
    let h = Harness()
    #expect(throws: ActionError.wrongInputShape(.doNothing)) { try h.press(.doNothing, down: true) }
  }
}

@Suite struct ModifierOnlyHoldTests {
  @Test func fnAloneGoesDownAndUp() throws {
    let h = Harness()
    try h.press("keyboard.hold", down: true, ["keys": "fn"])
    #expect(h.keyboard.events == ["fn down"])
    #expect(h.keyboard.heldModifiers == [.fn])
    try h.press("keyboard.hold", down: false)
    #expect(h.keyboard.events == ["fn down", "fn up"])
    #expect(h.keyboard.allReleased)
  }

  @Test func ctrlOptPressInOrderReleaseInReverse() throws {
    let h = Harness()
    try h.press("keyboard.hold", down: true, ["keys": "opt+ctrl"])
    try h.press("keyboard.hold", down: false)
    #expect(h.keyboard.events == ["ctrl down", "opt down", "opt up", "ctrl up"])
    #expect(h.keyboard.allReleased)
  }

  @Test func mixedModifiersIncludingFn() throws {
    let h = Harness()
    try h.press("keyboard.hold", down: true, ["keys": "fn+shift+cmd"])
    try h.press("keyboard.hold", down: false)
    #expect(h.keyboard.events == ["shift down", "cmd down", "fn down", "fn up", "cmd up", "shift up"])
    #expect(h.keyboard.posted.isEmpty)
  }

  @Test func doubleDownReleasesTheFirstModifierOnlyHold() throws {
    let h = Harness()
    try h.press("keyboard.hold", down: true, ["keys": "fn"])
    try h.press("keyboard.hold", down: true, ["keys": "ctrl+opt"])
    #expect(h.keyboard.events == ["fn down", "fn up", "ctrl down", "opt down"])
    try h.press("keyboard.hold", down: false)
    #expect(h.keyboard.allReleased)
  }

  @Test func modifierOnlyThenKeyedHold() throws {
    let h = Harness()
    try h.press("keyboard.hold", down: true, ["keys": "fn"])
    try h.press("keyboard.hold", down: true, ["keys": "cmd+space"])
    try h.press("keyboard.hold", down: false)
    #expect(h.keyboard.events == ["fn down", "fn up", "cmd down", "cmd+space down", "cmd+space up", "cmd up"])
  }

  @Test func failedModifierReleasesWhatWentDown() {
    let h = Harness()
    h.keyboard.failOnEvent = "opt down"
    #expect(throws: ActionError.unavailable("keyboard.hold", reason: "key event failed")) {
      try h.press("keyboard.hold", down: true, ["keys": "ctrl+opt"])
    }
    #expect(h.keyboard.allReleased)
  }

  @Test func shortcutAndSlideStepsNeedAKey() {
    let h = Harness()
    #expect(throws: ActionError.self) { try h.trigger("keyboard.shortcut", ["keys": "fn"]) }
    do {
      try h.trigger("keyboard.shortcut", ["keys": "ctrl+opt"])
      Issue.record("expected unavailable")
    } catch ActionError.unavailable(let id, let reason) {
      #expect(id == "keyboard.shortcut")
      #expect(reason.contains("needs a key"))
      #expect(reason.contains("ctrl+opt"))
    } catch {
      Issue.record("unexpected \(error)")
    }
    #expect(throws: ActionError.self) {
      try h.slide("keyboard.slideSteps", 0.5, phase: .began, ["upKeys": "up", "downKeys": "fn"])
    }
    #expect(throws: ActionError.self) {
      try h.slide("keyboard.slideSteps", 0.5, phase: .began, ["upKeys": "shift", "downKeys": "down"])
    }
    #expect(h.keyboard.posted.isEmpty && h.keyboard.events.isEmpty)
  }
}

/// The live keyboard output's event plan for modifier keys (pure; nothing is posted).
@Suite struct ModifierEventPlanTests {
  typealias Event = KeyCodes.ModifierEvent

  @Test func fnUsesItsKeyCodeAndTheSecondaryFnFlag() {
    let down = KeyCodes.modifierEvents([.fn], down: true, held: [])
    #expect(down.events == [Event(modifier: .fn, code: 0x3F, down: true, flags: .maskSecondaryFn)])
    #expect(down.held == [.fn])
    let up = KeyCodes.modifierEvents([.fn], down: false, held: down.held)
    #expect(up.events == [Event(modifier: .fn, code: 0x3F, down: false, flags: [])])
    #expect(up.held.isEmpty)
  }

  @Test func ctrlOptCarryTheHeldStateAndDeviceBits() {
    let ctrl = CGEventFlags.maskControl.union(CGEventFlags(rawValue: 0x1))
    let opt = CGEventFlags.maskAlternate.union(CGEventFlags(rawValue: 0x20))
    let down = KeyCodes.modifierEvents([.ctrl, .opt], down: true, held: [])
    #expect(
      down.events == [
        Event(modifier: .ctrl, code: 0x3B, down: true, flags: ctrl),
        Event(modifier: .opt, code: 0x3A, down: true, flags: ctrl.union(opt)),
      ])
    let up = KeyCodes.modifierEvents([.opt, .ctrl], down: false, held: down.held)
    #expect(
      up.events == [
        Event(modifier: .opt, code: 0x3A, down: false, flags: ctrl),
        Event(modifier: .ctrl, code: 0x3B, down: false, flags: []),
      ])
    #expect(up.held.isEmpty)
  }

  @Test func mixedWithFnKeepsOtherHeldModifiers() {
    let down = KeyCodes.modifierEvents([.cmd, .fn], down: true, held: [.shift])
    #expect(down.events.map(\.code) == [0x37, 0x3F])
    #expect(down.events[1].flags.contains([.maskShift, .maskCommand, .maskSecondaryFn]))
    #expect(down.held == [.shift, .cmd, .fn])
    let fnUp = KeyCodes.modifierEvents([.fn], down: false, held: down.held)
    #expect(!fnUp.events[0].flags.contains(.maskSecondaryFn))
    #expect(fnUp.events[0].flags.contains([.maskShift, .maskCommand]))
  }

  @Test func releasingANotHeldModifierStillEmitsItsUp() {
    let up = KeyCodes.modifierEvents([.fn], down: false, held: [])
    #expect(up.events.count == 1 && up.events[0].down == false)
  }
}

@Suite struct HoldWatchdogTests {
  @Test func releasesOnceAtDefaultMaxSeconds() throws {
    let h = Harness()
    try h.press("keyboard.hold", down: true, ["keys": "fn"])
    #expect(h.scheduler.pending.map(\.delay) == [120])
    h.scheduler.advance(by: 119.9)
    #expect(h.keyboard.heldModifiers == [.fn])
    h.scheduler.advance(by: 0.1)
    #expect(h.keyboard.events == ["fn down", "fn up"])
    #expect(h.keyboard.allReleased)
    h.scheduler.advance(by: 1000)
    #expect(h.keyboard.events == ["fn down", "fn up"])
    // The late up from the router is harmless.
    try h.press("keyboard.hold", down: false)
    #expect(h.keyboard.events == ["fn down", "fn up"])
  }

  @Test func honoursMaxSecondsParameter() throws {
    let h = Harness()
    try h.press("keyboard.hold", down: true, ["keys": "cmd+space", "maxSeconds": "5"])
    h.scheduler.advance(by: 5)
    #expect(h.keyboard.events == ["cmd down", "cmd+space down", "cmd+space up", "cmd up"])
  }

  @Test func doesNotFireAfterANormalUp() throws {
    let h = Harness()
    try h.press("keyboard.hold", down: true, ["keys": "fn", "maxSeconds": "5"])
    try h.press("keyboard.hold", down: false)
    #expect(h.scheduler.pending.isEmpty)
    #expect(h.scheduler.scheduled.first?.cancelled == true)
    h.scheduler.advance(by: 600)
    #expect(h.keyboard.events == ["fn down", "fn up"])
  }

  @Test func aStaleFireCannotReleaseANewerHold() throws {
    let h = Harness()
    try h.press("keyboard.hold", down: true, ["keys": "fn", "maxSeconds": "5"])
    try h.press("keyboard.hold", down: false)
    try h.press("keyboard.hold", down: true, ["keys": "ctrl", "maxSeconds": "5"])
    // The first timer fires anyway (it raced the cancel): the ctrl hold must survive.
    h.scheduler.fireLate(h.scheduler.scheduled[0])
    #expect(h.keyboard.heldModifiers == [.ctrl])
    h.scheduler.advance(by: 5)
    #expect(h.keyboard.allReleased)
  }

  @Test func outOfRangeMaxSecondsFailsBeforePressing() {
    let h = Harness()
    for bad in ["4", "601", "soon"] {
      #expect(throws: ActionError.missingParameter("keyboard.hold", name: "maxSeconds")) {
        try h.press("keyboard.hold", down: true, ["keys": "fn", "maxSeconds": bad])
      }
    }
    #expect(h.keyboard.events.isEmpty && h.scheduler.scheduled.isEmpty)
  }

  @Test func failedPressArmsNoWatchdog() {
    let h = Harness()
    h.keyboard.failOnEvent = "fn down"
    #expect(throws: ActionError.self) { try h.press("keyboard.hold", down: true, ["keys": "fn"]) }
    #expect(h.scheduler.pending.isEmpty)
  }
}

@Suite struct SwitcherWatchdogTests {
  @Test func idleSessionIsCancelledAndCommandReleased() throws {
    let h = Harness()
    try h.slide("apps.switcher", 0, phase: .began)
    // Batch 26 ruling (the switcher opens on one step of travel, never on contact): the watchdog arms when it opens.
    #expect(h.scheduler.pending.isEmpty)
    try h.slide("apps.switcher", 0.1)
    #expect(h.scheduler.pending.map(\.delay) == [ActionRegistry.switcherIdleTimeout])
    #expect(ActionRegistry.switcherIdleTimeout == 10)
    h.scheduler.advance(by: 10)
    #expect(
      h.keyboard.events == [
        "cmd down", "cmd+tab down", "cmd+tab up", "cmd+escape down", "cmd+escape up", "cmd up",
      ])
    #expect(h.keyboard.allReleased)
    h.scheduler.advance(by: 100)
    #expect(h.keyboard.events.count == 6)
  }

  @Test func everyEventPushesTheDeadlineBack() throws {
    let h = Harness()
    try h.slide("apps.switcher", 0, phase: .began)
    // Batch 26 ruling (the switcher opens on one step of travel, never on contact): open it first.
    try h.slide("apps.switcher", 0.1)
    for _ in 0..<5 {
      h.scheduler.advance(by: 9)
      try h.slide("apps.switcher", 0.01)
    }
    #expect(h.keyboard.heldModifiers == [.cmd])
    #expect(h.scheduler.pending.count == 1)
    h.scheduler.advance(by: 10)
    #expect(h.keyboard.allReleased)
    #expect(h.keyboard.events.suffix(3) == ["cmd+escape down", "cmd+escape up", "cmd up"])
  }

  @Test func normalEndDisarms() throws {
    // keepOpenMS 0: the stroke-at-a-time switcher this test was written for (batch 20).
    let h = Harness()
    try h.slide("apps.switcher", 0, phase: .began, ["keepOpenMS": "0"])
    // Batch 26 ruling (the switcher opens on one step of travel, never on contact): open it first.
    try h.slide("apps.switcher", 0.1, ["keepOpenMS": "0"])
    try h.slide("apps.switcher", 0, phase: .ended, ["keepOpenMS": "0"])
    #expect(h.scheduler.pending.isEmpty)
    h.scheduler.advance(by: 60)
    #expect(h.keyboard.events == ["cmd down", "cmd+tab down", "cmd+tab up", "cmd up"])
  }

  @Test func staleFireCannotEndANewerSession() throws {
    // keepOpenMS 0: the stroke-at-a-time switcher this test was written for (batch 20).
    let h = Harness()
    // Batch 26 ruling (the switcher opens on one step of travel, never on contact): each session opens on one step of travel (before, each `.began` opened it).
    try h.slide("apps.switcher", 0, phase: .began, ["keepOpenMS": "0"])
    try h.slide("apps.switcher", 0.1, ["keepOpenMS": "0"])
    try h.slide("apps.switcher", 0, phase: .cancelled, ["keepOpenMS": "0"])
    try h.slide("apps.switcher", 0, phase: .began, ["keepOpenMS": "0"])
    try h.slide("apps.switcher", 0.1, ["keepOpenMS": "0"])
    let eventsBefore = h.keyboard.events
    h.scheduler.fireLate(h.scheduler.scheduled[0])
    #expect(h.keyboard.events == eventsBefore)
    #expect(h.keyboard.heldModifiers == [.cmd])
  }
}
