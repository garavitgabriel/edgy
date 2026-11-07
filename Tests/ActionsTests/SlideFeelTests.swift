import EdgyCore
import Foundation
import Testing

@testable import Actions

// Batch 20: the shared slide feel (`SlideFeel`, `SlideStepper`, `LevelFeel`) and how the stepped
// and level actions use it.

private let frame = 1.0 / 120.0

/// A steady slide: `mm` of travel at `speed` mm/s, one motion per 120 Hz frame from `start`.
private func steady(_ mm: Double, speed: Double, from start: TimeInterval = 0) -> [SlideMotion] {
  let perFrame = speed * frame * (mm < 0 ? -1 : 1)
  let count = Int((abs(mm) / abs(perFrame)).rounded())
  return (1...count).map { SlideMotion(deltaMM: perFrame, timestamp: start + Double($0) * frame) }
}

/// Resting at an end for `seconds`, one report per frame.
private func resting(_ side: Int, for seconds: Double, from start: TimeInterval) -> [SlideMotion] {
  let count = Int((seconds / frame).rounded())
  return (0..<count).map { SlideMotion(deltaMM: 0, timestamp: start + Double($0) * frame, atEnd: side) }
}

private func steps(_ stepper: inout SlideStepper, _ motions: [SlideMotion]) -> Int {
  motions.reduce(0) { $0 + stepper.advance(travel: $1.deltaMM, motion: $1).steps }
}

@Suite struct SlideFeelModelTests {
  @Test func gainIsOneWhenSlow() {
    for speed in [0.0, 10, 30, SlideFeel.speedUpStartMMPerS] {
      #expect(SlideFeel.gain(speed: speed, maxGain: SlideFeel.steppedMaxGain) == 1)
    }
  }

  @Test func gainIsMonotonicAndContinuous() {
    var last = 1.0
    for speed in stride(from: 0.0, through: 1000, by: 1) {
      let gain = SlideFeel.gain(speed: speed, maxGain: SlideFeel.steppedMaxGain)
      #expect(gain >= last)
      // Gentle: no 1 mm/s change moves the gain by more than 2 %.
      #expect(gain - last < 0.02)
      last = gain
    }
  }

  @Test func gainIsCapped() {
    for speed in [SlideFeel.speedUpFullMMPerS, 500, 5000, .infinity] {
      let stepped = SlideFeel.gain(speed: speed, maxGain: SlideFeel.steppedMaxGain)
      #expect(stepped <= SlideFeel.steppedMaxGain)
    }
    #expect(SlideFeel.gain(speed: 1000, maxGain: SlideFeel.steppedMaxGain) == SlideFeel.steppedMaxGain)
    #expect(SlideFeel.gain(speed: .nan, maxGain: 3) == 1)
  }

  @Test func levelGainIsGentlerThanSteppedGain() {
    for speed in stride(from: 61.0, through: 600, by: 20) {
      #expect(
        SlideFeel.gain(speed: speed, maxGain: SlideFeel.levelMaxGain)
          < SlideFeel.gain(speed: speed, maxGain: SlideFeel.steppedMaxGain))
    }
    #expect(SlideFeel.levelMaxGain <= 2)
  }

  @Test func endRateEasesInThenHolds() {
    #expect(SlideFeel.endRate(after: 0) == SlideFeel.endStartRate)
    #expect(SlideFeel.endRate(after: SlideFeel.endEaseInS / 2) == 4)
    #expect(SlideFeel.endRate(after: SlideFeel.endEaseInS) == SlideFeel.endFullRate)
    #expect(SlideFeel.endRate(after: 10) == 6)
  }

  @Test func speedTracksASteadySlideAndIgnoresTheFirstFrame() {
    var speed = SlideSpeed()
    let motions = steady(60, speed: 200)
    let first = speed.update(motions[0])
    #expect(first <= SlideFeel.speedUpStartMMPerS)
    var last = first
    for motion in motions.dropFirst() { last = speed.update(motion) }
    #expect(abs(last - 200) < 5)
    // Resting end reports don't change it.
    #expect(speed.update(SlideMotion(deltaMM: 0, timestamp: 2, atEnd: 1)) == last)
  }

  @Test func speedStartsOverAfterAPause() {
    var speed = SlideSpeed()
    for motion in steady(30, speed: 300) { _ = speed.update(motion) }
    let resumed = speed.update(SlideMotion(deltaMM: 2.5, timestamp: 5))
    #expect(resumed <= SlideFeel.speedUpStartMMPerS)
  }
}

@Suite struct SlideStepperTests {
  @Test func speedUpOffStepsExactlyByDistance() {
    var stepper = SlideStepper(step: 8, speedUp: false)
    #expect(steps(&stepper, steady(80, speed: 400)) == 10)
  }

  @Test func slowSlidesStepByDistanceWithSpeedUpOn() {
    var stepper = SlideStepper(step: 8, speedUp: true)
    #expect(steps(&stepper, steady(80, speed: 40)) == 10)
  }

