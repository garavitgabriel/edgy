import EdgyCore
import Foundation
import Testing

@testable import Gestures

private let rightEdge: Set<Zone> = [.edge(.right)]

// MARK: - Slides

@Test func deliberateSlideRightUpProducesPositiveDeltas() throws {
  let run = replay(try Fixtures.load("deliberate-slide-right-up"), zones: rightEdge)
  let slides = run.slideEvents
  #expect(slides.first?.phase == .began)
  #expect(slides.last?.phase == .ended)
  #expect(run.changed.count >= 10)
  #expect(run.changed.allSatisfy { $0.delta > 0 })
  let total = run.changed.reduce(0) { $0 + $1.delta }
  #expect(abs(total - 30 / Fixtures.height) < 0.02)
  #expect(slides.allSatisfy { $0.zone == .edge(.right) && $0.fingers == 1 })
  #expect(run.events.count == slides.count)
  #expect(run.rejections.isEmpty)
  // Dwell claim: began once the 120 ms dwell elapsed, before the finger moved.
  let began = try #require(slides.first)
  #expect(run.relative(began) >= 0.12 && run.relative(began) < 0.15)
  expectClaimsFollowSlide(run)
}

@Test func deliberateSlideLeftDownProducesNegativeDeltas() {
  let frames = TraceBuilder([Stroke(id: 1, [(0, 3, 70), (1.0, 3, 30)])]).frames()
  let run = replay(frames, zones: [.edge(.left)])
  #expect(run.slideEvents.first?.phase == .began)
  #expect(run.slideEvents.last?.phase == .ended)
  #expect(run.changed.count >= 10)
  #expect(run.changed.allSatisfy { $0.delta < 0 })
  let total = run.changed.reduce(0) { $0 + $1.delta }
  #expect(abs(total + 40 / Fixtures.height) < 0.02)
  #expect(run.events.allSatisfy { $0.zone == .edge(.left) })
  #expect(run.rejections.isEmpty)
  // Along-axis claim: began well before the dwell would have, as soon as motion was clearly vertical.
  let began = run.slideEvents.first.map(run.relative) ?? 1
  #expect(began < 0.1)
  expectClaimsFollowSlide(run)
}

@Test func slideAtRestDoesNotJitter() {
  var stroke = Stroke(id: 1, [(0, 146, 40), (0.45, 146, 40), (0.85, 146, 60), (1.6, 146, 60)])
  stroke.jitterMM = 0.25
  let run = replay(TraceBuilder([stroke]).frames(), zones: rightEdge)
  #expect(run.events.map(\.kind).allSatisfy { $0 == .slide })
  #expect(run.slideEvents.first?.phase == .began)
  #expect(run.slideEvents.last?.phase == .ended)
  // Resting after the dwell claim: tremor never crosses the dead band.
  #expect(run.changed.filter { run.relative($0) < 0.45 }.isEmpty)
  // Moving: output flows.
  #expect(run.changed.filter { run.relative($0) > 0.45 && run.relative($0) <= 0.85 }.count >= 10)
  // Resting again: silent once rest is detected (100 ms), for the remaining ~600 ms of tremor.
  #expect(run.changed.filter { run.relative($0) > 1.0 }.isEmpty)
  let total = run.changed.reduce(0) { $0 + $1.delta }
  #expect(abs(total - 20 / Fixtures.height) < 0.02)
  #expect(run.rejections.isEmpty)
  expectClaimsFollowSlide(run)
}

// MARK: - Misfire defense

@Test func palmRestOnRightEdgeIsRejected() throws {
  let run = replay(try Fixtures.load("palm-rest-right"), zones: rightEdge)
  #expect(run.events.isEmpty)
  #expect(run.rejections == [Rejection(id: 1, reason: .palm)])
  #expect(run.neverClaimed)
}

@Test func twoFingerScrollNearEdgeIsRejected() throws {
  let run = replay(try Fixtures.load("two-finger-scroll-right"), zones: rightEdge)
  #expect(run.events.isEmpty)
  #expect(run.rejections == [Rejection(id: 1, reason: .tooManyContacts)])
  #expect(run.neverClaimed)
}

@Test func inwardSwipeFromRightEdgeHandsOffToSystem() throws {
  let run = replay(try Fixtures.load("inward-swipe-right"), zones: rightEdge)
  #expect(run.events.isEmpty)
  #expect(run.rejections == [Rejection(id: 1, reason: .systemGestureHandoff)])
  #expect(run.neverClaimed)
}

@Test func touchDriftingIntoZoneIsRejected() {
  let frames = TraceBuilder([Stroke(id: 1, [(0, 125, 40), (0.3, 147, 40), (0.7, 147, 70)])]).frames()
  let run = replay(frames, zones: rightEdge)
  #expect(run.events.isEmpty)
  #expect(run.rejections == [Rejection(id: 1, reason: .startedOutsideZone)])
  #expect(run.neverClaimed)
}

