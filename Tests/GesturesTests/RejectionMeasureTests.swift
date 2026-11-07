import EdgyCore
import Testing

@testable import Gestures

// The number behind each rejection (`GestureOutput.rejectionMeasures`), for Test Mode's plate:
// "Ignored: palm, 21 mm wide, limit 18 mm". Pad 150 × 95 mm, edges 8 mm, corners 12 mm.

private let rightEdge = Zone.edge(.right)
private let leftEdge = Zone.edge(.left)

extension Replay {
  /// Every measure the replay reported, by contact.
  var measures: [Int32: RejectionMeasure] {
    outputs.reduce(into: [:]) { all, output in all.merge(output.rejectionMeasures) { _, new in new } }
  }

  /// Measures are only ever reported for a contact rejected in the same output.
  var measuresMatchRejections: Bool {
    outputs.allSatisfy { output in
      Set(output.rejectionMeasures.keys).isSubset(of: Set(output.rejections.map(\.contactID)))
    }
  }
}

private func expectMeasure(
  _ run: Replay, _ id: Int32, _ unit: RejectionMeasure.Unit, limit: Double, measured: ClosedRange<Double>,
  sourceLocation: SourceLocation = #_sourceLocation
) {
  guard let measure = run.measures[id] else {
    Issue.record("no measure for contact \(id)", sourceLocation: sourceLocation)
    return
  }
  #expect(measure.unit == unit, sourceLocation: sourceLocation)
  #expect(abs(measure.limit - limit) < 1e-9, "limit \(measure.limit)", sourceLocation: sourceLocation)
  #expect(measured.contains(measure.measured), "measured \(measure.measured)", sourceLocation: sourceLocation)
  #expect(run.measuresMatchRejections, sourceLocation: sourceLocation)
}

// MARK: - Palm

@Test func palmMeasuresItsMajorAxisAgainstTheSetting() throws {
  let run = replay(try Fixtures.load("palm-rest-right"), zones: [rightEdge])
  #expect(run.rejections == [Rejection(id: 1, reason: .palm)])
  // It spreads from 10 to 24 mm; rejected on the first frame past 18 mm.
  expectMeasure(run, 1, .mm, limit: 18, measured: 18.000_1...24)
}

@Test func palmMeasureFollowsTheUsersPalmSetting() {
  var palm = Stroke(id: 1, [(0, 146, 50), (0.3, 146, 50)])
  palm.majorAxisMM = 23
  var settings = GestureSettings.test
  settings.palmMajorAxisMM = 22
  let run = replay(TraceBuilder([palm]).frames(), zones: [rightEdge], settings: settings)
  #expect(run.rejections == [Rejection(id: 1, reason: .palm)])
  expectMeasure(run, 1, .mm, limit: 22, measured: 23...23)
}

@Test func roundBlobPalmMeasuresItsMinorAxis() {
  var blob = Stroke(id: 1, [(0, 146, 50), (0.3, 146, 50)])
  blob.majorAxisMM = 16
  blob.minorAxisMM = 15
  let run = replay(TraceBuilder([blob]).frames(), zones: [rightEdge])
  #expect(run.rejections == [Rejection(id: 1, reason: .palm)])
  expectMeasure(run, 1, .mm, limit: 14, measured: 15...15)
}

@Test func palmJudgedBySizeAloneHasNoMeasure() {
  var heavy = Stroke(id: 1, [(0, 146, 50), (0.3, 146, 50)])
  heavy.size = 3
  let run = replay(TraceBuilder([heavy]).frames(), zones: [rightEdge])
  #expect(run.rejections == [Rejection(id: 1, reason: .palm)])
  #expect(run.measures.isEmpty)
}

// MARK: - Typing

@Test func typingMeasuresTimeSinceTheLastKey() {
  let frames = TraceBuilder([Stroke(id: 1, [(0, 146, 50), (0.4, 146, 50)])]).frames()
  let run = replay(frames, zones: [rightEdge], secondsSinceLastKeyPress: 0.2)
  #expect(run.rejections == [Rejection(id: 1, reason: .typing)])
  expectMeasure(run, 1, .ms, limit: 500, measured: 199.999...200.001)
}

