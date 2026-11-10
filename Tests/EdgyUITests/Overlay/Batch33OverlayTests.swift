import Actions
import EdgyCore
import EdgyRuntime
import Foundation
import Testing

@testable import EdgyUI

/// Batch 33 fix 4: a re-trigger while a key sequence is still sending stays silent (no plate).
/// The action ignores that trigger (`ActionRegistry.performShortcut`), so a plate would lie.
@MainActor
@Suite(.serialized)
struct Batch33OverlayTests {
  static let zone = Zone.corner(.bottomLeft)

  func rig(keys: String) -> (OverlayController, ManualClock) {
    var config = PreviewFixtures.demoConfig
    config.defaultProfile.bindings.removeAll { $0.zone == Self.zone }
    config.defaultProfile.bindings.append(
      EdgyCore.Binding(
        zone: Self.zone, gesture: .doubleTap, action: BuiltInAction.keyboardShortcut, parameters: ["keys": keys]))
    let (controller, _, clock, _) = overlayRig(model: PreviewFixtures.model(config: config))
    return (controller, clock)
  }

  let ran = LiveDecision.actionRan(BuiltInAction.keyboardShortcut, zone: zone, kind: .doubleTap)

  private func newest(_ controller: OverlayController) -> Int { controller.timeline.entries.map(\.id).max() ?? 0 }

  @Test func reTriggerWhileASequenceSendsShowsNoPlate() {
    let (controller, clock) = rig(keys: "ctrl+b n x")
    controller.receive([ran])
    let first = newest(controller)
    #expect(first > 0)
    #expect(controller.timeline.entries.last?.content.title == "Pressed ⌃B, N, X")
    // Still sending (two more steps, 40 ms apart): the re-trigger is ignored and says nothing.
    clock.now += 0.030
    controller.receive([ran])
    #expect(newest(controller) == first)
    clock.now += 0.040
    controller.receive([ran])
    #expect(newest(controller) == first)
    // Sent: the next trigger runs and shows its plate.
    clock.now += 0.020
    controller.receive([ran])
    #expect(newest(controller) > first)
  }

  @Test func singleCombosAreNeverQuieted() {
    let (controller, clock) = rig(keys: "cmd+shift+4")
    controller.receive([ran])
    let first = newest(controller)
    clock.now += 0.001
    controller.receive([ran])
    #expect(newest(controller) > first)
  }

  @Test func quietWindowLastsOneGapPerRemainingStep() {
    var quiet = SequenceQuiet()
    let context = PlateContext(bindings: [
      EdgyCore.Binding(
        zone: Self.zone, gesture: .doubleTap, action: BuiltInAction.keyboardShortcut,
        parameters: ["keys": "ctrl+b n"])
    ])
    let starts = quiet.admits(ran, context: context, now: 10)
    #expect(starts)
    #expect(quiet.sendingUntil == 10 + SequenceQuiet.stepGap)
    let retrigger = quiet.admits(ran, context: context, now: 10.02)
    #expect(!retrigger)
    // Other plates are never held back.
    let other = quiet.admits(
      .actionRan(BuiltInAction.playPause, zone: .edge(.bottom), kind: .doubleTap), context: context, now: 10.02)
    #expect(other)
    let after = quiet.admits(ran, context: context, now: 10.05)
    #expect(after)
  }
}
