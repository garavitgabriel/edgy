import EdgyCore
import Foundation
import Testing

@testable import EdgyRuntime

// Measured rejections and action outcomes, from fake recognizers and fake actions through the
// router and the feed. Nothing touches the real system.

/// A router wired to fake actions, recording its decisions.
private final class RouterRig {
  let actions = FakeActions()
  let router: Router
  var decisions: [LiveDecision] = []
  var config = EdgyConfig.defaults

  init(catalog: [ActionDescriptor] = MachineCatalog.descriptors) {
    actions.available = catalog
    router = Router(actions: actions, logger: RecordingLogger())
    router.onDecision = { [unowned self] in self.decisions.append($0) }
  }

  func slide(_ phase: GestureEvent.Phase, delta: Double = 0, zone: Zone = .edge(.left)) {
    router.route(Sample.event(zone, .slide, phase: phase, delta: delta), config: config, frontmostBundleID: nil)
  }

  /// Fake brightness: the level follows the slide's deltas from 0.5; `detail` per call.
  func levelSlides(detail: @escaping () -> String?) {
    var level = 0.5
    actions.outcome = { _, input in
      if case .delta(let delta, _) = input { level = min(max(level + delta, 0), 1) }
      return ActionOutcome(level: level, detail: detail())
    }
  }

  var updates: [ActionOutcome] {
    decisions.compactMap { if case .actionUpdated(_, _, _, let outcome) = $0 { return outcome } else { return nil } }
  }
  var checks: [LiveDecision] {
    decisions.filter { if case .displayCheckDue = $0 { return true } else { return false } }
  }
}

private let marker = "\u{1E}displayCheck:"

@Suite struct OutcomeFeedTests {
  // MARK: Rejections carry their measure

