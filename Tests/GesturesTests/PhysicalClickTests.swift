import EdgyCore
import Testing

@testable import Gestures

// A touch that clicks (`TouchFrame.buttonDown`) is the user pressing, dragging or selecting: it is
// never an edge gesture. Built-in trackpad, 150 × 95 mm, `GestureSettings.test` (edges 8 mm,
// corners 12 mm).

private let topRight = Zone.corner(.topRight)
private let topLeft = Zone.corner(.topLeft)
private let rightEdge = Zone.edge(.right)

private func run(
  _ strokes: [Stroke], buttons: [ClosedRange<Double>], zones: Set<Zone>, slideZones: Set<Zone>? = nil,
  longPressZones: Set<Zone>? = nil
) -> Replay {
  var builder = TraceBuilder(strokes)
  builder.buttonDown = buttons
  return replay(builder.frames(), zones: zones, slideZones: slideZones, longPressZones: longPressZones)
}

@Test func clickWithoutDragInACornerIsNotATap() {
  // Press the top-right corner until it clicks, release, lift: as short and still as a tap.
  let run = run([Stroke(id: 1, [(0, 146, 90), (0.15, 146, 90)])], buttons: [0.04...0.1], zones: [topRight])
  #expect(run.events.isEmpty)
  #expect(run.neverClaimed)
  #expect(run.reasons(1) == [.physicalClick])
}

@Test func clickMidSlideCancelsTheSlide() {
  // A deliberate slide up the right edge; 0.4 s in, the finger presses down and clicks.
  let run = run(
    [Stroke(id: 1, [(0, 146, 30), (0.15, 146, 30), (0.75, 146, 60)])], buttons: [0.4...0.75], zones: [rightEdge])
  let phases = run.slideEvents.map(\.phase)
  #expect(phases.first == .began)
  #expect(phases.last == .cancelled)
  #expect(phases.filter { $0 == .cancelled }.count == 1)
  #expect(!run.changed.isEmpty, "it slid before the click")
  let cancel = try! #require(run.slideEvents.last)
  #expect(abs(run.relative(cancel) - 0.4) < 0.01, "cancelled on the first clicked frame")
  #expect(run.events.allSatisfy { run.relative($0) <= 0.401 }, "nothing after the click")
  #expect(run.reasons(1) == [.physicalClick])
  #expect(run.endsUnclaimed)
  expectClaimsFollowSlide(run)
}

@Test func clickAfterALongPressBeganEndsTheHold() {
  // A push-to-talk hold in the top-left corner; at 0.7 s the finger presses through to a click.
  let run = run(
    [Stroke(id: 1, [(0, 4, 90), (1.0, 4, 90)])], buttons: [0.7...1.0], zones: [topLeft], longPressZones: [topLeft])
  #expect(holdPhases(run) == [.began, .cancelled])
  let cancel = try! #require(run.events.last)
  #expect(abs(run.relative(cancel) - 0.7) < 0.01)
  #expect(run.reasons(1) == [.physicalClick])
  #expect(run.endsUnclaimed)
  expectHoldsArePaired(run)
}

@Test func forceClickWhileStillIsNotALongPress() {
  // A force-click style press: the finger never moves, the button goes down at 300 ms (before the
  // 500 ms hold time) and stays down. A hold would otherwise fire at 500 ms.
  let run = run(
    [Stroke(id: 1, [(0, 4, 90), (1.0, 4, 90)])], buttons: [0.3...1.0], zones: [topLeft], longPressZones: [topLeft])
  #expect(holdPhases(run).isEmpty)
  #expect(run.events.isEmpty)
  #expect(run.neverClaimed)
  #expect(run.reasons(1) == [.physicalClick])
}

@Test func clickedEdgeTapNeverFires() {
  // A short, still press on the right edge that clicks: no tap.
  let run = run([Stroke(id: 1, [(0, 146, 50), (0.1, 146, 50)])], buttons: [0.03...0.08], zones: [rightEdge])
  #expect(run.events.isEmpty)
  #expect(run.reasons(1) == [.physicalClick])
}

@Test func clickedFlickAlongAnEdgeIsNotASwipe() {
  // A fast flick up the right edge with the button held: a click-drag, not a swipe.
  let run = run(
    [Stroke(id: 1, [(0, 146, 30), (0.1, 146, 60)])], buttons: [0.0...0.1], zones: [rightEdge], slideZones: [])
  #expect(run.events.isEmpty)
  #expect(run.neverClaimed)
  #expect(run.reasons(1) == [.physicalClick])
}

@Test func clickedTapDoesNotPairWithTheNextTap() {
  // A click in the corner, then two clean taps: the click is not the first tap of a double-tap.
  let run = run(
    [
      Stroke(id: 1, [(0, 146, 90), (0.08, 146, 90)]),
      Stroke(id: 2, [(0.2, 146, 90), (0.26, 146, 90)]),
      Stroke(id: 3, [(0.4, 146, 90), (0.46, 146, 90)]),
    ], buttons: [0.02...0.06], zones: [topRight])
  #expect(run.events.map(\.kind) == [.tap, .doubleTap])
  #expect(run.reasons(1) == [.physicalClick])
}

@Test func fingerLandingOnAnEdgeWhileTheButtonIsHeldIsNotOurs() {
  // The index finger holds a click mid-pad (a drag in progress); the thumb lands on the right edge
  // and rests. Its rejection is the click, decided before the contact count is.
  let run = run(
    [
      Stroke(id: 1, [(0, 70, 40), (1.0, 90, 40)]),
      Stroke(id: 2, [(0.3, 146, 50), (0.9, 146, 50)]),
    ], buttons: [0.05...1.0], zones: [rightEdge])
  #expect(run.events.isEmpty)
  #expect(run.neverClaimed)
  #expect(run.reasons(2) == [.physicalClick])
}

@Test func releasingTheButtonDoesNotReviveTheTouch() {
  // Click and release early, then keep the finger resting on the edge well past the dwell and the
  // hold time: the touch stays not-ours until it lifts.
  let run = run(
    [Stroke(id: 1, [(0, 146, 50), (0.9, 146, 50)])], buttons: [0.02...0.06], zones: [rightEdge],
    longPressZones: [rightEdge])
  #expect(run.events.isEmpty)
  #expect(run.neverClaimed)
  #expect(run.reasons(1) == [.physicalClick])
}

@Test func buttonGoingDownAsTheFingerLiftsKeepsTheTap() {
  // Tap-to-click reports its click after the lift. A button seen first on the lift frame doesn't
  // undo a tap that never pressed.
  var builder = TraceBuilder([Stroke(id: 1, [(0, 146, 90), (0.08, 146, 90)])])
  let frames = builder.frames()
  let liftIndex = try! #require(frames.firstIndex { $0.contacts.contains { $0.state == .lifting } })
  builder.buttonDown = [(Double(liftIndex) / builder.hz)...(Double(liftIndex + 1) / builder.hz)]
  let run = replay(builder.frames(), zones: [topRight])
  #expect(run.events.map(\.kind) == [.tap])
}
