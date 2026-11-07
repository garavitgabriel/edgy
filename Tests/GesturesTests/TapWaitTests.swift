import EdgyCore
import Testing

@testable import Gestures

// A tap in a zone that also has a double-tap bound waits for the double-tap window (300 ms in
// `GestureSettings.test`), so the first tap of a double-tap never fires the tap action.

private let topRight = Zone.corner(.topRight)
private let topLeft = Zone.corner(.topLeft)
private let rightEdge = Zone.edge(.right)

/// `builder`'s frames, then empty frames from the same device until `until` seconds. A real device
/// stops sending after the lift; these stand in for the next frames it sends (e.g. the next touch).
private func framesIdling(_ builder: TraceBuilder, until: Double) -> [TouchFrame] {
  var frames = builder.frames()
  let next = frames.count
  for index in next...builder.frameIndex(until) {
    frames.append(
      TouchFrame(
        deviceID: builder.device.id, timestamp: builder.time(ofFrame: index), frameNumber: Int32(index), contacts: []))
  }
  return frames
}

/// Index of the frame whose output carries the first event of `kind`.
private func frameIndex(of kind: GestureKind, in run: Replay) -> Int? {
  run.outputs.firstIndex { $0.events.contains { $0.kind == kind } }
}

private let singleTap = TraceBuilder([Stroke(id: 1, [(0, 146, 90), (0.08, 146, 90)])])
/// Lift time of `singleTap`'s finger, seconds from the start: the frame that reports it lifting.
private let singleTapLift: Double = {
  let frames = singleTap.frames()
  let lift = frames.first { $0.contacts.contains { $0.state == .lifting } }!
  return lift.timestamp - frames[0].timestamp
}()

@Test func singleTapWaitsForTheDoubleTapWindow() {
  let run = replay(
    framesIdling(singleTap, until: 0.6), zones: [topRight], doubleTapZones: [topRight])
  #expect(run.events.map(\.kind) == [.tap])
  let index = try! #require(frameIndex(of: .tap, in: run))
  let emittedAt = run.frames[index].timestamp - run.frames[0].timestamp
  // Released on the first frame past lift + window, not before.
  #expect(emittedAt > singleTapLift + 0.3)
  #expect(emittedAt <= singleTapLift + 0.3 + 1 / 120.0 + 1e-9)
}

@Test func doubleTapInAWaitingZoneEmitsOnlyTheDoubleTap() {
  let builder = TraceBuilder([
    Stroke(id: 1, [(0, 146, 90), (0.08, 146, 90)]),
    Stroke(id: 2, [(0.2, 146.3, 89.8), (0.28, 146.3, 89.8)]),
  ])
  let run = replay(framesIdling(builder, until: 1.0), zones: [topRight], doubleTapZones: [topRight])
  #expect(run.events.map(\.kind) == [.doubleTap])
}

@Test func zoneWithoutADoubleTapFiresItsTapAtOnce() {
  // Another zone waits; this one doesn't, so its tap fires on the lift frame (no added latency).
  let run = replay(framesIdling(singleTap, until: 0.6), zones: [topRight, topLeft], doubleTapZones: [topLeft])
  #expect(run.events.map(\.kind) == [.tap])
  let index = try! #require(frameIndex(of: .tap, in: run))
  #expect(abs(run.frames[index].timestamp - run.frames[0].timestamp - singleTapLift) < 1e-9)
}

@Test func noDoubleTapZonesMeansNobodyWaits() {
  let run = replay(framesIdling(singleTap, until: 0.6), zones: [topRight], doubleTapZones: nil)
  let index = try! #require(frameIndex(of: .tap, in: run))
  #expect(abs(run.frames[index].timestamp - run.frames[0].timestamp - singleTapLift) < 1e-9)
}

@Test func delayedTapKeepsItsPositionAndLiftTime() {
  // The same tap on the right edge, immediate vs. delayed: the event is identical.
  let builder = TraceBuilder([Stroke(id: 1, [(0, 146, 37), (0.08, 146, 37)])])
  let immediate = replay(framesIdling(builder, until: 0.6), zones: [rightEdge])
  let delayed = replay(framesIdling(builder, until: 0.6), zones: [rightEdge], doubleTapZones: [rightEdge])
  #expect(immediate.events.count == 1)
  #expect(delayed.events == immediate.events)
  #expect(abs((delayed.events.first?.position ?? 0) - 37.0 / 95.0) < 1e-9)
}

@Test func resetDropsAPendingTap() {
  let recognizer = makeGestureRecognizer()
  let context = GestureContext(
    settings: .test, enabledZones: [topRight], secondsSinceLastKeyPress: nil, doubleTapZones: [topRight])
  let device = TraceBuilder.defaultDevice
  let frames = framesIdling(singleTap, until: 0.6)
  let lift = singleTap.frames().count
  var events: [GestureEvent] = []
  for frame in frames[..<lift] { events += recognizer.process(frame, device: device, context: context).events }
  recognizer.reset()
  for frame in frames[lift...] { events += recognizer.process(frame, device: device, context: context).events }
  #expect(events.isEmpty)
  let flusher = try! #require(recognizer as? DeferredGestureFlushing)
  #expect(flusher.nextFlushDeadline == nil)
  #expect(flusher.flush(now: frames.last!.timestamp + 1).events.isEmpty)
}