  @Test func aQuickFlickStepsFurtherButCapped() {
    var slow = SlideStepper(step: 8, speedUp: true)
    var quick = SlideStepper(step: 8, speedUp: true)
    let slowSteps = steps(&slow, steady(40, speed: 40))
    let quickSteps = steps(&quick, steady(40, speed: 400))
    #expect(slowSteps == 5)
    #expect(quickSteps > slowSteps)
    #expect(quickSteps <= Int(40 * SlideFeel.steppedMaxGain / 8))
  }

  @Test func carryPersistsAcrossUpdates() {
    var stepper = SlideStepper(step: 8, speedUp: false)
    #expect(stepper.advance(travel: 5, motion: SlideMotion(deltaMM: 5, timestamp: 0)).steps == 0)
    #expect(stepper.advance(travel: 5, motion: SlideMotion(deltaMM: 5, timestamp: 1)).steps == 1)
    #expect(stepper.carry == 2)
  }

  @Test func noMotionIsPlainStepping() {
    var stepper = SlideStepper(step: 0.1, speedUp: true)
    #expect(stepper.advance(travel: 0.35, motion: nil).steps == 3)
    #expect(stepper.advance(travel: -0.1, motion: nil).steps == 0)
  }

  @Test func endSteppingReachesItsSteadyRate() {
    var stepper = SlideStepper(step: 8, speedUp: false)
    // ∫ rate over 2 s: 2.4 steps while easing in (0.6 s), then 6/s for 1.4 s = 10.8.
    let count = steps(&stepper, resting(1, for: 2, from: 10))
    #expect(count == 10)
  }

  @Test func endSteppingEasesIn() {
    var stepper = SlideStepper(step: 8, speedUp: false)
    var firstStep: TimeInterval?
    for motion in resting(1, for: 1, from: 0) where firstStep == nil {
      if stepper.advance(travel: 0, motion: motion).steps != 0 { firstStep = motion.timestamp }
    }
    // 2t + (10/3)t² = 1 → t ≈ 0.32 s: later than a full-rate step (1/6 s), sooner than half a second.
    #expect(firstStep.map { $0 > 0.3 && $0 < 0.36 } == true)
  }

  @Test func endSteppingStopsWhenTheFingerMovesAndRestartsEased() {
    var stepper = SlideStepper(step: 8, speedUp: false)
    _ = steps(&stepper, resting(1, for: 2, from: 0))
    // One frame of motion (back off the end): no end steps from it.
    let moved = stepper.advance(travel: -1, motion: SlideMotion(deltaMM: -1, timestamp: 2.01))
    #expect(moved.steps == 0)
    // A new end run eases in again: nothing in its first 0.3 s.
    #expect(steps(&stepper, resting(1, for: 0.3, from: 2.02)) == 0)
  }

  @Test func endSteppingFollowsTheEndAndFlagsItsFirstStep() {
    var stepper = SlideStepper(step: 8, speedUp: false)
    var results: [SlideStepResult] = []
    for motion in resting(-1, for: 1, from: 0) {
      let result = stepper.advance(travel: 0, motion: motion)
      if result.steps != 0 { results.append(result) }
    }
    #expect(results.allSatisfy { $0.steps == -1 })
    #expect(results.first?.endStarted == true)
    #expect(results.dropFirst().allSatisfy { !$0.endStarted })
  }

  @Test func endStepsIgnoreLeftoverCarry() {
    var stepper = SlideStepper(step: 8, speedUp: false)
    _ = stepper.advance(travel: 7, motion: SlideMotion(deltaMM: 7, timestamp: 0))
    _ = steps(&stepper, resting(1, for: 0.5, from: 0.1))
    #expect(stepper.carry == 0)
  }
}

@Suite struct SlideStepsFeelTests {
  static let id = BuiltInAction.keyboardSlideSteps
  static let keys = ["upKeys": "cmd+]", "downKeys": "cmd+[", "speedUp": "off"]

  func slide(_ h: Harness, _ motions: [SlideMotion], zoneMM: Double, _ extra: [String: String] = [:]) throws {
    let parameters = Self.keys.merging(extra) { _, new in new }
    try h.move(Self.id, mm: 0, at: 0, zoneMM: zoneMM, phase: .began, parameters)
    for motion in motions {
      try h.move(Self.id, mm: motion.deltaMM, at: motion.timestamp, zoneMM: zoneMM, atEnd: motion.atEnd, parameters)
    }
    try h.move(Self.id, mm: 0, at: 9, zoneMM: zoneMM, phase: .ended, parameters)
  }

  @Test func millimetreStepsAreTheSameOnEveryPadAndSegment() throws {
    // A whole 150 mm edge, a quarter of a 100 mm edge: 40 mm is five presses on both.
    for zone in [150.0, 25.0] {
      let h = Harness()
      try slide(h, steady(40, speed: 50), zoneMM: zone, ["stepMM": "8"])
      #expect(h.keyboard.posted == Array(repeating: "cmd+rightbracket", count: 5))
    }
  }

