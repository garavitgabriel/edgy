import EdgyCore
import Testing

@testable import Gestures

// `GestureOutput.tapLifts` (batch 35): the zones where a contact lifted this step as an accepted
// tap, so the runtime can expect the system's tap-to-click click. Reported on the lift step for a
// tap that fires at once, a tap held for the double-tap window and the second tap of a double-tap;
// never for a rejected lift or from a flush. Built-in trackpad, 150 × 95 mm, `GestureSettings.test`.

private let topRight = Zone.corner(.topRight)
private let topLeft = Zone.corner(.topLeft)
private let rightEdge = Zone.edge(.right)

private let singleTap = TraceBuilder([Stroke(id: 1, [(0, 146, 90), (0.08, 146, 90)])])

/// `builder`'s frames, then empty frames until `until` seconds (the device's next frames).
private func framesIdling(_ builder: TraceBuilder, until: Double) -> [TouchFrame] {
  var frames = builder.frames()
  for index in frames.count...builder.frameIndex(until) {
    frames.append(
      TouchFrame(
        deviceID: builder.device.id, timestamp: builder.time(ofFrame: index), frameNumber: Int32(index), contacts: []))
  }
  return frames
}

/// Index of the first frame where a contact is lifting.
private func liftFrame(_ run: Replay) -> Int? {
  run.frames.firstIndex { $0.contacts.contains { $0.state == .lifting } }
}

/// Every (frame index, zones) pair with a non-empty `tapLifts`.
private func lifts(_ run: Replay) -> [(Int, [Zone])] {
  run.outputs.enumerated().filter { !$0.element.tapLifts.isEmpty }.map { ($0.offset, $0.element.tapLifts) }
}

@Test func tapThatFiresAtOnceReportsItsLiftOnTheSameStep() {
  let run = replay(framesIdling(singleTap, until: 0.6), zones: [topRight])
  let lift = try! #require(liftFrame(run))
  #expect(lifts(run).map(\.0) == [lift])
  #expect(lifts(run).map(\.1) == [[topRight]])
  #expect(run.outputs[lift].events.map(\.kind) == [.tap])
}

@Test func heldTapReportsItsLiftAtTheLiftNotWhenItIsReleased() {
  let run = replay(framesIdling(singleTap, until: 0.6), zones: [topRight], doubleTapZones: [topRight])
  let lift = try! #require(liftFrame(run))
  #expect(lifts(run).map(\.0) == [lift])
  #expect(run.outputs[lift].events.isEmpty, "the tap itself is held back")
  let released = try! #require(run.outputs.firstIndex { $0.events.contains { $0.kind == .tap } })
  #expect(released > lift)
  #expect(run.outputs[released].tapLifts.isEmpty, "a released held tap is not a new lift")
}

@Test func doubleTapReportsBothLifts() {
  let builder = TraceBuilder([
    Stroke(id: 1, [(0, 146, 90), (0.08, 146, 90)]),
    Stroke(id: 2, [(0.2, 146.3, 89.8), (0.28, 146.3, 89.8)]),
  ])
  for waiting in [Set([topRight]), nil] {
    let run = replay(framesIdling(builder, until: 1.0), zones: [topRight], doubleTapZones: waiting)
    #expect(lifts(run).map(\.1) == [[topRight], [topRight]])
    let second = try! #require(lifts(run).last?.0)
    #expect(run.outputs[second].events.map(\.kind) == [.doubleTap])
  }
}

@Test func flushNeverReportsALift() {
  let pipeline = GesturePipeline()
  let context = GestureContext(
    settings: .test, enabledZones: [topRight], secondsSinceLastKeyPress: nil, doubleTapZones: [topRight])
  let outputs = singleTap.frames().map { pipeline.process($0, device: TraceBuilder.defaultDevice, context: context) }
  #expect(outputs.flatMap(\.tapLifts) == [topRight])
  let flushed = pipeline.flush(now: singleTap.time(ofFrame: 200))
  #expect(flushed.events.map(\.kind) == [.tap])
  #expect(flushed.tapLifts.isEmpty)
}

@Test func tapToClickButtonAtTheLiftStillReportsTheLift() {
  // The system reports the tap as a click after the lift: the button reads down from the lift frame.
  var builder = singleTap
  let liftTime = Double(builder.frameIndex(0.08) + 1) / builder.hz
  builder.buttonDown = [liftTime...(liftTime + 0.05)]
  let run = replay(framesIdling(builder, until: 0.6), zones: [topRight])
  #expect(lifts(run).map(\.1) == [[topRight]])
  #expect(run.events.map(\.kind) == [.tap])
}

// MARK: - Rejected lifts never report one

@Test func palmLiftReportsNoTap() {
  var palm = Stroke(id: 1, [(0, 146, 90), (0.08, 146, 90)])
  palm.majorAxisMM = 26
  let run = replay(framesIdling(TraceBuilder([palm]), until: 0.6), zones: [topRight])
  #expect(run.rejections.map(\.reason) == [.palm])
  #expect(lifts(run).isEmpty)
}

@Test func typingLiftReportsNoTap() {
  let run = replay(framesIdling(singleTap, until: 0.6), zones: [topRight], secondsSinceLastKeyPress: 0.1)
  #expect(run.rejections.map(\.reason) == [.typing])
  #expect(lifts(run).isEmpty)
}

@Test func movedLiftReportsNoTap() {
  let moved = TraceBuilder([Stroke(id: 1, [(0, 146, 90), (0.15, 141, 90)])])
  let run = replay(framesIdling(moved, until: 0.6), zones: [topRight])
  #expect(run.rejections.map(\.reason) == [.offAxisMotion])
  #expect(lifts(run).isEmpty)
}

@Test func physicallyClickedLiftReportsNoTap() {
  var builder = singleTap
  builder.buttonDown = [0.03...0.06]
  let run = replay(framesIdling(builder, until: 0.6), zones: [topRight])
  #expect(run.rejections.map(\.reason) == [.physicalClick])
  #expect(lifts(run).isEmpty)
}

@Test func liftInAnUnmappedZoneReportsNoTap() {
  let run = replay(framesIdling(singleTap, until: 0.6), zones: [topLeft])
  #expect(run.rejections.map(\.reason) == [.disabledZone])
  #expect(lifts(run).isEmpty)
}

@Test func liftThatIsNotATapReportsNone() {
  // Too long to be a tap (no long-press bound) and a swipe: neither is a tap lift.
  let long = TraceBuilder([Stroke(id: 1, [(0, 146, 90), (0.4, 146, 90)])])
  let longRun = replay(framesIdling(long, until: 0.8), zones: [topRight], longPressZones: [])
  #expect(longRun.events.isEmpty)
  #expect(lifts(longRun).isEmpty)
  let swipe = TraceBuilder([Stroke(id: 1, [(0, 146, 30), (0.08, 146, 50)])])
  let swipeRun = replay(framesIdling(swipe, until: 0.6), zones: [rightEdge])
  #expect(swipeRun.events.map(\.kind) == [.swipe(.up)])
  #expect(lifts(swipeRun).isEmpty)
}
