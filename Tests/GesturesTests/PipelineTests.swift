import EdgyCore
import Foundation
import Testing

@testable import Gestures

private let rightEdge: Set<Zone> = [.edge(.right)]

@Test func factoryReturnsRealPipeline() {
  let recognizer = makeGestureRecognizer()
  #expect(!(recognizer is NoopGestureRecognizer))
  let run = replay(
    TraceBuilder([Stroke(id: 1, [(0, 146, 90), (0.08, 146, 90)])]).frames(), zones: [.corner(.topRight)],
    recognizer: recognizer)
  #expect(run.events.map(\.kind) == [.tap])
}

/// Keeps the committed JSON fixtures identical to what `TraceBuilder` produces.
/// Set `EDGY_REGENERATE_FIXTURES=1` to rewrite them first.
@Test func fixturesMatchTraceBuilder() throws {
  let regenerate = ProcessInfo.processInfo.environment["EDGY_REGENERATE_FIXTURES"] == "1"
  for trace in Fixtures.all() {
    let sourceURL = Fixtures.sourceDirectory.appendingPathComponent("\(trace.label).json")
    if regenerate { try trace.write(to: sourceURL) }
    #expect(try TraceFile.load(from: sourceURL) == trace, "\(trace.label) is stale; regenerate it")
    if !regenerate {
      #expect(try Fixtures.load(trace.label) == trace, "\(trace.label) bundle copy differs")
    }
  }
}

@Test func edgeTapLongerThanDwellIsATapNotASlide() {
  let run = replay(TraceBuilder([Stroke(id: 1, [(0, 146, 50), (0.18, 146, 50)])]).frames(), zones: rightEdge)
  // The dwell claims a slide at 120 ms; lifting before it ever moved turns it back into a tap.
  #expect(run.events.map(\.kind) == [.slide, .slide, .tap])
  #expect(run.slideEvents.map(\.phase) == [.began, .cancelled])
  #expect(run.changed.isEmpty)
  expectClaimsFollowSlide(run)
}

@Test func twoFingerSlideWhenConfigured() {
  var settings = GestureSettings.defaults
  settings.fingers = 2
  let frames = TraceBuilder([
    Stroke(id: 1, [(0, 145, 30), (0.03, 145, 30), (0.6, 145, 50)]),
    Stroke(id: 2, [(0.01, 147, 40), (0.03, 147, 40), (0.6, 147, 60)]),
  ]).frames()
  let run = replay(frames, zones: rightEdge, settings: settings)
  #expect(run.slideEvents.first?.phase == .began)
  #expect(run.slideEvents.last?.phase == .ended)
  #expect(run.slideEvents.allSatisfy { $0.fingers == 2 })
  #expect(run.changed.allSatisfy { $0.delta > 0 })
  #expect(abs(run.changed.reduce(0) { $0 + $1.delta } - 20 / Fixtures.height) < 0.02)
  #expect(run.rejections.isEmpty)
  #expect(run.outputs.contains { $0.claimedContactIDs == [1, 2] })
  expectClaimsFollowSlide(run)
  // The same two fingers with the default one-finger setting are a multi-finger touch: rejected.
  let oneFinger = replay(frames, zones: rightEdge)
  #expect(oneFinger.events.isEmpty)
  #expect(Set(oneFinger.rejections.map(\.reason)) == [.tooManyContacts])
}

@Test func fingerLandingWithClaimedSlideCancelsIt() {
  let frames = TraceBuilder([
    Stroke(id: 1, [(0, 146, 30), (0.5, 146, 50)]),
    Stroke(id: 2, [(0.09, 120, 40), (0.5, 120, 60)]),
  ]).frames()
  let run = replay(frames, zones: rightEdge)
  #expect(run.slideEvents.first?.phase == .began)
  #expect(run.slideEvents.last?.phase == .cancelled)
  #expect(!run.slideEvents.contains { $0.phase == .ended })
  #expect(run.rejections == [Rejection(id: 1, reason: .tooManyContacts)])
  expectClaimsFollowSlide(run)
}

@Test func lateRestingFingerDoesNotCancelClaimedSlide() {
  let frames = TraceBuilder([
    Stroke(id: 1, [(0, 146, 30), (0.8, 146, 60)]),
    Stroke(id: 2, [(0.3, 70, 10), (0.9, 70, 10)]),
  ]).frames()
  let run = replay(frames, zones: rightEdge)
  #expect(run.slideEvents.first?.phase == .began)
  #expect(run.slideEvents.last?.phase == .ended)
  #expect(!run.slideEvents.contains { $0.phase == .cancelled })
  #expect(run.rejections.isEmpty)
  expectClaimsFollowSlide(run)
}

