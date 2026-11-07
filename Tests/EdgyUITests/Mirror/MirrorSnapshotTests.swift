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

  /// A long label in a quarter of the bottom edge truncates inside its bar instead of running on.
  @Test func longLabelInASplitBarTruncates() throws {
    var config = EdgyConfig.defaults
    config.defaultProfile.bindings.removeAll { $0.zone == .edge(.bottom) }
    let part = Zone.edge(.bottom, segment: 1, segments: 4)
    config.defaultProfile.bindings += [
      Binding(zone: part, gesture: .swipe(.left), action: "keyboard.shortcut", parameters: ["keys": "cmd+left"]),
      Binding(zone: part, gesture: .swipe(.right), action: "media.next"),
      Binding(zone: part, gesture: .doubleTap, action: "media.playPause"),
    ]
    try shoot(PadMirrorView(model: PreviewFixtures.model(config: config)), "pad-split-bottom4-long-label")
  }

  /// Render B's state: the window with the picker open on the bottom edge, anchored to the
  /// mirror's bar through `.pickerAnchor(for:)`.
  @Test func windowWithPickerOnBottomEdge() throws {
    let model = PreviewFixtures.model()
    model.selectedZone = .edge(.bottom)
    model.picking = PickerTarget(zone: .edge(.bottom), gesture: .tap)
    let urls = try Snapshot.write(
      SettingsWindowView(model: model).withExportedAppIcon(), folder: Self.folder, name: "window-picker-bottom",
      size: SettingsWindowView.minimumSize)
    #expect(urls.count == 2)
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

  /// The popover while Wayfare is in front: its effective zones (app-only hold corner, left edge off).
  @Test func miniActiveAppProfile() throws {
    let model = PreviewFixtures.model()
    model.simulate(MirrorFixtures.touch(0.97, 0.05, .claimed))
    try shoot(MiniMirrorView(model: model, frontmostApp: PreviewFixtures.wayfare), "mini-wayfare-active")
  }

  /// Two pads attached: a touch on the built-in pad switches the mirror's outline to its proportions.
  @Test func padSwitchedToBuiltIn() throws {
    let model = PreviewFixtures.model()
    model.simulate(
      EngineStatus(running: true, enabled: true, devices: [PreviewFixtures.externalPad, PreviewFixtures.builtInPad]))
    model.simulate(MirrorFixtures.touch(0.97, 0.5, .claimed, device: PreviewFixtures.builtInPad.id))
    try shoot(PadMirrorView(model: model), "pad-switched-to-built-in")
  }

  /// Render C's state (onboarding step 2, "Try it"): only the right edge is mapped, a finger
  /// slides on it.
  @Test func tryItRightSlide() throws {
    var config = EdgyConfig.defaults
    config.defaultProfile.bindings = [Binding(zone: .edge(.right), gesture: .slide, action: "audio.volume")]
    let model = PreviewFixtures.model(config: config)
    model.simulate(MirrorFixtures.touch(0.975, 0.42, .claimed))
    try shoot(PadMirrorView(model: model), "pad-try-it-right-slide")
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