  @Test func feedCarriesTheRejectionMeasure() throws {
    let f = try FeedHarness()
    let onRight = FeedHarness.contact(4, x: 0.98, y: 0.5)
    let palm = RejectionMeasure(measured: 21, limit: 18, unit: .mm)
    f.frame([onRight], GestureOutput(rejections: [(4, .palm)], rejectionMeasures: [4: palm]))
    #expect(
      f.decisions == [
        .rejected(contactID: 4, zone: .edge(.right), reason: .palm, deviceID: Sample.device.id, measure: palm)
      ])
  }

  @Test func rejectionsWithoutANumberCarryNone() throws {
    let f = try FeedHarness()
    let finger = FeedHarness.contact(4, x: 0.98, y: 0.5)
    f.frame([finger], GestureOutput(rejections: [(4, .physicalClick)]))
    guard case .rejected(_, _, .physicalClick, _, let measure) = f.decisions.first else {
      Issue.record("no rejection")
      return
    }
    #expect(measure == nil)
  }

  @Test func eachContactGetsItsOwnMeasure() throws {
    let f = try FeedHarness()
    let a = FeedHarness.contact(1, x: 0.98, y: 0.4)
    let b = FeedHarness.contact(2, x: 0.98, y: 0.6)
    let typing = RejectionMeasure(measured: 200, limit: 500, unit: .ms)
    f.frame(
      [a, b], GestureOutput(rejections: [(1, .typing), (2, .systemGestureHandoff)], rejectionMeasures: [1: typing]))
    let measures = f.decisions.compactMap { decision -> RejectionMeasure?? in
      if case .rejected(_, _, _, _, let measure) = decision { return measure } else { return nil }
    }
    #expect(measures == [typing, nil])
  }

  // MARK: Outcomes on actionRan

  @Test func feedCarriesTheOutcomeOnActionRan() throws {
    let f = try FeedHarness(catalog: MachineCatalog.descriptors)
    f.h.actions.outcome = { _, _ in ActionOutcome(level: 0.64, systemHUDShown: true) }
    let right = Zone.edge(.right)
    f.frame([], GestureOutput(events: [Sample.event(right, .slide, phase: .began)]))
    #expect(
      f.decisions.contains(
        .actionRan("audio.volume", zone: right, kind: .slide, outcome: ActionOutcome(level: 0.64, systemHUDShown: true))
      ))
  }

  @Test func actionsThatReportNothingRunWithANilOutcome() {
    let rig = RouterRig()
    rig.router.route(Sample.event(.edge(.bottom), .doubleTap), config: rig.config, frontmostBundleID: nil)
    #expect(rig.decisions == [.actionRan("media.playPause", zone: .edge(.bottom), kind: .doubleTap, outcome: nil)])
  }

  @Test func holdPressCarriesTheHeldCombo() {
    let rig = RouterRig()
    rig.config = HoldSetup.config
    rig.actions.outcome = { _, input in input == .press(down: true) ? ActionOutcome(detail: "fn") : nil }
    rig.router.route(HoldSetup.event(.began), config: rig.config, frontmostBundleID: nil)
    rig.router.route(HoldSetup.event(.ended), config: rig.config, frontmostBundleID: nil)
    #expect(
      rig.decisions == [
        .actionRan("keyboard.hold", zone: HoldSetup.corner, kind: .longPress, outcome: ActionOutcome(detail: "fn"))
      ])
    #expect(rig.actions.performed.map(\.input) == [.press(down: true), .press(down: false)])
  }

  @Test func testModeReportsWouldRunWithoutPerforming() {
    let rig = RouterRig()
    rig.router.testMode = true
    rig.actions.outcome = { _, _ in ActionOutcome(level: 1) }
    rig.slide(.began)
    rig.slide(.changed, delta: 0.2)
    #expect(rig.decisions == [.wouldRun("display.brightness", zone: .edge(.left), kind: .slide)])
    #expect(rig.actions.performed.isEmpty)
  }

  // MARK: Slides follow the level

  @Test func slideUpdatesOnlyWhenTheWholePercentChanges() {
    let rig = RouterRig()
    rig.levelSlides { "Desk 34" }
    rig.slide(.began)
    rig.slide(.changed, delta: 0.001)  // 50.1%: still 50%
    rig.slide(.changed, delta: 0.1)  // 60%
    rig.slide(.changed, delta: 0.002)  // 60.2%: still 60%
    rig.slide(.changed, delta: 0.05)  // 65%
    rig.slide(.ended)
    #expect(
      rig.decisions.first
        == .actionRan(
          "display.brightness", zone: .edge(.left), kind: .slide, outcome: ActionOutcome(level: 0.5, detail: "Desk 34"))
    )
    #expect(rig.updates.compactMap { DisplayCheckDetail.percent($0.level) } == [60, 65])
    #expect(rig.updates.allSatisfy { $0.detail == "Desk 34" })
  }

  @Test func slideReportStateIsDroppedOnReset() {
    let rig = RouterRig()
    rig.levelSlides { "Desk 34" + marker + "k1" }
    rig.slide(.began)
    rig.slide(.changed, delta: 0.2)
    rig.router.reset()
    rig.slide(.ended)
    #expect(rig.checks.isEmpty)
  }

  // MARK: Display check

  @Test func checkIsDueAtTheEndOfASlideThatMovedTheLevel() {
    let rig = RouterRig()
    rig.levelSlides { "Desk 34" + marker + "4c2d-7154-9" }
    rig.slide(.began)
    rig.slide(.changed, delta: 0.2)
    #expect(rig.checks.isEmpty)
    rig.slide(.ended)
    #expect(rig.checks == [.displayCheckDue(key: "4c2d-7154-9", name: "Desk 34")])
    // The marker never reaches the feed's outcomes.
    #expect(rig.updates.allSatisfy { $0.detail == "Desk 34" })
    #expect(!rig.decisions.contains { "\($0)".contains("displayCheck:") })
  }

  @Test func noCheckWhenTheSlideDidNotMoveTheLevel() {
    let rig = RouterRig()
    rig.levelSlides { "Desk 34" + marker + "k1" }
    rig.slide(.began)
    rig.slide(.ended)
    #expect(rig.checks.isEmpty)
  }

  @Test func noCheckWhenTheOutcomeAsksForNone() {
    let rig = RouterRig()
    rig.levelSlides { "Desk 34" }
    rig.slide(.began)
    rig.slide(.changed, delta: 0.3)
    rig.slide(.ended)
    #expect(rig.checks.isEmpty)
  }

  @Test func cancelledSlideThatMovedStillAsks() {
    let rig = RouterRig()
    rig.levelSlides { "Desk 34" + marker + "k1" }
    rig.slide(.began)
    rig.slide(.changed, delta: -0.2)
    rig.slide(.cancelled)
    #expect(rig.checks == [.displayCheckDue(key: "k1", name: "Desk 34")])
  }

  @Test func markerMatchesTheActionsModule() {
    // Actions' `DisplayCheckRequest.marker` is pinned to the same literal in ActionsTests.
    #expect(DisplayCheckDetail.marker == "\u{1E}displayCheck:")
    let (clean, request) = DisplayCheckDetail.split(ActionOutcome(level: 0.4, detail: "A" + marker + "k"))
    #expect(clean == ActionOutcome(level: 0.4, detail: "A"))
    #expect(request == DisplayCheckDetail.Request(key: "k", name: "A"))
    #expect(DisplayCheckDetail.split(nil).0 == nil)
  }
}
