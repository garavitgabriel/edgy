import EdgyCore
import Testing

@testable import Gestures

// Misfire hardening: things hands really do near the edges. Each scenario runs against the zone
// sets the shipped preset produces (`EdgyConfig.defaults`), unless it names its own binding.
// Built-in trackpad, 150 × 95 mm; edges 8 mm, corners 12 mm.

enum Preset {
  static let zones: Set<Zone> = Set(EdgyConfig.defaults.defaultProfile.bindings.map(\.zone))
  static let slideZones: Set<Zone> = Set(
    EdgyConfig.defaults.defaultProfile.bindings.filter { $0.gesture == .slide }.map(\.zone))
  static let longPressZones: Set<Zone> = []

  static func run(_ strokes: [Stroke], typing: Double? = nil, longPress: Set<Zone> = longPressZones) -> Replay {
    replay(
      TraceBuilder(strokes).frames(), zones: zones, secondsSinceLastKeyPress: typing, slideZones: slideZones,
      longPressZones: longPress)
  }
}

extension Replay {
  func reasons(_ id: Int32) -> [RejectionReason] { rejections.filter { $0.id == id }.map(\.reason) }
}

// MARK: - Resting thumb

@Test func thumbRestingOnBottomEdgeWhileIndexMovesElsewhere() {
  // The thumb parks on the bottom edge (swipes + double-tap there, no slide); the index finger
  // lands mid-pad and moves the pointer. Nothing may fire or claim.
  let run = Preset.run([
    Stroke(id: 1, [(0, 70, 3), (1.4, 70.4, 3.2)]),
    Stroke(id: 2, [(0.3, 80, 50), (0.5, 80, 50), (1.2, 110, 65)]),
  ])
  #expect(run.events.isEmpty)
  #expect(run.neverClaimed)
  #expect(run.reasons(1) == [.tooManyContacts])
}

@Test func thumbRestingOnASlideEdgeIsLetGoWhenAnotherFingerMoves() {
  // Same hand, but the thumb rests on the right edge (volume) long enough to claim a slide before
  // the index finger arrives. A resting late finger keeps the claim (see
  // lateRestingFingerDoesNotCancelClaimedSlide); one that moves the pointer revokes it, or the
  // pointer stays frozen under the user's moving finger.
  let run = Preset.run([
    Stroke(id: 1, [(0, 146, 20), (1.4, 146, 20)]),
    Stroke(id: 2, [(0.4, 80, 50), (0.5, 80, 50), (1.2, 110, 65)]),
  ])
  #expect(run.changed.isEmpty)
  #expect(run.slideEvents.map(\.phase) == [.began, .cancelled])
  #expect(run.reasons(1) == [.tooManyContacts])
  expectClaimsFollowSlide(run)
  // Let go within ~3 mm of the index finger starting to move (~43 mm/s → about 70 ms).
  let cancel = run.slideEvents.last.map(run.relative) ?? 0
  #expect(cancel > 0.5 && cancel < 0.6)
}

@Test func thumbHoldingAPushToTalkCornerIsCancelledWhenAnotherFingerMoves() {
  // A hold bound to the bottom-left corner; the thumb has held it past 500 ms when the index
  // finger starts moving the pointer. The claim would freeze that pointer, so the hold ends.
  let run = replay(
    TraceBuilder([
      Stroke(id: 1, [(0, 4, 4), (1.4, 4, 4)]),
      Stroke(id: 2, [(0.7, 80, 50), (0.8, 80, 50), (1.2, 110, 65)]),
    ]).frames(), zones: Preset.zones.union([.corner(.bottomLeft)]), slideZones: Preset.slideZones,
    longPressZones: [.corner(.bottomLeft)])
  #expect(holdPhases(run) == [.began, .cancelled])
  expectHoldsArePaired(run)
  #expect(run.endsUnclaimed)
}

// MARK: - Multi-finger system gestures

@Test func twoFingerScrollDriftingIntoRightEdgeNeverClaims() {
  let run = Preset.run([
    Stroke(id: 1, [(0, 105, 40), (0.5, 140, 60)]),
    Stroke(id: 2, [(0.01, 120, 42), (0.5, 147, 62)]),
  ])
  #expect(run.events.isEmpty)
  #expect(run.neverClaimed)
  #expect(run.reasons(2) == [.startedOutsideZone])
}