@Test func shortFastFlickIsTooFast() {
  let frames = TraceBuilder([Stroke(id: 1, [(0, 60, 3), (0.02, 64, 3), (0.1, 64, 3)])]).frames()
  let run = replay(frames, zones: [.edge(.bottom)])
  #expect(run.events.isEmpty)
  #expect(run.rejections == [Rejection(id: 1, reason: .tooFast)])
  #expect(run.neverClaimed)
}

@Test func flickHeldTooLongIsTooFast() {
  let frames = TraceBuilder([Stroke(id: 1, [(0, 60, 3), (0.03, 70, 3), (0.6, 70, 3)])]).frames()
  let run = replay(frames, zones: [.edge(.bottom)])
  #expect(run.events.isEmpty)
  #expect(run.rejections == [Rejection(id: 1, reason: .tooFast)])
  #expect(run.neverClaimed)
}

@Test func diagonalMotionIsOffAxis() {
  let frames = TraceBuilder([Stroke(id: 1, [(0, 146, 40), (0.3, 141, 46)])]).frames()
  let run = replay(frames, zones: rightEdge)
  #expect(run.events.isEmpty)
  #expect(run.rejections == [Rejection(id: 1, reason: .offAxisMotion)])
  #expect(run.neverClaimed)
}

@Test func palmBySizeOutlierIsRejected() {
  var blob = Stroke(id: 1, [(0, 146, 50), (0.5, 146, 50)])
  blob.majorAxisMM = 12
  blob.minorAxisMM = 10
  blob.size = 3.0
  let run = replay(TraceBuilder([blob]).frames(), zones: rightEdge)
  #expect(run.events.isEmpty)
  #expect(run.rejections == [Rejection(id: 1, reason: .palm)])
  #expect(run.neverClaimed)
}

@Test func unmappedCornerDoesNotFallThroughToEdge() {
  let run = replay(TraceBuilder([Stroke(id: 1, [(0, 146, 5), (0.08, 146, 5)])]).frames(), zones: rightEdge)
  #expect(run.events.isEmpty)
  #expect(run.rejections == [Rejection(id: 1, reason: .disabledZone)])
}

@Test func resetClearsTapHistory() {
  let recognizer = makeGestureRecognizer()
  let zones: Set<Zone> = [.corner(.topRight)]
  let frames = TraceBuilder([
    Stroke(id: 1, [(0, 146, 90), (0.08, 146, 90)]),
    Stroke(id: 2, [(0.2, 146, 90), (0.28, 146, 90)]),
  ]).frames()
  let split = frames.firstIndex { $0.contacts.contains { $0.id == 2 } } ?? frames.count
  let first = replay(Array(frames[..<split]), zones: zones, recognizer: recognizer)
  recognizer.reset()
  let second = replay(Array(frames[split...]), zones: zones, recognizer: recognizer)
  #expect(first.events.map(\.kind) == [.tap])
  #expect(second.events.map(\.kind) == [.tap])
}

@Test func zoneGeometryClassifiesInMillimetres() {
  let geometry = ZoneGeometry(device: TraceBuilder.defaultDevice, settings: .defaults)
  #expect(geometry.region(at: Point2D(x: 75, y: 47)) == nil)
  #expect(geometry.region(at: Point2D(x: 143, y: 47)) == .edge(.right))
  #expect(geometry.region(at: Point2D(x: 141, y: 47)) == nil)
  #expect(geometry.region(at: Point2D(x: 75, y: 2)) == .edge(.bottom))
  #expect(geometry.region(at: Point2D(x: 75, y: 90)) == .edge(.top))
  #expect(geometry.region(at: Point2D(x: 5, y: 47)) == .edge(.left))
  #expect(geometry.region(at: Point2D(x: 140, y: 85)) == .corner(.topRight))
  #expect(geometry.region(at: Point2D(x: 2, y: 2)) == .corner(.bottomLeft))
  // The finest mapped segmentation wins.
  let zones: Set<Zone> = [.edge(.right), .edge(.right, segment: 1, segments: 2)]
  #expect(
    geometry.zone(for: .edge(.right), at: Point2D(x: 146, y: 70), enabled: zones)
      == .edge(.right, segment: 1, segments: 2))
  #expect(geometry.zone(for: .edge(.right), at: Point2D(x: 146, y: 20), enabled: zones) == .edge(.right))
}
