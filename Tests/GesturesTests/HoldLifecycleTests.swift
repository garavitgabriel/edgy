import EdgyCore
import Testing

@testable import Gestures

// Long-press lifecycle: `.began` at recognition, then exactly one `.ended` (lift) or `.cancelled`
// (touch taken away), with the fingers claimed for the whole hold.

@Test func edgeHoldEndsAtLiftAndStaysClaimedUntilThen() throws {
  let builder = TraceBuilder([Stroke(id: 1, [(0, 60, 3), (1.0, 60, 3)])])
  let run = replay(builder.frames(), zones: [.edge(.bottom)], slideZones: [], longPressZones: [.edge(.bottom)])
  #expect(holdPhases(run) == [.began, .ended])
  let began = try #require(run.events.first)
  let ended = try #require(run.events.last)
  #expect(run.relative(began) >= 0.5 && run.relative(began) < 0.52)
  #expect(run.relative(ended) > 1.0 && run.relative(ended) < 1.02)
  #expect(ended.zone == .edge(.bottom))
  let beganFrame = try #require(run.outputs.firstIndex { !$0.events.isEmpty })
  for (index, output) in run.outputs.enumerated() {
    let shouldClaim = index >= beganFrame && index <= builder.frameIndex(1.0)
    #expect(output.claimedContactIDs == (shouldClaim ? [1] : []), "frame \(index)")
  }
  expectHoldsArePaired(run)
}

@Test func holdThatMovesAfterItBeganIsNotASwipe() {
  // Push-to-talk: the finger shifts along the edge while talking. The hold must survive and end
  // at lift, never turn into a swipe (which would strand the hold with no `.ended`).
  let frames = TraceBuilder([Stroke(id: 1, [(0, 60, 3), (0.6, 60, 3), (0.65, 75, 3), (0.9, 75, 3)])]).frames()
  let run = replay(frames, zones: [.edge(.bottom)], slideZones: [], longPressZones: [.edge(.bottom)])
  #expect(run.events.map(\.kind) == [.longPress, .longPress])
  #expect(holdPhases(run) == [.began, .ended])
  #expect(run.rejections.isEmpty)
  expectHoldsArePaired(run)
  #expect(run.endsUnclaimed)
}

@Test func holdThatDriftsInwardAfterItBeganIsNotHandedOff() {
  let frames = TraceBuilder([Stroke(id: 1, [(0, 146, 50), (0.6, 146, 50), (0.7, 130, 50), (0.9, 130, 50)])])
    .frames()
  let run = replay(frames, zones: [.edge(.right)], slideZones: [], longPressZones: [.edge(.right)])
  #expect(holdPhases(run) == [.began, .ended])
  #expect(run.rejections.isEmpty)
  expectHoldsArePaired(run)
}

@Test func holdOnASlideZoneFreezesSlideOutputUntilLift() {
  // Slide and long-press both bound: the resting finger claims a slide at the dwell, the hold
  // begins at 500 ms, and from then on motion emits no slide deltas.
  let frames = TraceBuilder([Stroke(id: 1, [(0, 146, 40), (0.6, 146, 40), (0.8, 146, 70), (0.9, 146, 70)])])
    .frames()
  let run = replay(frames, zones: [.edge(.right)])
  #expect(holdPhases(run) == [.began, .ended])
  #expect(run.changed.isEmpty)
  #expect(run.slideEvents.map(\.phase) == [.began, .ended])
  expectHoldsArePaired(run)
  expectClaimsFollowSlide(run)
}

@Test func cornerHoldThatMovesAfterItBeganStillEndsAtLift() {
  let frames = TraceBuilder([Stroke(id: 1, [(0, 4, 91), (0.6, 4, 91), (0.7, 9, 86), (0.9, 9, 86)])]).frames()
  let run = replay(frames, zones: [.corner(.topLeft)])
  #expect(holdPhases(run) == [.began, .ended])
  #expect(run.rejections.isEmpty)
  expectHoldsArePaired(run)
}

@Test func palmSpreadingUnderAHoldCancelsIt() throws {
  var stroke = Stroke(id: 1, [(0, 4, 91), (1.2, 4, 91)])
  stroke.grownMajorAxisMM = 20
  stroke.growS = 1.0  // crosses the 18 mm palm limit at ~0.82 s, after the hold began
  let run = replay(TraceBuilder([stroke]).frames(), zones: [.corner(.topLeft)])
  #expect(holdPhases(run) == [.began, .cancelled])
  #expect(run.rejections == [Rejection(id: 1, reason: .palm)])
  let cancelledFrame = try #require(run.outputs.firstIndex { $0.events.contains { $0.phase == .cancelled } })
  #expect(run.outputs[cancelledFrame].claimedContactIDs.isEmpty)
  expectHoldsArePaired(run)
}

@Test func extraFingersLandingDuringAHoldCancelIt() {
  let frames = TraceBuilder([
    Stroke(id: 1, [(0, 4, 91), (1.2, 4, 91)]),
    Stroke(id: 2, [(0.7, 70, 50), (1.0, 70, 40)]),
    Stroke(id: 3, [(0.71, 85, 50), (1.0, 85, 40)]),
  ]).frames()
  let run = replay(frames, zones: [.corner(.topLeft)])
  #expect(holdPhases(run) == [.began, .cancelled])
  #expect(run.rejections.contains(Rejection(id: 1, reason: .tooManyContacts)))
  expectHoldsArePaired(run)
  #expect(run.endsUnclaimed)
}

@Test func oneLateRestingFingerDoesNotCancelAHold() {
  // Same rule as a claimed slide: a single contact landing well after the hold (a thumb coming to
  // rest) leaves it alone; only 3+ contacts or a finger that landed together with it revoke it.
  let frames = TraceBuilder([
    Stroke(id: 1, [(0, 4, 91), (1.2, 4, 91)]),
    Stroke(id: 2, [(0.8, 75, 30), (1.0, 75, 30)]),
  ]).frames()
  let run = replay(frames, zones: [.corner(.topLeft)])
  #expect(holdPhases(run) == [.began, .ended])
  expectHoldsArePaired(run)
}

@Test func resetMidHoldEmitsNothingAndForgetsTheHold() {
  let frames = TraceBuilder([Stroke(id: 1, [(0, 4, 91), (1.0, 4, 91)])]).frames()
  let pipeline = makeGestureRecognizer()
  let context = GestureContext(
    settings: .test, enabledZones: [.corner(.topLeft)], secondsSinceLastKeyPress: nil)
  let device = TraceBuilder.defaultDevice
  let resetAt = 84  // 0.7 s: the hold began at 0.5 s
  var before: [GestureOutput] = []
  for frame in frames[..<resetAt] { before.append(pipeline.process(frame, device: device, context: context)) }
  let phasesBefore = before.flatMap(\.events).map(\.phase)
  #expect(phasesBefore == [.began])
  pipeline.reset()
  let after = frames[resetAt...].map { pipeline.process($0, device: device, context: context) }
  // The engine closes the hold it was told about; the pipeline must not emit a stray `.ended`
  // for a touch it no longer knows (the finger, now unknown, lifts before it could hold again).
  let eventsAfter = after.flatMap(\.events)
  #expect(eventsAfter.isEmpty)
  #expect(after.allSatisfy { $0.claimedContactIDs.isEmpty })
}