@Test func twoFingerScrollStartingInRightEdgeIsRejected() {
  let run = Preset.run([
    Stroke(id: 1, [(0, 146, 30), (0.4, 146, 70)]),
    Stroke(id: 2, [(0.012, 130, 31), (0.4, 130, 71)]),
  ])
  #expect(run.events.isEmpty)
  #expect(run.neverClaimed)
  #expect(run.reasons(1) == [.tooManyContacts])
}

@Test func threeFingerSwipeStartingAtTheRightEdgeIsRejected() {
  let run = Preset.run([
    Stroke(id: 1, [(0, 146, 30), (0.25, 90, 30)]),
    Stroke(id: 2, [(0.01, 146, 50), (0.25, 90, 50)]),
    Stroke(id: 3, [(0.02, 146, 70), (0.25, 90, 70)]),
  ])
  #expect(run.events.isEmpty)
  #expect(run.neverClaimed)
  #expect(Set([1, 2, 3].flatMap(run.reasons)) == [.tooManyContacts])
}

@Test func fourFingerSwipeUpFromTheBottomEdgeIsRejected() {
  let run = Preset.run([
    Stroke(id: 1, [(0, 40, 3), (0.3, 40, 60)]),
    Stroke(id: 2, [(0.01, 60, 4), (0.3, 60, 61)]),
    Stroke(id: 3, [(0.015, 80, 4), (0.3, 80, 61)]),
    Stroke(id: 4, [(0.02, 100, 3), (0.3, 100, 60)]),
  ])
  #expect(run.events.isEmpty)
  #expect(run.neverClaimed)
}

@Test func threeFingerSwipeSidewaysAlongTheBottomEdgeIsNotASwipe() {
  // Spaces switching with three fingers that happen to sit low: along the bottom edge's own
  // axis, fast — exactly what a one-finger media swipe looks like, times three.
  let run = Preset.run([
    Stroke(id: 1, [(0, 40, 4), (0.2, 90, 4)]),
    Stroke(id: 2, [(0.01, 55, 6), (0.2, 105, 6)]),
    Stroke(id: 3, [(0.02, 70, 5), (0.2, 120, 5)]),
  ])
  #expect(run.events.isEmpty)
  #expect(run.neverClaimed)
}

// MARK: - Palms, typing, system edge swipes

@Test func palmLandingOnLeftEdgeWhileTypingIsRejected() {
  var palm = Stroke(id: 1, [(0, 5, 40), (0.8, 5, 40)])
  palm.majorAxisMM = 12
  palm.grownMajorAxisMM = 26
  palm.minorAxisMM = 11
  let run = Preset.run([palm], typing: 0.15)
  #expect(run.events.isEmpty)
  #expect(run.neverClaimed)
  // Typing rejects it at landing, before it spreads wide enough to read as a palm.
  #expect(run.reasons(1) == [.typing])
}

@Test func palmLandingOnLeftEdgeIsRejectedAsPalm() {
  var palm = Stroke(id: 1, [(0, 5, 40), (0.8, 5, 40)])
  palm.majorAxisMM = 12
  palm.grownMajorAxisMM = 26
  palm.minorAxisMM = 11
  let run = Preset.run([palm])
  #expect(run.events.isEmpty)
  #expect(run.slideEvents.isEmpty)
  #expect(run.reasons(1) == [.palm])
}

@Test func fingertipGrazingRightEdgeRightAfterTypingIsRejected() {
  let run = Preset.run([Stroke(id: 1, [(0, 146, 50), (0.6, 146, 58)])], typing: 0.2)
  #expect(run.events.isEmpty)
  #expect(run.neverClaimed)
  #expect(run.reasons(1) == [.typing])
}

@Test func slowInwardSwipeFromRightEdgeHandsOffToSystem() {
  // Unhurried, with a short pause on landing and a little along-axis wobble: still the system's.
  var stroke = Stroke(id: 1, [(0, 147, 50), (0.08, 147, 50), (0.5, 115, 53)])
  stroke.jitterMM = 0.2
  let run = Preset.run([stroke])
  #expect(run.events.isEmpty)
  #expect(run.neverClaimed)
  #expect(run.reasons(1) == [.systemGestureHandoff])
}

