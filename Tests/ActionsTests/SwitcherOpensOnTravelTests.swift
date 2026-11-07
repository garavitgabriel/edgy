import EdgyCore
import Foundation
import Testing

@testable import Actions

// Batch 26: Switch Apps opens on travel, never on contact. A finger resting on the edge claims a
// slide (`.began`, no travel); the switcher arms but presses nothing until one `stepMM` (8 mm) of
// travel. Mock keyboard only (hard rule 1).

@Suite struct SwitcherOpensOnTravelTests {
  static let id = BuiltInAction.appSwitcher
  static let opening = ["cmd down", "cmd+tab down", "cmd+tab up"]
  static let forward = ["cmd+tab down", "cmd+tab up"]
  static let cancel = ["cmd+escape down", "cmd+escape up", "cmd up"]
  static let off = ["speedUp": "off"]

  /// `mm` of slow travel in 1 mm frames at 60 Hz from `start`.
  func travel(_ h: Harness, _ mm: Double, from start: TimeInterval = 0, _ parameters: [String: String] = off)
    throws
  {
    let frames = Int(abs(mm).rounded())
    for index in 0..<frames {
      try h.move(Self.id, mm: mm < 0 ? -1 : 1, at: start + Double(index + 1) / 60, parameters)
    }
  }

  @Test func aRestingFingerOpensNothing() throws {
    let h = Harness()
    try h.move(Self.id, mm: 0, at: 0, phase: .began, Self.off)
    h.scheduler.advance(by: 30)
    #expect(h.keyboard.events.isEmpty)
    #expect(h.keyboard.allReleased)
    #expect(h.scheduler.pending.isEmpty)
    #expect(h.haptics.ticks == 0 && h.haptics.strongTicks == 0)
  }

  @Test func travelShortOfAStepThenLiftingPressesNothing() throws {
    for keepOpen in ["400", "0"] {
      let parameters = ["speedUp": "off", "keepOpenMS": keepOpen]
      let h = Harness()
      try h.move(Self.id, mm: 0, at: 0, phase: .began, parameters)
      try travel(h, 7, parameters)
      try h.move(Self.id, mm: 0, at: 1, phase: .ended, parameters)
      // No key events at all: no command-up for a command that was never pressed.
      #expect(h.keyboard.events.isEmpty)
      #expect(!h.switcherInput.listening)
      #expect(h.switcherInput.starts == 0)
      h.scheduler.advance(by: 30)
      #expect(h.keyboard.events.isEmpty)
    }
  }

  @Test func beganThenCancelledFortyMillisecondsLaterPressesNothing() throws {
    // The logged misfire: `began` at the top edge, `cancelled` 40 ms later.
    let h = Harness()
    try h.move(Self.id, mm: 0, at: 0, phase: .began, Self.off)
    try h.move(Self.id, mm: 0, at: 0.04, phase: .cancelled, Self.off)
    #expect(h.keyboard.events.isEmpty)
    #expect(!h.switcherInput.listening)
    #expect(h.scheduler.pending.isEmpty)
  }

  @Test func oneStepOfTravelOpensOnTheNextApp() throws {
    let h = Harness()
    try h.move(Self.id, mm: 0, at: 0, phase: .began, Self.off)
    try travel(h, 7)
    #expect(h.keyboard.events.isEmpty)
    try h.move(Self.id, mm: 1, at: 0.2, Self.off)
    #expect(h.keyboard.events == Self.opening)
    #expect(h.keyboard.heldModifiers == [.cmd])
  }

  @Test func twoStepsOpenAndMoveOneApp() throws {
    let h = Harness()
    try h.move(Self.id, mm: 0, at: 0, phase: .began, Self.off)
    try travel(h, 16)
    #expect(h.keyboard.events == Self.opening + Self.forward)
    // In one update too: the opening plus one more tab.
    let one = Harness()
    try one.move(Self.id, mm: 0, at: 0, phase: .began, Self.off)
    try one.move(Self.id, mm: 16, at: 0.01, Self.off)
    #expect(one.keyboard.events == Self.opening + Self.forward)
  }

  @Test func slidingBackOneStepAfterOpeningCancels() throws {
    let h = Harness()
    try h.move(Self.id, mm: 0, at: 0, phase: .began, Self.off)
    try travel(h, 8)
    try travel(h, -8, from: 0.5)
    #expect(h.keyboard.events == Self.opening + Self.cancel)
    #expect(h.keyboard.allReleased)
  }

  @Test func backwardTravelOpensItToo() throws {
    // Travel counts in either direction; the switcher still opens on the next app.
    let h = Harness()
    try h.move(Self.id, mm: 0, at: 0, phase: .began, Self.off)
    try travel(h, -8)
    #expect(h.keyboard.events == Self.opening)
    // A further step back from where it opened cancels, as before.
    try travel(h, -8, from: 0.5)
    #expect(h.keyboard.events == Self.opening + Self.cancel)
    // A long backward jump in one update opens without cancelling in the same frame.
    let one = Harness()
    try one.move(Self.id, mm: 0, at: 0, phase: .began, Self.off)
    try one.move(Self.id, mm: -24, at: 0.01, Self.off)
    #expect(one.keyboard.events == Self.opening)
  }