  @Test func theDefaultStepIsEightMillimetres() throws {
    let h = Harness()
    try slide(h, steady(-24, speed: 50), zoneMM: 120)
    #expect(h.keyboard.posted == Array(repeating: "cmd+leftbracket", count: 3))
  }

  @Test func aLegacyFractionStepIsConvertedWithTheZoneLength() throws {
    // `step` 0.1 on a 120 mm zone = 12 mm per press: 36 mm → 3. On a 60 mm zone, 6 mm → 6.
    let long = Harness()
    try slide(long, steady(36, speed: 50), zoneMM: 120, ["step": "0.1"])
    #expect(long.keyboard.posted.count == 3)
    let short = Harness()
    try slide(short, steady(38, speed: 50), zoneMM: 60, ["step": "0.1"])
    #expect(short.keyboard.posted.count == 6)
  }

  @Test func stepMMWinsOverALegacyStep() throws {
    let h = Harness()
    try slide(h, steady(38, speed: 50), zoneMM: 120, ["step": "0.1", "stepMM": "6"])
    #expect(h.keyboard.posted.count == 6)
  }

  @Test func withoutAMotionTheLegacyFractionBehaviourIsUnchanged() throws {
    let h = Harness()
    let parameters = ["upKeys": "cmd+]", "downKeys": "cmd+[", "step": "0.1"]
    try h.slide(Self.id, 0, phase: .began, parameters)
    try h.slide(Self.id, 0.35, parameters)
    #expect(h.keyboard.posted.count == 3)
  }

  @Test func aQuickFlickSendsSeveralPressesWithSpeedUpOn() throws {
    let off = Harness()
    try slide(off, steady(40, speed: 400), zoneMM: 100, ["stepMM": "8"])
    let on = Harness()
    try slide(on, steady(40, speed: 400), zoneMM: 100, ["stepMM": "8", "speedUp": "on"])
    #expect(off.keyboard.posted.count == 5)
    #expect(on.keyboard.posted.count > 5)
  }

  @Test func restingAtTheEndKeepsPressingWithAClickAtTheStart() throws {
    let h = Harness()
    try slide(h, steady(17, speed: 50) + resting(1, for: 2, from: 1), zoneMM: 100, ["stepMM": "8"])
    #expect(h.keyboard.posted.count == 2 + 10)
    #expect(h.haptics.strongTicks == 1)
    #expect(h.haptics.ticks == 12)
  }

  @Test func outOfRangeStepMMFails() {
    let h = Harness()
    #expect(throws: ActionError.missingParameter(Self.id, name: "stepMM")) {
      try slide(h, steady(16, speed: 50), zoneMM: 100, ["stepMM": "40"])
    }
    #expect(throws: ActionError.missingParameter(Self.id, name: "speedUp")) {
      try slide(h, steady(16, speed: 50), zoneMM: 100, ["speedUp": "fast"])
    }
  }
}

@Suite struct LevelSpeedUpTests {
  static let id = BuiltInAction.volume

  func level(_ motions: [SlideMotion], _ parameters: [String: String], motion: Bool = true) throws -> Double {
    let h = Harness(settings: .with(hud: .none))
    h.audio.volume = 0.2
    try h.move(Self.id, mm: 0, at: 0, phase: .began, parameters)
    for m in motions {
      if motion {
        try h.move(Self.id, mm: m.deltaMM, at: m.timestamp, parameters)
      } else {
        try h.slide(Self.id, m.deltaMM / 100, parameters)
      }
    }
    return h.audio.volume
  }

  @Test func speedUpOffIsTheOldBehaviourExactly() throws {
    let flick = steady(20, speed: 400)
    let off = try level(flick, ["speedUp": "off"])
    let old = try level(flick, [:], motion: false)
    #expect(off == old)
    #expect(abs(off - 0.4) < 1e-9)
  }

  @Test func withoutAMotionSpeedUpChangesNothing() throws {
    let flick = steady(20, speed: 400)
    #expect(try level(flick, ["speedUp": "on"], motion: false) == level(flick, ["speedUp": "off"], motion: false))
  }

  @Test func aSlowSlideIsUnchangedWithSpeedUpOn() throws {
    let slow = steady(20, speed: 40)
    #expect(abs(try level(slow, [:]) - level(slow, ["speedUp": "off"])) < 1e-9)
  }

  @Test func aQuickFlickMovesTheLevelFurtherButGently() throws {
    let flick = steady(20, speed: 400)
    let on = try level(flick, [:]) - 0.2
    let off = try level(flick, ["speedUp": "off"]) - 0.2
    #expect(on > off * 1.3)
    #expect(on <= off * SlideFeel.levelMaxGain + 1e-9)
  }

  @Test func restingAtTheEndDoesNotMoveALevel() throws {
    let h = Harness(settings: .with(hud: .none))
    h.audio.volume = 0.98
    try h.move(Self.id, mm: 0, at: 0, phase: .began)
    for motion in resting(1, for: 1, from: 0.1) {
      try h.move(Self.id, mm: 0, at: motion.timestamp, atEnd: 1)
    }
    #expect(h.audio.volume == 0.98)
  }
}
