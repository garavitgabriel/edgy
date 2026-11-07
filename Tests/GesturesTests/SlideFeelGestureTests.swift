import EdgyCore
import Foundation
import Testing

@testable import Gestures

// Batch 20: `zoneLengthMM`, `atEnd`, per-zone hold time, holds that survive pointing, and the
// clearer flick a swipe needs on a zone with a slide bound.

private let right = Zone.edge(.right)

private func run(
  _ strokes: [Stroke], zones: Set<Zone> = [right], device: TouchDeviceInfo = TraceBuilder.defaultDevice,
  slideZones: Set<Zone>? = nil, longPressZones: Set<Zone>? = nil, longPressMS: [Zone: Double]? = nil,
  buttons: [ClosedRange<Double>] = []
) -> Replay {
  var builder = TraceBuilder(strokes)
  builder.device = device
  var frames = builder.frames()
  if !buttons.isEmpty {
    for index in frames.indices {
      let t = frames[index].timestamp - builder.startTime
      frames[index].buttonDown = buttons.contains { $0.contains(t) }
    }
  }
  let context = GestureContext(
    settings: .test, enabledZones: zones, secondsSinceLastKeyPress: nil, slideZones: slideZones,
    longPressZones: longPressZones, longPressMSByZone: longPressMS)
  let recognizer = makeGestureRecognizer()
  return Replay(frames: frames, outputs: frames.map { recognizer.process($0, device: device, context: context) })
}

private func travelMM(_ run: Replay) -> Double {
  run.slideEvents.reduce(0) { $0 + $1.delta * $1.zoneLengthMM }
}

// MARK: - zoneLengthMM

@Test func slideEventsCarryTheZoneLength() {
  let whole = run([Stroke(id: 1, [(0, 146, 30), (0.4, 146, 60)])])
  #expect(!whole.slideEvents.isEmpty)
  #expect(whole.slideEvents.allSatisfy { $0.zoneLengthMM == 95 })
  let third = Zone.edge(.right, segment: 1, segments: 3)
  let segment = run([Stroke(id: 1, [(0, 146, 35), (0.4, 146, 55)])], zones: [third])
  #expect(!segment.slideEvents.isEmpty)
  #expect(segment.slideEvents.allSatisfy { abs($0.zoneLengthMM - 95.0 / 3) < 1e-9 })
}

@Test func travelInMillimetresIsTheSameOnTwoPadSizes() {
  let small = TouchDeviceInfo(id: 7, kind: .builtInTrackpad, sensorSizeMM: Size2D(width: 100, height: 70), familyID: 0)
  let a = run([Stroke(id: 1, [(0, 146, 20), (0.5, 146, 50)])])
  let b = run([Stroke(id: 1, [(0, 96, 20), (0.5, 96, 50)])], device: small)
  // Normalized deltas differ (95 mm vs 70 mm edges); millimetres don't.
  #expect(abs(travelMM(a) - travelMM(b)) < 0.01)
  #expect(abs(travelMM(a) - 30) < 0.01)
  #expect(a.changed.first?.delta != b.changed.first?.delta)
}

@Test func discreteEventsCarryTheZoneLengthToo() {
  let hold = run([Stroke(id: 1, [(0, 146, 40), (0.7, 146, 40)])], slideZones: [])
  #expect(hold.events.filter { $0.kind == .longPress }.allSatisfy { $0.zoneLengthMM == 95 })
}

// MARK: - atEnd

@Test func restingAtTheHighEndReportsAtEndEveryFrame() {
  // Slide up to 2 mm from the top and rest there for half a second.
  let run = run([Stroke(id: 1, [(0, 146, 40), (0.3, 146, 93), (0.8, 146, 93)])])
  let ends = run.changed.filter { $0.atEnd != 0 }
  #expect(ends.count > 30)
  #expect(ends.allSatisfy { $0.atEnd == 1 && $0.delta == 0 })
  // Not before the slide has rested (`restDurationS` after it stops), and never while moving.
  #expect((ends.first.map(run.relative) ?? 0) >= 0.4 - 1e-9)
  #expect(run.changed.filter { $0.delta != 0 }.allSatisfy { $0.atEnd == 0 })
  #expect(run.slideEvents.last?.phase == .ended)
}

@Test func restingAtTheLowEndReportsMinusOne() {
  // Slow enough (114 mm/s) to be a slide wherever it starts, into the bottom corner's area.
  let run = run([Stroke(id: 1, [(0, 146, 60), (0.5, 146, 3), (1.0, 146, 3)])])
  let ends = run.changed.filter { $0.atEnd != 0 }
  #expect(!ends.isEmpty)
  #expect(ends.allSatisfy { $0.atEnd == -1 })
}