@Test func typingMeasureUsesTheSuppressionSetting() {
  var settings = GestureSettings.test
  settings.typingSuppressionMS = 1200
  let frames = TraceBuilder([Stroke(id: 1, [(0, 146, 50), (0.4, 146, 50)])]).frames()
  let run = replay(frames, zones: [rightEdge], settings: settings, secondsSinceLastKeyPress: 0.9)
  expectMeasure(run, 1, .ms, limit: 1200, measured: 899.999...900.001)
}

// MARK: - Too many contacts

@Test func twoFingerScrollMeasuresContactsAgainstTheFingerSetting() throws {
  let run = replay(try Fixtures.load("two-finger-scroll-right"), zones: [rightEdge])
  #expect(run.rejections == [Rejection(id: 1, reason: .tooManyContacts)])
  expectMeasure(run, 1, .fingers, limit: 1, measured: 2...2)
}

@Test func threeFingersOnATwoFingerSettingMeasureThree() {
  var settings = GestureSettings.test
  settings.fingers = 2
  let frames = TraceBuilder([
    Stroke(id: 1, [(0, 146, 40), (0.3, 146, 40)]),
    Stroke(id: 2, [(0.01, 146, 50), (0.3, 146, 50)]),
    Stroke(id: 3, [(0.02, 120, 60), (0.3, 120, 60)]),
  ]).frames()
  let run = replay(frames, zones: [rightEdge], settings: settings)
  #expect(Set(run.rejections.map(\.reason)) == [.tooManyContacts])
  expectMeasure(run, 1, .fingers, limit: 2, measured: 3...3)
}

// MARK: - Off-axis motion

@Test func cornerWanderMeasuresTravelAgainstTheCornerLimit() {
  let frames = TraceBuilder([Stroke(id: 1, [(0, 146, 6), (0.2, 146, 6), (1.0, 146, 40)])]).frames()
  let run = replay(frames, zones: [.corner(.bottomRight)])
  #expect(run.rejections == [Rejection(id: 1, reason: .offAxisMotion)])
  expectMeasure(run, 1, .mm, limit: 3, measured: 3.000_1...4)
}

@Test func diagonalMotionMeasuresTotalTravel() {
  // Equal parts along and inward, fast enough to beat the dwell: no axis wins.
  let frames = TraceBuilder([Stroke(id: 1, [(0, 146, 50), (0.1, 142, 54)])]).frames()
  let run = replay(frames, zones: [rightEdge])
  #expect(run.rejections == [Rejection(id: 1, reason: .offAxisMotion)])
  expectMeasure(run, 1, .mm, limit: 3, measured: 3...4.5)
}

@Test func outwardMotionMeasuresSidewaysTravel() {
  // Lands 7 mm in on the left edge and moves toward the physical edge.
  let frames = TraceBuilder([Stroke(id: 1, [(0, 7, 50), (0.06, 2, 50)])]).frames()
  let run = replay(frames, zones: [leftEdge])
  #expect(run.rejections == [Rejection(id: 1, reason: .offAxisMotion)])
  expectMeasure(run, 1, .mm, limit: 2.5, measured: 2.5...5)
}

@Test func swipeThatVeersAcrossMeasuresAcrossAgainstAlong() {
  // A fast flick along the edge (a swipe candidate), then mostly inward before lifting.
  let frames = TraceBuilder([Stroke(id: 1, [(0, 146, 30), (0.02, 146, 34), (0.06, 137, 35)])]).frames()
  let run = replay(frames, zones: [rightEdge])
  #expect(run.rejections == [Rejection(id: 1, reason: .offAxisMotion)])
  guard let measure = run.measures[1] else {
    Issue.record("no measure")
    return
  }
  #expect(measure.unit == .mm)
  #expect(measure.measured > measure.limit)
  #expect((6...9.01).contains(measure.measured))
  #expect((3...5.01).contains(measure.limit))
}

// MARK: - Too fast (a swipe candidate that didn't finish as a swipe)

