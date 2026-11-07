import EdgyCore
import EdgyRuntime
import Foundation
import SwiftUI
import Testing

@testable import EdgyUI

/// Snapshots for review against `docs/design/final/26F-1TVB-A/B/C/E.png` and `supp/S1, S5, S7`.
/// Written to `docs/design/build-shots/batch-14/<name>-<light|dark>.png`.
@MainActor
@Suite(.serialized)
struct MirrorSnapshotTests {
  static let folder = "batch-14"

  /// The mirror on the window's warm tint, with room for the slab's shadow.
  func frame(_ view: some View) -> some View {
    view.padding(28).background(Tokens.windowTint)
  }

  func shoot(_ view: some View, _ name: String, model: SettingsModel? = nil) throws {
    let urls = try Snapshot.write(frame(view), folder: Self.folder, name: name)
    #expect(urls.count == 2)
    for url in urls {
      let image = try #require(NSImage(contentsOf: url))
      #expect(image.size.width > 100 && image.size.height > 80)
    }
  }

  @Test func defaultIdle() throws {
    try shoot(PadMirrorView(model: PreviewFixtures.model()), "pad-default-idle")
  }

  @Test func rightEdgeSelected() throws {
    let model = PreviewFixtures.model()
    model.selectedZone = .edge(.right)
    try shoot(PadMirrorView(model: model), "pad-right-selected")
  }

  @Test func liveSlideOnRightEdge() throws {
    let model = PreviewFixtures.model()
    model.selectedZone = .edge(.right)
    model.simulate(MirrorFixtures.touch(0.975, 0.68, .claimed))
    try shoot(PadMirrorView(model: model), "pad-live-slide-right")
  }

  @Test func rejectedTouch() throws {
    let model = PreviewFixtures.model()
    model.simulate(MirrorFixtures.touch(0.03, 0.45, .rejected))
    try shoot(PadMirrorView(model: model), "pad-rejected-touch")
  }

  @Test func splitBottomTwoRightThree() throws {
    let model = PreviewFixtures.model(config: MirrorFixtures.splitConfig)
    model.selectedZone = .edge(.right, segment: 2, segments: 3)
    try shoot(PadMirrorView(model: model), "pad-split-bottom2-right3")
  }

  @Test func wayfareTab() throws {
    let model = PreviewFixtures.model()
    model.selectedProfile = .app(PreviewFixtures.wayfare)
    try shoot(PadMirrorView(model: model), "pad-wayfare")
  }

  @Test func huddleOff() throws {
    let model = PreviewFixtures.model()
    model.selectedProfile = .app(PreviewFixtures.huddle)
    try shoot(PadMirrorView(model: model), "pad-huddle-off")
  }

  @Test func noTrackpad() throws {
    let model = PreviewFixtures.model()
    MirrorFixtures.noTrackpad(model)
    try shoot(PadMirrorView(model: model), "pad-no-trackpad")
  }

  @Test func disabled() throws {
    let model = PreviewFixtures.model(config: MirrorFixtures.disabledConfig())
    try shoot(PadMirrorView(model: model), "pad-disabled")
  }

  @Test func builtInPadSize() throws {
    let model = PreviewFixtures.model(device: PreviewFixtures.builtInPad)
    model.simulate(MirrorFixtures.touch(0.5, 0.03, .claimed, device: PreviewFixtures.builtInPad.id))
    try shoot(PadMirrorView(model: model), "pad-built-in")
  }

  @Test func miniIdle() throws {
    try shoot(MiniMirrorView(model: PreviewFixtures.model()), "mini-idle")
  }

  @Test func miniWithLastTouch() throws {
    let model = PreviewFixtures.model()
    model.simulate(MirrorFixtures.touch(0.98, 0.75, .claimed))
    try shoot(MiniMirrorView(model: model), "mini-last-touch")
  }

  @Test func miniNoTrackpad() throws {
    let model = PreviewFixtures.model()
    MirrorFixtures.noTrackpad(model)
    try shoot(MiniMirrorView(model: model), "mini-no-trackpad")
  }

  @Test func miniPaused() throws {
    let model = PreviewFixtures.model()
    MirrorFixtures.paused(model)
    try shoot(MiniMirrorView(model: model), "mini-paused")
  }

  @Test func miniAppOff() throws {
    try shoot(
      MiniMirrorView(model: PreviewFixtures.model(), frontmostApp: PreviewFixtures.huddle), "mini-huddle-off")
  }

  @Test func presetMirrors() throws {
    var minimal = EdgyConfig.defaults
    minimal.defaultProfile.bindings = Array(minimal.defaultProfile.bindings.prefix(2))
    try shoot(
      HStack(spacing: 20) {
        PresetMirrorView(config: .defaults)
        PresetMirrorView(config: minimal)
      }, "preset-media-minimal")
  }
}
