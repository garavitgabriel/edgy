import EdgyCore
import Foundation
import Testing

@testable import EdgyRuntime

// Batch 28 (batch 26 follow-up): a Switch Apps slide is silent until the switcher opens. A finger
// resting on its edge plays no `gestureCaught` tick and feeds no `actionRan`. Fake actions only.

private final class SwitcherRig {
  let actions = FakeActions()
  let router: Router
  var decisions: [LiveDecision] = []
  var config = EdgyConfig.defaults
  /// The fake switcher opens on the slide's first update with this much travel.
  var opened = false

  init() {
    actions.available = MachineCatalog.descriptors
    router = Router(actions: actions, logger: RecordingLogger())
    router.onDecision = { [unowned self] in self.decisions.append($0) }
    config.defaultProfile.bindings.removeAll { $0.zone == .edge(.top) && $0.gesture == .slide }
    config.defaultProfile.bindings.append(Binding(zone: .edge(.top), gesture: .slide, action: "apps.switcher"))
    // Like the registry: an outcome only while the switcher shows; it opens past 8 mm of delta.
    actions.outcome = { [unowned self] _, input in
      if case .delta(let delta, _) = input, abs(delta) >= 0.08 { self.opened = true }
      return self.opened ? ActionOutcome(systemHUDShown: true) : nil
    }
  }

  func slide(_ phase: GestureEvent.Phase, delta: Double = 0) {
    router.route(Sample.event(.edge(.top), .slide, phase: phase, delta: delta), config: config, frontmostBundleID: nil)
  }

  var ran: [LiveDecision] {
    decisions.filter { if case .actionRan = $0 { return true } else { return false } }
  }
}

@Suite struct Batch28RouterTests {
  @Test func aRestingFingerOnTheSwitcherEdgeTicksNothingAndReportsNothing() {
    let rig = SwitcherRig()
    rig.slide(.began)
    rig.slide(.changed, delta: 0.01)
    rig.slide(.ended)
    // Was (batch 26): one `gestureCaught` and one `actionRan(outcome: nil)` at `.began`.
    #expect(!rig.actions.feedbacks.contains(.gestureCaught))
    #expect(rig.ran.isEmpty)
    #expect(rig.decisions.isEmpty)
  }

  @Test func theSwitcherReportsWhenItOpens() {
    let rig = SwitcherRig()
    rig.slide(.began)
    #expect(rig.decisions.isEmpty)
    rig.slide(.changed, delta: 0.1)
    #expect(
      rig.ran == [
        .actionRan("apps.switcher", zone: .edge(.top), kind: .slide, outcome: ActionOutcome(systemHUDShown: true))
      ])
    rig.slide(.changed, delta: 0.1)
    rig.slide(.ended)
    #expect(rig.ran.count == 1)
    #expect(!rig.actions.feedbacks.contains(.gestureCaught))
  }

  @Test func otherSlidesStillTickAndReportAtTheirStart() {
    let rig = SwitcherRig()
    rig.router.route(
      Sample.event(.edge(.right), .slide, phase: .began, delta: 0), config: rig.config, frontmostBundleID: nil)
    #expect(rig.actions.feedbacks.contains(.gestureCaught))
    #expect(rig.ran.count == 1)
  }

  @Test func aSwitcherThatFailsAtItsStartStillReportsTheFailure() {
    let rig = SwitcherRig()
    rig.actions.errorToThrow = NSError(domain: "test", code: 1)
    rig.slide(.began)
    #expect(rig.decisions.count == 1)
  }
}
