import AppKit
import EdgyCore
import EdgyRuntime
import SwiftUI

/// The popover's mini mirror: zones of the active profile and the last touch where it landed (bone 10).
///
/// Same drawing as `PadMirrorView` at `Tokens.miniMirrorPointsPerMM`, with no labels and no
/// clicks. It keeps the last frame of touches after the finger lifts, so the last touch stays
/// where it was. States: no trackpad (dashed outline at the default proportion with "No trackpad
/// connected", no zones), paused, disabled, off in the frontmost app (faded to 40%; the popover
/// says the words).
///
/// **Active profile.** `MiniMirrorView(model:)` follows `model.frontmostBundleID` (set by the app
/// on activation, never Edgy's own) and draws `effectiveBindings(forApp:)` for it, which is Default
/// for an app without a profile. `MiniMirrorView(model:frontmostApp:)` pins the app instead (tests,
/// previews, or a host that already knows it). It reads `model.revision`, so edits made in
/// Settings show at once.
public struct MiniMirrorView: View {
  @Bindable var model: SettingsModel
  /// `nil` = follow the frontmost app; `.some(app)` = pinned (`.some(nil)` = Default).
  let pinnedApp: String??
  @State private var lastTouches: [LiveTouch] = []
  @State private var lastKnownSize: Size2D?
  /// The host already fades the mirror for these states (the popover applies its one 40%), so
  /// the mirror doesn't fade again (one fade only).
  var hostFades = false

  /// The same mirror, leaving the 40% fade to the host (the popover).
  func fadedByHost() -> MiniMirrorView {
    var copy = self
    copy.hostFades = true
    return copy
  }

  /// Follows the frontmost app: the mirror shows the profile in effect right now.
  public init(model: SettingsModel) {
    self.model = model
    pinnedApp = nil
  }

  /// The mini mirror for the profile in effect while `frontmostApp` is in front (`nil` = Default).
  public init(model: SettingsModel, frontmostApp: String?) {
    self.model = model
    pinnedApp = .some(frontmostApp)
  }

  /// The last touch where it landed (bone 10): the frame kept after a lift is the last non-empty one.
  static func remembered(after frame: [LiveTouch], previous: [LiveTouch]) -> [LiveTouch] {
    frame.isEmpty ? previous : frame
  }

  /// What the mirror draws: the live fingers, or, once they lift, the last frame where they landed.
  static func shown(live: [LiveTouch], last: [LiveTouch]) -> [LiveTouch] {
    live.isEmpty ? last : live
  }

  /// The app whose profile the mirror draws.
  /// Unpinned, it is `model.frontmostBundleID` (set by the app on activation, never Edgy itself), the
  /// same source the popover chips read, so the mirror and the chips always agree.
  var activeApp: String? { pinnedApp ?? model.frontmostBundleID }

  /// The frontmost app after an activation: Edgy's own activation (opening its window or
  /// popover) keeps the app that was in front before.
  static func frontmost(afterActivating activated: String?, own: String?, previous: String?) -> String? {
    guard let activated, activated != own else { return previous }
    return activated
  }

  public var body: some View {
    let _ = model.revision  // redraw on every settings change, wherever it was made
    let frontmostApp = activeApp
    let state = model.mirrorState(forApp: frontmostApp)
    let device = model.mirroredDevice
    let sizeMM =
      state == .noTrackpad
      ? MirrorGeometry.defaultSensorSizeMM
      : device?.sensorSizeMM ?? model.lastKnownPadSizeMM ?? lastKnownSize ?? MirrorGeometry.defaultSensorSizeMM
    let geometry = MirrorGeometry(
      sensorSizeMM: sizeMM, settings: model.editor.config.gestures, pointsPerMM: Tokens.miniMirrorPointsPerMM)
    ZStack {
      MirrorPad(
        geometry: geometry, zones: model.mirrorZones(forApp: frontmostApp, unavailableAsUnmapped: true), selected: nil,
        touches: device == nil ? [] : Self.shown(live: model.liveTouches, last: lastTouches),
        faded: state.faded && !hostFades, dashedOutline: state == .noTrackpad, showsLabels: false,
        message: state == .noTrackpad ? MirrorMessage(text: MirrorCopy.noTrackpadMini) : nil
      )
      .id(device?.id)
      .transition(.opacity)
    }
    .animation(MirrorMotion.padSwitch, value: device?.id)
    .onChange(of: model.liveTouches, initial: true) { _, new in
      lastTouches = Self.remembered(after: new, previous: lastTouches)
    }
    .onChange(of: device, initial: true) { old, new in
      if let new { lastKnownSize = new.sensorSizeMM }
      if old?.id != new?.id { lastTouches = [] }
    }
  }
}

/// A static mini mirror of a config's Default profile, for onboarding's preset cards (render S7,
/// "a 120 pt mini mirror showing that preset's zones"). Normal zone shapes; no labels, icons,
/// touches or clicks.
public struct PresetMirrorView: View {
  let config: EdgyConfig
  let sensorSizeMM: Size2D
  let width: CGFloat

  public init(config: EdgyConfig, sensorSizeMM: Size2D? = nil, width: CGFloat = 120) {
    self.config = config
    self.sensorSizeMM = sensorSizeMM ?? MirrorGeometry.defaultSensorSizeMM
    self.width = width
  }

  public var body: some View {
    let rows = config.defaultProfile.bindings.filter { $0.action != .doNothing }.map {
      EffectiveBinding(binding: $0, source: .inherited, defaultBinding: $0)
    }
    MirrorPad(
      geometry: MirrorGeometry(
        sensorSizeMM: sensorSizeMM, settings: config.gestures, pointsPerMM: width / sensorSizeMM.width),
      zones: MirrorContent.zones(rows: rows, catalog: [:]), selected: nil, showsLabels: false, showsIcons: false)
  }
}