@Test func restingInTheMiddleIsNotAnEnd() {
  let run = run([Stroke(id: 1, [(0, 146, 30), (0.3, 146, 60), (0.9, 146, 60)])])
  #expect(!run.changed.isEmpty)
  #expect(run.changed.allSatisfy { $0.atEnd == 0 })
}

@Test func restingAtTheEndWithoutHavingMovedIsNotAnEnd() {
  // A dwell claim that lands in the end band and never moves (a finger parked there).
  let third = Zone.edge(.right, segment: 1, segments: 3)
  let run = run([Stroke(id: 1, [(0, 146, 62), (0.8, 146, 62)])], zones: [third], longPressZones: [])
  #expect(run.slideEvents.first?.phase == .began)
  #expect(run.changed.isEmpty)
}

@Test func movingAwayFromTheEndStopsAtEnd() {
  let run = run([Stroke(id: 1, [(0, 146, 40), (0.3, 146, 93), (0.7, 146, 93), (0.9, 146, 70), (1.0, 146, 70)])])
  let ends = run.changed.filter { $0.atEnd != 0 }
  let firstMoveBack = run.changed.first { $0.delta < 0 }
  #expect(!ends.isEmpty)
  #expect(firstMoveBack != nil)
  // Every end report comes before the finger moved back.
  #expect(ends.allSatisfy { $0.timestamp < (firstMoveBack?.timestamp ?? 0) })
}

@Test func theEndBandIsSixMillimetres() {
  // 7.5 mm from the top: outside the band. 5 mm: inside.
  let outside = run([Stroke(id: 1, [(0, 146, 40), (0.3, 146, 87.5), (0.8, 146, 87.5)])])
  let inside = run([Stroke(id: 1, [(0, 146, 40), (0.3, 146, 90), (0.8, 146, 90)])])
  #expect(outside.changed.allSatisfy { $0.atEnd == 0 })
  #expect(inside.changed.contains { $0.atEnd == 1 })
}

@Test func aSegmentHasItsOwnEnds() {
  // The middle third of the right edge spans 31.7…63.3 mm; its band there is 6 mm.
  let third = Zone.edge(.right, segment: 1, segments: 3)
  let run = run([Stroke(id: 1, [(0, 146, 40), (0.3, 146, 61), (0.8, 146, 61)])], zones: [third])
  #expect(run.changed.contains { $0.atEnd == 1 })
  #expect(!run.changed.contains { $0.atEnd == -1 })
}

@Test func shortSegmentsCapTheBandAtAFifthOfTheirLength() {
  let step = FrameStep(
    frame: TouchFrame(deviceID: 7, timestamp: 0, frameNumber: 0, contacts: []),
    geometry: ZoneGeometry(device: TraceBuilder.defaultDevice, settings: .test),
    context: GestureContext(settings: .test, enabledZones: [], secondsSinceLastKeyPress: nil),
    timing: Timing(.test), tuning: .standard, state: DeviceState())
  // A quarter of the right edge is 23.75 mm: band = 4.75 mm.
  let quarter = Zone.edge(.right, segment: 0, segments: 4)
  #expect(step.endSide(quarter, edge: .right, along: 19.5) == 1)
  #expect(step.endSide(quarter, edge: .right, along: 18.5) == 0)
  #expect(step.endSide(quarter, edge: .right, along: 4.5) == -1)
  #expect(step.endSide(quarter, edge: .right, along: 30) == 1)
  #expect(step.endSide(.corner(.topLeft), edge: .right, along: 0) == 0)
}

// MARK: - Per-zone hold time

@Test func perZoneHoldTimeFiresEarlier() {
  let fast = Zone.edge(.bottom)
  let strokes = [Stroke(id: 1, [(0, 60, 3), (0.7, 60, 3)])]
  let run = run(strokes, zones: [fast], slideZones: [], longPressMS: [fast: 300])
  let began = run.events.first { $0.kind == .longPress && $0.phase == .began }
  #expect(began.map(run.relative).map { $0 >= 0.3 && $0 < 0.32 } == true)
}

@Test func otherZonesKeepTheGlobalHoldTime() {
  let bottom = Zone.edge(.bottom)
  let run = run(
    [Stroke(id: 1, [(0, 146, 40), (0.7, 146, 40)])], zones: [right, bottom], slideZones: [],
    longPressMS: [bottom: 300])
  let began = run.events.first { $0.kind == .longPress && $0.phase == .began }
  #expect(began.map(run.relative).map { $0 >= 0.5 && $0 < 0.52 } == true)
}

