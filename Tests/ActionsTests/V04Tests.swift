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