@Test func flushReleasesThePendingTapWhenNoMoreFramesCome() {
  // The device stops sending after the lift (one trailing empty frame). The owner wakes the
  // recognizer at `nextFlushDeadline`.
  let recognizer = makeGestureRecognizer()
  let flusher = try! #require(recognizer as? DeferredGestureFlushing)
  let context = GestureContext(
    settings: .test, enabledZones: [topRight], secondsSinceLastKeyPress: nil, doubleTapZones: [topRight])
  let frames = singleTap.frames()
  var events: [GestureEvent] = []
  for frame in frames {
    events += recognizer.process(frame, device: TraceBuilder.defaultDevice, context: context).events
    if frame.contacts.contains(where: { $0.state == .touching }) {
      #expect(flusher.nextFlushDeadline == nil, "nothing pending while the finger is down")
    }
  }
  #expect(events.isEmpty)
  let start = frames[0].timestamp
  let deadline = try! #require(flusher.nextFlushDeadline)
  #expect(abs(deadline - (start + singleTapLift + 0.3)) < 1e-9)
  #expect(flusher.flush(now: deadline - 0.05).events.isEmpty, "early flush releases nothing")
  let output = flusher.flush(now: deadline + 0.001)
  #expect(output.events.map(\.kind) == [.tap])
  #expect(output.claimedContactIDs.isEmpty)
  #expect(abs((output.events.first?.timestamp ?? 0) - (start + singleTapLift)) < 1e-9, "keeps its lift time")
  #expect(flusher.nextFlushDeadline == nil)
  #expect(flusher.flush(now: deadline + 1).events.isEmpty, "released once")
}

@Test func secondTouchStillDownPastTheWindowKeepsTheTapWaiting() {
  // The second tap lands inside the window (at 0.25 s, window ends at ~0.39 s) and lifts at
  // 0.45 s: it is still a possible tap when the window ends, so the first tap keeps waiting and the
  // pair becomes one double-tap.
  let builder = TraceBuilder([
    Stroke(id: 1, [(0, 146, 90), (0.08, 146, 90)]),
    Stroke(id: 2, [(0.25, 146, 90), (0.45, 146, 90)]),
  ])
  let run = replay(framesIdling(builder, until: 1.0), zones: [topRight], doubleTapZones: [topRight])
  #expect(run.events.map(\.kind) == [.doubleTap])
}

@Test func tapThenHoldReleasesTheTapBeforeTheHold() {
  // A tap, then a hold in the same corner landing inside the window: the tap was real, and fires
  // ahead of the hold.
  let builder = TraceBuilder([
    Stroke(id: 1, [(0, 146, 90), (0.08, 146, 90)]),
    Stroke(id: 2, [(0.2, 146, 90), (0.9, 146, 90)]),
  ])
  let run = replay(
    framesIdling(builder, until: 1.2), zones: [topRight], longPressZones: [topRight], doubleTapZones: [topRight])
  #expect(run.events.map(\.kind) == [.tap, .longPress, .longPress])
  #expect(holdPhases(run) == [.began, .ended])
  // Released once the second touch outlasts a tap (0.45 s), before the hold begins (0.7 s).
  let tapAt = run.frames[try! #require(frameIndex(of: .tap, in: run))].timestamp - run.frames[0].timestamp
  #expect(abs(tapAt - 0.45) < 0.01)
  expectHoldsArePaired(run)
}

@Test func tapsInDifferentZonesWaitIndependently() {
  // A tap in each waiting corner, 50 ms apart: neither pairs with the other; both release.
  let builder = TraceBuilder([
    Stroke(id: 1, [(0, 146, 90), (0.08, 146, 90)]),
    Stroke(id: 2, [(0.15, 4, 90), (0.22, 4, 90)]),
  ])
  let run = replay(
    framesIdling(builder, until: 1.0), zones: [topRight, topLeft], doubleTapZones: [topRight, topLeft])
  #expect(run.events.map(\.kind) == [.tap, .tap])
  #expect(run.events.map(\.zone) == [topRight, topLeft])
}

@Test func tapThenSwipeInsideTheWindowReleasesTheTapFirst() {
  // A tap on the right edge, then a flick up the same edge that ends before the window does: the
  // swipe settles the zone, so the tap fires at once, ahead of the swipe in the same frame.
  let builder = TraceBuilder([
    Stroke(id: 1, [(0, 146, 30), (0.08, 146, 30)]),
    Stroke(id: 2, [(0.15, 146, 30), (0.22, 146, 55)]),
  ])
  let run = replay(
    framesIdling(builder, until: 1.0), zones: [rightEdge], slideZones: [], doubleTapZones: [rightEdge])
  #expect(run.events.map(\.kind) == [.tap, .swipe(.up)])
  #expect(frameIndex(of: .tap, in: run) == frameIndex(of: .swipe(.up), in: run))
}
