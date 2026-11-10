import Actions
import EdgyCore
import EdgyRuntime
import SwiftUI
import Testing

@testable import EdgyUI

/// Batch 33: critique 29 design answers 1 (no commas in combined edge labels) and 3 (corner tabs
/// grow to 40% of their edge), and answer 2 (the dry-run verb by kind).
@MainActor
@Suite(.serialized)
struct Batch33MirrorTests {
  static let folder = "batch-33"

  private func model(replacing zones: [Zone], with bindings: [EdgyCore.Binding]) -> SettingsModel {
    var config = PreviewFixtures.demoConfig
    config.defaultProfile.bindings.removeAll { zones.contains($0.zone) }
    config.defaultProfile.bindings += bindings
    return PreviewFixtures.model(config: config)
  }

  private func pad(_ model: SettingsModel) -> MirrorPad {
    MirrorPad(
      geometry: MirrorGeometry(
        sensorSizeMM: PreviewFixtures.externalPad.sensorSizeMM, settings: model.editor.config.gestures,
        pointsPerMM: Tokens.mirrorPointsPerMM), zones: model.mirrorZones(forApp: nil), selected: nil)
  }

  private func shootPad(_ model: SettingsModel, _ name: String) throws {
    let view = PadMirrorView(model: model).padding(28).background(Tokens.windowTint)
    #expect(try Snapshot.write(view, folder: Self.folder, name: name).count == 2)
  }

  // MARK: Answer 3

  @Test func cornerTabGrowsToFortyPercentOfItsEdge() throws {
    let url = EdgyCore.Binding(
      zone: .corner(.bottomLeft), gesture: .doubleTap, action: BuiltInAction.openURL,
      parameters: ["url": "https://www.example.com/plans"])
    let file = EdgyCore.Binding(
      zone: .corner(.bottomRight), gesture: .doubleTap, action: BuiltInAction.openFile,
      parameters: ["path": "~/Documents/report.pdf"])
    let model = model(replacing: [.corner(.bottomLeft), .corner(.bottomRight)], with: [url, file])
    let mirror = pad(model)
    let corner = try #require(model.mirrorZones(forApp: nil).first { $0.zone == .corner(.bottomLeft) })
    let grow = mirror.cornerGrowRoom(corner)
    #expect(grow == mirror.geometry.size.width * MirrorPad.cornerTabEdgeShare - 18)
    #expect(grow > mirror.labelRoom(corner, placement: mirror.labelPlacement(corner)))
    #expect(MirrorPad.textWidth("example.com") > mirror.labelRoom(corner, placement: mirror.labelPlacement(corner)))
    // "example.com" no longer fades to "example.co".
    let fit = mirror.fittedLabel(corner, placement: mirror.labelPlacement(corner))
    #expect(fit == MirrorPad.FittedLabel(text: "example.com", clipWidth: nil))
    // A short form that fits the usual width still wins (render A's "Mic off").
    let defaults = PreviewFixtures.model()
    let mic = try #require(defaults.mirrorZones(forApp: nil).first { $0.zone == .corner(.topLeft) })
    let defaultPad = pad(defaults)
    #expect(defaultPad.fittedLabel(mic, placement: defaultPad.labelPlacement(mic)).text == "Mic off")
    try shootPad(model, "pad-corner-tab-forty-percent")
  }

  // MARK: Fix 5: format once per revision

  @Test func comboLabelsAreFormattedOncePerRevision() throws {
    let shortcut = EdgyCore.Binding(
      zone: .corner(.bottomLeft), gesture: .doubleTap, action: BuiltInAction.keyboardShortcut,
      parameters: ["keys": "ctrl+b n"])
    let model = model(replacing: [.corner(.bottomLeft)], with: [shortcut])
    let before = model.mirrorData.zoneComputations
    for _ in 0..<60 { _ = model.mirrorZones(forApp: nil) }  // a second of frames
    #expect(model.mirrorData.zoneComputations - before <= 1)
    #expect(model.mirrorZones(forApp: nil).first { $0.zone == .corner(.bottomLeft) }?.label == "⌃B, N")
  }

  // MARK: Answer 1

  @Test func combinedEdgeLabelHasNoCommas() throws {
    let model = PreviewFixtures.model()
    let bottom = try #require(
      model.mirrorZones(forApp: PreviewFixtures.wayfare).first { $0.zone == .edge(.bottom) })
    #expect(bottom.label == "⇧⌘[ and 2 more")
    #expect(!(bottom.label ?? "").contains(","))
    // The hover line still lists them all (bone 10).
    #expect(MiniMirrorView.hoverLine(bottom).hasPrefix("Bottom: ⇧⌘[, "))
    // The default bottom edge's pair still collapses first: two names, "A and B".
    let plain = try #require(model.mirrorZones(forApp: nil).first { $0.zone == .edge(.bottom) })
    #expect(plain.label?.hasPrefix("Tracks and ") == true)
  }

  // MARK: Answer 2

  @Test func dryRunVerbFollowsTheKind() {
    let corner = Zone.corner(.bottomRight)
    let slide = EdgyCore.Binding(
      zone: .edge(.right), gesture: .slide, action: BuiltInAction.volume, customName: "Dictate")
    #expect(
      plate(
        .wouldRun(BuiltInAction.volume, zone: .edge(.right), kind: .slide), context: PlateContext(bindings: [slide]),
        dryRun: true)?.title == "Would set Dictate")
    let hold = EdgyCore.Binding(
      zone: corner, gesture: .longPress, action: BuiltInAction.keyboardHold, parameters: ["keys": "fn"],
      customName: "Dictate")
    #expect(
      plate(
        .wouldRun(BuiltInAction.keyboardHold, zone: corner, kind: .longPress), context: PlateContext(bindings: [hold]),
        dryRun: true)?.title == "Would hold Dictate")
    let trigger = EdgyCore.Binding(
      zone: corner, gesture: .doubleTap, action: BuiltInAction.playPause, customName: "Dictate")
    #expect(
      plate(
        .wouldRun(BuiltInAction.playPause, zone: corner, kind: .doubleTap), context: PlateContext(bindings: [trigger]),
        dryRun: true)?.title == "Would run Dictate")
    // Run mode stays verb-less for custom names.
    #expect(
      plate(
        .actionRan(BuiltInAction.playPause, zone: corner, kind: .doubleTap), context: PlateContext(bindings: [trigger]))?
        .title == "Dictate")
  }
}