@Test func swipeHeldTooLongMeasuresTimeAgainstTheSwipeLimit() {
  // Flicks 10 mm in 40 ms (a swipe candidate), then stays down past the 350 ms swipe limit.
  let frames = TraceBuilder([Stroke(id: 1, [(0, 146, 30), (0.04, 146, 40), (0.7, 146, 40)])]).frames()
  let run = replay(frames, zones: [rightEdge])
  #expect(run.rejections == [Rejection(id: 1, reason: .tooFast)])
  expectMeasure(run, 1, .ms, limit: 350, measured: 350.000_1...360)
}

@Test func swipeOnlyZoneMeasuresAgainstTheLongerLimit() {
  let frames = TraceBuilder([Stroke(id: 1, [(0, 146, 30), (0.04, 146, 40), (0.9, 146, 40)])]).frames()
  let run = replay(frames, zones: [rightEdge], slideZones: [])
  #expect(run.rejections == [Rejection(id: 1, reason: .tooFast)])
  expectMeasure(run, 1, .ms, limit: 600, measured: 600.000_1...610)
}

@Test func swipeTooShortMeasuresAlongTravelAgainstTheMinimum() {
  // A 4 mm flick at 200 mm/s: fast enough to be a swipe candidate, too short to be a swipe.
  let frames = TraceBuilder([Stroke(id: 1, [(0, 146, 30), (0.02, 146, 34)])]).frames()
  let run = replay(frames, zones: [rightEdge])
  #expect(run.rejections == [Rejection(id: 1, reason: .tooFast)])
  expectMeasure(run, 1, .mm, limit: 6, measured: 2...4.01)
}

// MARK: - Started outside a zone

@Test func driftIntoAnEdgeMeasuresHowFarInItLanded() {
  let frames = TraceBuilder([Stroke(id: 1, [(0, 125, 40), (0.3, 147, 40), (0.7, 147, 70)])]).frames()
  let run = replay(frames, zones: [rightEdge])
  #expect(run.rejections == [Rejection(id: 1, reason: .startedOutsideZone)])
  expectMeasure(run, 1, .mm, limit: 8, measured: 25...25)
}

@Test func driftIntoACornerMeasuresAgainstTheCornerSize() {
  // Lands 20 mm from the right and 30 mm from the bottom, drifts into the bottom-right square.
  let frames = TraceBuilder([Stroke(id: 1, [(0, 130, 30), (0.4, 146, 5)])]).frames()
  let run = replay(frames, zones: [.corner(.bottomRight)])
  #expect(run.rejections == [Rejection(id: 1, reason: .startedOutsideZone)])
  expectMeasure(run, 1, .mm, limit: 12, measured: 30...30)
}

// MARK: - No number means anything

@Test func systemGestureHandoffCarriesNoMeasure() throws {
  let run = replay(try Fixtures.load("inward-swipe-right"), zones: [rightEdge])
  #expect(run.rejections == [Rejection(id: 1, reason: .systemGestureHandoff)])
  #expect(run.measures.isEmpty)
}

@Test func physicalClickCarriesNoMeasure() {
  var builder = TraceBuilder([Stroke(id: 1, [(0, 146, 90), (0.15, 146, 90)])])
  builder.buttonDown = [0.04...0.1]
  let run = replay(builder.frames(), zones: [.corner(.topRight)])
  #expect(run.rejections == [Rejection(id: 1, reason: .physicalClick)])
  #expect(run.measures.isEmpty)
}

@Test func disabledZoneCarriesNoMeasure() {
  // Only the lower half of the right edge is mapped; the touch lands in the upper half.
  let frames = TraceBuilder([Stroke(id: 1, [(0, 146, 80), (0.1, 146, 80)])]).frames()
  let run = replay(frames, zones: [.edge(.right, segment: 0, segments: 2)])
  #expect(run.rejections == [Rejection(id: 1, reason: .disabledZone)])
  #expect(run.measures.isEmpty)
}

@Test func recognizedGesturesCarryNoMeasure() throws {
  let run = replay(try Fixtures.load("deliberate-slide-right-up"), zones: [rightEdge])
  #expect(run.rejections.isEmpty)
  #expect(run.measures.isEmpty)
}