@Test func touchWhileTypingIsRejected() {
  let frames = TraceBuilder([Stroke(id: 1, [(0, 146, 50), (0.4, 146, 50)])]).frames()
  let typing = replay(frames, zones: rightEdge, secondsSinceLastKeyPress: 0.2)
  #expect(typing.events.isEmpty)
  #expect(typing.rejections == [Rejection(id: 1, reason: .typing)])
  #expect(typing.neverClaimed)
  // Control: the same touch well after the last key press claims a slide.
  let idle = replay(frames, zones: rightEdge, secondsSinceLastKeyPress: 2.0)
  #expect(idle.events.map(\.phase) == [.began, .ended])
  #expect(idle.rejections.isEmpty)
}

@Test func unmappedZoneNeverClaims() {
  let frames = TraceBuilder([
    Stroke(id: 1, [(0, 3, 30), (0.2, 3, 30), (1.0, 3, 70)]),
    Stroke(id: 2, [(1.3, 4, 91), (2.0, 4, 91)]),
  ]).frames()
  let run = replay(frames, zones: rightEdge)
  #expect(run.events.isEmpty)
  #expect(run.rejections == [Rejection(id: 1, reason: .disabledZone), Rejection(id: 2, reason: .disabledZone)])
  #expect(run.neverClaimed)
}

// MARK: - Corners, taps, swipes, segments

@Test func doubleTapTopRightCornerFires() throws {
  let run = replay(try Fixtures.load("double-tap-top-right"), zones: [.corner(.topRight)])
  #expect(run.events.map(\.kind) == [.tap, .doubleTap])
  #expect(run.events.allSatisfy { $0.zone == .corner(.topRight) && $0.phase == .ended && $0.delta == 0 })
  #expect(run.rejections.isEmpty)
  #expect(run.neverClaimed)
}

@Test func singleTapDoesNotFireDoubleTap() {
  let zones: Set<Zone> = [.corner(.topRight)]
  let single = replay(TraceBuilder([Stroke(id: 1, [(0, 146, 90), (0.08, 146, 90)])]).frames(), zones: zones)
  #expect(single.events.map(\.kind) == [.tap])
  // Two taps farther apart than the 300 ms window stay two single taps.
  let apart = replay(
    TraceBuilder([
      Stroke(id: 1, [(0, 146, 90), (0.08, 146, 90)]),
      Stroke(id: 2, [(0.6, 146, 90), (0.68, 146, 90)]),
    ]).frames(), zones: zones)
  #expect(apart.events.map(\.kind) == [.tap, .tap])
  #expect(single.rejections.isEmpty && apart.rejections.isEmpty)
}

@Test func longPressTopLeftCornerFires() throws {
  var stroke = Stroke(id: 1, [(0, 4, 91), (0.8, 4, 91)])
  stroke.jitterMM = 0.2
  let builder = TraceBuilder([stroke])
  let run = replay(builder.frames(), zones: [.corner(.topLeft)])
  #expect(run.events.map(\.kind) == [.longPress])
  let press = try #require(run.events.first)
  #expect(press.zone == .corner(.topLeft))
  #expect(run.relative(press) >= 0.5 && run.relative(press) < 0.52)
  #expect(run.rejections.isEmpty)
  // Claimed from the long-press frame until the finger lifts, and not before.
  let pressFrame = try #require(run.outputs.firstIndex { !$0.events.isEmpty })
  let lastDownFrame = builder.frameIndex(0.8)
  for (index, output) in run.outputs.enumerated() {
    let shouldClaim = index >= pressFrame && index <= lastDownFrame
    #expect(output.claimedContactIDs == (shouldClaim ? [1] : []), "frame \(index)")
  }
}

@Test func bottomEdgeSwipeLeftAndRight() {
  let frames = TraceBuilder([
    Stroke(id: 1, [(0, 60, 3), (0.08, 90, 3)]),
    Stroke(id: 2, [(0.5, 90, 3), (0.58, 60, 3)]),
  ]).frames()
  let run = replay(frames, zones: [.edge(.bottom)])
  #expect(run.events.map(\.kind) == [.swipe(.right), .swipe(.left)])
  #expect(run.events.allSatisfy { $0.zone == .edge(.bottom) && $0.phase == .ended })
  #expect(run.slideEvents.isEmpty)
  #expect(run.rejections.isEmpty)
  #expect(run.everClaimed && run.endsUnclaimed)
}

// Seen on hardware: an unhurried swipe along the bottom (~75 mm/s, under the flick speed) was
// claimed as a slide on a zone that binds no slide, so nothing fired and the pointer froze.
@Test func slowSwipeOnSwipeOnlyZoneFires() {
  let frames = TraceBuilder([
    Stroke(id: 1, [(0, 50, 3), (0.4, 80, 3)]),
    Stroke(id: 2, [(1.0, 80, 3), (1.4, 50, 3)]),
  ]).frames()
  let run = replay(frames, zones: [.edge(.bottom)], slideZones: [])
  #expect(run.events.map(\.kind) == [.swipe(.right), .swipe(.left)])
  #expect(run.slideEvents.isEmpty)
  #expect(run.everClaimed && run.endsUnclaimed)
}