@Test func perZoneHoldTimeAppliesToCornersAndSlideZones() {
  let corner = Zone.corner(.bottomLeft)
  let c = run([Stroke(id: 1, [(0, 4, 4), (0.6, 4, 4)])], zones: [corner], longPressMS: [corner: 200])
  #expect(c.events.first { $0.kind == .longPress }.map(c.relative).map { $0 >= 0.2 && $0 < 0.22 } == true)
  // A zone with a slide too: the dwell claims first, the hold still fires at its own time.
  let s = run([Stroke(id: 1, [(0, 146, 40), (0.6, 146, 40)])], longPressMS: [right: 250])
  #expect(s.events.first { $0.kind == .longPress }.map(s.relative).map { $0 >= 0.25 && $0 < 0.27 } == true)
}

// MARK: - Holds survive pointing

@Test func edgeHoldSurvivesAnotherFingerPointingAfterItBegan() {
  let run = run(
    [
      Stroke(id: 1, [(0, 146, 40), (1.5, 146, 40)]),
      Stroke(id: 2, [(0.8, 60, 40), (0.9, 60, 40), (1.3, 30, 60)]),
    ], slideZones: [])
  #expect(holdPhases(run) == [.began, .ended])
  #expect(run.rejections.filter { $0.id == 1 }.isEmpty)
  #expect(run.endsUnclaimed)
}

@Test func pointingBeforeTheHoldBeginsStillRevokesIt() {
  // The second finger moves at 0.3 s, before the 500 ms hold: no hold, the touch is rejected.
  let run = run(
    [
      Stroke(id: 1, [(0, 146, 40), (1.0, 146, 40)]),
      Stroke(id: 2, [(0.2, 60, 40), (0.25, 60, 40), (0.45, 30, 60)]),
    ], slideZones: [])
  #expect(holdPhases(run).isEmpty || holdPhases(run) == [.began, .cancelled])
  #expect(!run.events.contains { $0.kind == .longPress && $0.phase == .ended })
}

@Test func beganHoldStillCancelsWhenTheHeldTouchBecomesAPalm() {
  // The held contact flattens past the palm limit (18 mm) at ~0.86 s, after the hold began.
  var flattening = Stroke(id: 1, [(0, 146, 40), (1.5, 146, 40)])
  flattening.grownMajorAxisMM = 30
  flattening.growS = 2.0
  let run = run([flattening], slideZones: [])
  #expect(holdPhases(run) == [.began, .cancelled])
  #expect(run.rejections.contains(Rejection(id: 1, reason: .palm)))
}

@Test func aPalmRestingElsewhereLeavesABeganHoldAlone() {
  var palm = Stroke(id: 2, [(0.8, 40, 20), (1.2, 40, 20)])
  palm.majorAxisMM = 25
  let run = run([Stroke(id: 1, [(0, 146, 40), (1.5, 146, 40)]), palm], slideZones: [])
  #expect(holdPhases(run) == [.began, .ended])
  #expect(run.rejections.contains(Rejection(id: 2, reason: .palm)))
}

@Test func beganHoldStillCancelsOnAClick() {
  let run = run([Stroke(id: 1, [(0, 146, 40), (1.5, 146, 40)])], slideZones: [], buttons: [0.9...1.0])
  #expect(holdPhases(run) == [.began, .cancelled])
  #expect(run.rejections.contains(Rejection(id: 1, reason: .physicalClick)))
}

@Test func beganHoldStillCancelsOnThreeContacts() {
  let run = run(
    [
      Stroke(id: 1, [(0, 146, 40), (1.5, 146, 40)]),
      Stroke(id: 2, [(0.8, 60, 40), (1.2, 60, 40)]),
      Stroke(id: 3, [(0.9, 80, 40), (1.2, 80, 40)]),
    ], slideZones: [])
  #expect(holdPhases(run) == [.began, .cancelled])
}

// MARK: - Swipes on a zone with a slide

@Test func aMediumFlickOnASlideZoneIsASlide() {
  // ~220 mm/s: a swipe where nothing says a slide is bound, a slide where one is.
  let stroke = [Stroke(id: 1, [(0, 146, 30), (0.1, 146, 52)])]
  let unknown = run(stroke)
  let slide = run(stroke, slideZones: [right])
  #expect(unknown.events.contains { $0.kind == .swipe(.up) })
  #expect(!slide.events.contains { $0.kind == .swipe(.up) })
  #expect(slide.slideEvents.first?.phase == .began)
}

@Test func aClearFlickOnASlideZoneIsStillASwipe() {
  // ~400 mm/s over 20 mm.
  let run = run([Stroke(id: 1, [(0, 146, 30), (0.05, 146, 50)])], slideZones: [right])
  #expect(run.events.contains { $0.kind == .swipe(.up) })
}