  @Test func endSteppingWithoutAStepOfTravelOpensNothing() throws {
    let h = Harness()
    try h.move(Self.id, mm: 0, at: 0, phase: .began, Self.off)
    // No travel at all, resting at the end.
    for index in 0..<240 {
      try h.move(Self.id, mm: 0, at: 0.1 + Double(index) / 120, atEnd: 1, Self.off)
    }
    #expect(h.keyboard.events.isEmpty)
    // Short travel, then resting at the end.
    let short = Harness()
    try short.move(Self.id, mm: 0, at: 0, phase: .began, Self.off)
    try travel(short, 5)
    for index in 0..<240 {
      try short.move(Self.id, mm: 0, at: 0.2 + Double(index) / 120, atEnd: 1, Self.off)
    }
    try short.move(Self.id, mm: 0, at: 2.3, phase: .ended, Self.off)
    #expect(short.keyboard.events.isEmpty)
  }

  @Test func aBeganWhileLingeringContinuesWithNoTab() throws {
    let h = Harness()
    try h.move(Self.id, mm: 0, at: 0, phase: .began, Self.off)
    try travel(h, 8)
    try h.move(Self.id, mm: 0, at: 1, phase: .ended, Self.off)
    h.scheduler.advance(by: 0.2)
    try h.move(Self.id, mm: 0, at: 2, phase: .began, Self.off)
    #expect(h.keyboard.events == Self.opening)
    #expect(h.keyboard.heldModifiers == [.cmd])
    // The continued stroke moves from the first step on: no second opening.
    try travel(h, 8, from: 2)
    #expect(h.keyboard.events == Self.opening + Self.forward)
  }

  @Test func hapticOutcomeAndWatchdogComeOnlyWithTheOpening() throws {
    let h = Harness()
    func report(_ mm: Double, at time: TimeInterval, _ phase: GestureEvent.Phase = .changed) throws -> ActionOutcome? {
      try h.registry.performReporting(
        Self.id, input: .delta(mm / 100, phase: phase),
        context: ActionContext(
          frontmostBundleID: nil, parameters: Self.off, motion: SlideMotion(deltaMM: mm, timestamp: time, atEnd: 0)))
    }
    #expect(try report(0, at: 0, .began) == nil)
    #expect(try report(4, at: 0.05) == nil)
    #expect(h.haptics.strongTicks == 0 && h.haptics.ticks == 0)
    #expect(h.scheduler.pending.isEmpty)
    // The step that opens it: the `actionFired` click, the outcome, the watchdog.
    #expect(try report(4, at: 0.1) == ActionOutcome(systemHUDShown: true))
    #expect(h.haptics.strongTicks == 1 && h.haptics.ticks == 0)
    #expect(h.scheduler.pending.map(\.delay) == [ActionRegistry.switcherIdleTimeout])
    #expect(try report(8, at: 0.15) == ActionOutcome(systemHUDShown: true))
    #expect(h.haptics.strongTicks == 1 && h.haptics.ticks == 1)
    #expect(try report(0, at: 0.2, .ended) == ActionOutcome(systemHUDShown: true))
  }

  @Test func theOpeningClickFollowsTheHapticSettings() throws {
    var settings = AppSettings.defaults
    settings.hapticEvents.remove(.actionFired)
    let h = Harness(settings: settings)
    try h.move(Self.id, mm: 0, at: 0, phase: .began, Self.off)
    try travel(h, 8)
    #expect(h.keyboard.events == Self.opening)
    #expect(h.haptics.strongTicks == 0)
  }

  @Test func speedUpNeverShortensTheOpening() throws {
    // A quick flick (400 mm/s) with speed-up on still needs a full 8 mm to open.
    let on = ["speedUp": "on"]
    let h = Harness()
    try h.move(Self.id, mm: 0, at: 0, phase: .began, on)
    try h.move(Self.id, mm: 3.33, at: 1.0 / 120, on)
    try h.move(Self.id, mm: 3.33, at: 2.0 / 120, on)
    #expect(h.keyboard.events.isEmpty)
    try h.move(Self.id, mm: 3.33, at: 3.0 / 120, on)
    #expect(h.keyboard.events == Self.opening)
  }

  @Test func anUnopenedStrokeReplacedByANewOnePressesNothing() throws {
    // A lost end on an armed stroke: the next `.began` replaces it silently.
    let h = Harness()
    try h.move(Self.id, mm: 0, at: 0, phase: .began, Self.off)
    try travel(h, 5)
    try h.move(Self.id, mm: 0, at: 1, phase: .began, Self.off)
    #expect(h.keyboard.events.isEmpty)
    // The new stroke starts from zero: the old 5 mm don't count toward its opening.
    try travel(h, 5, from: 1)
    #expect(h.keyboard.events.isEmpty)
    try travel(h, 3, from: 2)
    #expect(h.keyboard.events == Self.opening)
  }

  @Test func theCatalogSaysTheSwitcherOpensAfterOneStep() throws {
    let switcher = try #require(ActionCatalog.all.first { $0.id == Self.id })
    let step = try #require(switcher.parameters.first { $0.key == ActionParameterKey.stepMM })
    #expect(step.helpText == "Slide this far to open the switcher and move one app.")
    let keys = try #require(ActionCatalog.all.first { $0.id == BuiltInAction.keyboardSlideSteps })
    let keyStep = try #require(keys.parameters.first { $0.key == ActionParameterKey.stepMM })
    #expect(keyStep.helpText != step.helpText)
  }
}