@Test func slowAlongMotionIsStillASlideWhereSlideIsBound() {
  let frames = TraceBuilder([Stroke(id: 1, [(0, 50, 3), (0.4, 80, 3)])]).frames()
  let run = replay(frames, zones: [.edge(.bottom)], slideZones: [.edge(.bottom)])
  #expect(run.slideEvents.first?.phase == .began)
  #expect(!run.events.contains { if case .swipe = $0.kind { true } else { false } })
}

@Test func restingFingerOnSwipeOnlyZoneNeverClaims() {
  let frames = TraceBuilder([Stroke(id: 1, [(0, 60, 3), (0.6, 60, 3)])]).frames()
  let run = replay(frames, zones: [.edge(.bottom)], slideZones: [], longPressZones: [])
  #expect(run.events.isEmpty)
  #expect(run.neverClaimed)
}

@Test func longPressFiresOnlyWhereBound() {
  let frames = TraceBuilder([Stroke(id: 1, [(0, 60, 3), (0.7, 60, 3)])]).frames()
  let bound = replay(frames, zones: [.edge(.bottom)], slideZones: [], longPressZones: [.edge(.bottom)])
  #expect(bound.events.map(\.kind) == [.longPress])
}

@Test func segmentedEdgeRoutesToCorrectSegment() {
  let zones: Set<Zone> = Set((0..<3).map { Zone.edge(.right, segment: $0, segments: 3) })
  let frames = TraceBuilder([
    Stroke(id: 1, [(0, 146, 19), (0.08, 146, 19)]),
    Stroke(id: 2, [(0.5, 146, 47.5), (0.58, 146, 47.5)]),
    Stroke(id: 3, [(1.0, 146, 76), (1.08, 146, 76)]),
  ]).frames()
  let run = replay(frames, zones: zones)
  #expect(run.events.map(\.kind) == [.tap, .tap, .tap])
  #expect(
    run.events.map(\.zone) == [
      .edge(.right, segment: 0, segments: 3), .edge(.right, segment: 1, segments: 3),
      .edge(.right, segment: 2, segments: 3),
    ])
  // 47.5 mm is the middle of the middle segment.
  #expect(abs(run.events[1].position - 0.5) < 0.01)
  #expect(run.rejections.isEmpty)
}

@Test func cornerTakesPrecedenceOverEdge() {
  let frames = TraceBuilder([
    // Tap inside the bottom-right corner square, which also lies inside the right edge strip.
    Stroke(id: 1, [(0, 146, 5), (0.08, 146, 5)]),
    // A slide attempt that starts in the corner: corners never slide.
    Stroke(id: 2, [(0.5, 146, 6), (0.7, 146, 6), (1.5, 146, 40)]),
    // The same edge, outside the corner square, still taps as the edge.
    Stroke(id: 3, [(2.0, 146, 50), (2.08, 146, 50)]),
  ]).frames()
  let run = replay(frames, zones: [.edge(.right), .corner(.bottomRight)])
  #expect(run.events.map(\.kind) == [.tap, .tap])
  #expect(run.events.map(\.zone) == [.corner(.bottomRight), .edge(.right)])
  #expect(run.slideEvents.isEmpty)
  #expect(run.rejections == [Rejection(id: 2, reason: .offAxisMotion)])
  #expect(run.neverClaimed)
}

// Default config binds no bottom-right corner: its square must fall through to the right edge,
// otherwise the bottom 12 mm of the volume edge would be dead.
@Test func unmappedCornerFallsThroughToItsEdge() {
  let frames = TraceBuilder([
    Stroke(id: 1, [(0, 146, 5), (0.08, 146, 5)])
  ]).frames()
  let run = replay(frames, zones: [.edge(.right)])
  #expect(run.events.map(\.kind) == [.tap])
  #expect(run.events.map(\.zone) == [.edge(.right)])
  #expect(run.rejections.isEmpty)
}

// MARK: - Determinism

@Test func pipelineIsDeterministic() throws {
  let traces = [
    try Fixtures.load("deliberate-slide-right-up"), try Fixtures.load("double-tap-top-right"),
    try Fixtures.load("two-finger-scroll-right"),
  ]
  let zones: Set<Zone> = [.edge(.right), .corner(.topRight)]
  let reused = makeGestureRecognizer()
  for trace in traces {
    let first = replay(trace.frames, device: trace.device, zones: zones)
    let second = replay(trace.frames, device: trace.device, zones: zones)
    reused.reset()
    let afterReset = replay(trace.frames, device: trace.device, zones: zones, recognizer: reused)
    #expect(!first.events.isEmpty || !first.rejections.isEmpty, "\(trace.label) produced nothing")
    for other in [second, afterReset] {
      #expect(first.events == other.events, "\(trace.label)")
      #expect(first.rejections == other.rejections, "\(trace.label)")
      #expect(first.outputs.map(\.claimedContactIDs) == other.outputs.map(\.claimedContactIDs), "\(trace.label)")
    }
  }
}
