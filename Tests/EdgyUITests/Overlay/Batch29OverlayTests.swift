import Actions
import EdgyCore
import EdgyRuntime
import Foundation
import SwiftUI
import Testing

@testable import EdgyUI

/// Batch 29 plates (BRIEF § Your own name and icon, § Key sequences): a custom name is the whole
/// value line with no verb; a key sequence reads "Pressed ⌃ B, N". The second line never changes.
@MainActor
@Suite(.serialized)
struct Batch29OverlayTests {
  static let folder = "batch-29"
  static let corner = Zone.corner(.bottomRight)

  static func context(_ binding: EdgyCore.Binding) -> PlateContext { PlateContext(bindings: [binding]) }

  static let dictate = EdgyCore.Binding(
    zone: corner, gesture: .longPress, action: BuiltInAction.keyboardHold, parameters: ["keys": "fn"],
    customName: "Dictate", customIcon: BuiltInAction.dictation)

  static let playNamed = EdgyCore.Binding(
    zone: corner, gesture: .doubleTap, action: BuiltInAction.playPause, customName: "Dictate")

  static let sequence = EdgyCore.Binding(
    zone: .edge(.top), gesture: .tap, action: BuiltInAction.keyboardShortcut, parameters: ["keys": "ctrl+b n"])

  private func shoot(_ plates: [PlateContent], _ name: String) throws {
    let stack = VStack(alignment: .leading, spacing: 16) {
      ForEach(Array(plates.enumerated()), id: \.offset) { PlateView($1) }
    }
    .padding(24).background(Tokens.windowTint)
    #expect(try Snapshot.write(stack, folder: Self.folder, name: name).count == 2)
  }

  // MARK: Custom name

  @Test func runPlateIsTheCustomNameWithNoVerb() throws {
    let content = try #require(
      plate(
        .actionRan(BuiltInAction.playPause, zone: Self.corner, kind: .doubleTap), context: Self.context(Self.playNamed))
    )
    #expect(content.title == "Dictate")
    #expect(content.detail == "Bottom-right corner, double-tap")
    // A custom name wins over a parameter's verb too ("Opened Quillpad" → the name).
    let app = EdgyCore.Binding(
      zone: Self.corner, gesture: .tap, action: BuiltInAction.openApp,
      parameters: ["bundleID": "com.example.quillpad"], customName: "Write")
    #expect(
      plate(.actionRan(BuiltInAction.openApp, zone: Self.corner, kind: .tap), context: Self.context(app))?.title
        == "Write")
    try shoot([content], "plate-custom-run")
  }

  @Test func holdPlateReadsHeldThenReleased() throws {
    let held = try #require(
      plate(
        .actionRan(
          BuiltInAction.keyboardHold, zone: Self.corner, kind: .longPress, outcome: ActionOutcome(detail: "fn")),
        context: Self.context(Self.dictate)))
    #expect(held.kind == .holding)
    #expect(held.title == "Dictate, held")
    #expect(held.detail == "Bottom-right corner, long-press")
    let released = try #require(held.released(cancelled: false))
    #expect(released.title == "Dictate, released")
    #expect(released.detail == "Bottom-right corner, long-press")
    // Cancelled: the tail stays, as for "Released fn, finger left the zone".
    #expect(held.released(cancelled: true)?.title == "Dictate, released, finger left the zone")
    try shoot([held], "plate-custom-hold-held")
    try shoot([released], "plate-custom-hold-released")
  }

  @Test func holdNamedLikeThePrefixStillReleasesByName() {
    var binding = Self.dictate
    binding.customName = "Holding pen"
    let held = plate(
      .actionRan(BuiltInAction.keyboardHold, zone: Self.corner, kind: .longPress), context: Self.context(binding))
    #expect(held?.released(cancelled: false)?.title == "Holding pen, released")
  }

  @Test func dryRunReadsWouldRunTheCustomName() throws {
    let content = try #require(
      plate(
        .wouldRun(BuiltInAction.playPause, zone: Self.corner, kind: .doubleTap), context: Self.context(Self.playNamed),
        dryRun: true))
    #expect(content.title == "Would run Dictate")
    #expect(content.detail == "Bottom-right corner, double-tap")
    // A held binding in dry run keeps the hold's verbs around the name.
    let held = plate(
      .wouldRun(BuiltInAction.keyboardHold, zone: Self.corner, kind: .longPress), context: Self.context(Self.dictate),
      dryRun: true)
    #expect(held?.title == "Would hold Dictate")
    #expect(held?.released(cancelled: false)?.title == "Would release Dictate")
    try shoot([content], "plate-custom-dry-run")
  }

  @Test func withoutACustomNameNothingChanges() {
    var plain = Self.dictate
    plain.customName = nil
    let held = plate(
      .actionRan(BuiltInAction.keyboardHold, zone: Self.corner, kind: .longPress, outcome: ActionOutcome(detail: "fn")),
      context: Self.context(plain))
    #expect(held?.title == "Holding fn")
    #expect(held?.released(cancelled: false)?.title == "Released fn")
    #expect(
      plate(.actionRan(BuiltInAction.playPause, zone: Self.corner, kind: .doubleTap))?.title == "Play/Pause")
  }

  @Test func levelPlatesIgnoreTheCustomName() {
    let volume = EdgyCore.Binding(
      zone: .edge(.right), gesture: .slide, action: BuiltInAction.volume, customName: "Loud")
    let content = plate(
      .actionRan(BuiltInAction.volume, zone: .edge(.right), kind: .slide, outcome: ActionOutcome(level: 0.64)),
      context: Self.context(volume))
    #expect(content?.title == "Volume 64%")
  }

  // MARK: Key sequences

  @Test func sequencePlateReadsPressedAndWouldPress() throws {
    let ran = try #require(
      plate(
        .actionRan(BuiltInAction.keyboardShortcut, zone: .edge(.top), kind: .tap), context: Self.context(Self.sequence))
    )
    #expect(ran.title == "Pressed ⌃ B, N")
    #expect(ran.detail == "Top edge, tap")
    let dry = try #require(
      plate(
        .wouldRun(BuiltInAction.keyboardShortcut, zone: .edge(.top), kind: .tap), context: Self.context(Self.sequence),
        dryRun: true))
    #expect(dry.title == "Would press ⌃ B, N")
    // One combo is unchanged when run, and reads "Would press" in dry run (BRIEF § Key sequences).
    var single = Self.sequence
    single.parameters = ["keys": "cmd+shift+4"]
    #expect(
      plate(.actionRan(BuiltInAction.keyboardShortcut, zone: .edge(.top), kind: .tap), context: Self.context(single))?
        .title == "Pressed ⇧⌘ 4")
    #expect(
      plate(
        .wouldRun(BuiltInAction.keyboardShortcut, zone: .edge(.top), kind: .tap), context: Self.context(single),
        dryRun: true)?.title == "Would press ⇧⌘ 4")
    #expect(PlateNaming.keys(["keys": "ctrl+b nope+"]) == nil)
    try shoot([ran, dry], "plate-sequence")
  }
}