@Test func inwardSwipeUpFromBottomEdgeHandsOffToSystem() {
  let run = Preset.run([Stroke(id: 1, [(0, 75, 2), (0.15, 75, 40)])])
  #expect(run.events.isEmpty)
  #expect(run.reasons(1) == [.systemGestureHandoff])
}

// MARK: - Long-press drift, boundaries

@Test func longPressThatDriftsSlowlyInACornerDoesNotFire() {
  let run = replay(
    TraceBuilder([Stroke(id: 1, [(0, 5, 90), (0.9, 7.2, 89)])]).frames(), zones: [.corner(.topLeft)],
    longPressZones: [.corner(.topLeft)])
  #expect(holdPhases(run).isEmpty)
  #expect(run.neverClaimed)
}

@Test func longPressThatDriftsSlowlyAlongAnEdgeDoesNotFire() {
  let run = replay(
    TraceBuilder([Stroke(id: 1, [(0, 60, 3), (0.9, 62.5, 3)])]).frames(), zones: [.edge(.bottom)],
    slideZones: [], longPressZones: [.edge(.bottom)])
  #expect(holdPhases(run).isEmpty)
  #expect(!run.events.contains { $0.kind == .longPress })
}

@Test func tapOnTheCornerEdgeBoundary() {
  // The corner square is [0, 12) mm from both sides. Exactly 12.0 mm is the edge's; 11.9 is the
  // corner's. A mapped corner wins inside its square; an unmapped one falls through to the edge.
  func tap(_ x: Double, _ y: Double, zones: Set<Zone>) -> [GestureEvent] {
    replay(TraceBuilder([Stroke(id: 1, [(0, x, y), (0.08, x, y)])]).frames(), zones: zones).events
  }
  let both: Set<Zone> = [.corner(.bottomRight), .edge(.bottom)]
  #expect(tap(150 - 11.9, 3, zones: both).map(\.zone) == [.corner(.bottomRight)])
  #expect(tap(150 - 12.0, 3, zones: both).map(\.zone) == [.edge(.bottom)])
  #expect(tap(150 - 12.1, 3, zones: both).map(\.zone) == [.edge(.bottom)])
  // Corner unmapped: the same spot is the bottom edge, so the edge's ends are never dead.
  #expect(tap(150 - 11.9, 3, zones: [.edge(.bottom)]).map(\.zone) == [.edge(.bottom)])
  // Inside the corner square but outside the 8 mm strip of the edge it borders: corner only.
  #expect(tap(150 - 4, 10, zones: both).map(\.zone) == [.corner(.bottomRight)])
  #expect(tap(150 - 4, 10, zones: [.edge(.bottom)]).isEmpty)
}

@Test func tapThatLandsInACornerAndRollsIntoTheEdgeStaysACornerTap() {
  // The zone is decided where the finger lands; a 1 mm roll across the line changes nothing.
  let run = replay(
    TraceBuilder([Stroke(id: 1, [(0, 138.5, 3), (0.1, 137.5, 3)])]).frames(),
    zones: [.corner(.bottomRight), .edge(.bottom)])
  #expect(run.events.map(\.zone) == [.corner(.bottomRight)])
  #expect(run.events.map(\.kind) == [.tap])
}

// MARK: - Physical click

@Test(
  .disabled(
    "blocker: TouchFrame/TouchContact carry no button state, so a physical click-and-drag can't be told from a slide. See .parallel-plans/blockers-batch-9.md"
  ))
func physicalClickAndDragStartingInAnEdgeStripIsNotOurs() {
  // A click-drag (button down) from the right edge strip up along it — a window resize or a text
  // selection. Today it is indistinguishable from a deliberate volume slide, so it claims.
  let run = Preset.run([Stroke(id: 1, [(0, 146, 30), (0.15, 146, 30), (0.75, 146, 60)])])
  #expect(run.neverClaimed)
  #expect(run.events.isEmpty)
}
