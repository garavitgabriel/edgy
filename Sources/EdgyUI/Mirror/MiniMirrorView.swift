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
public struct MiniMirrorView: View {
  @Bindable var model: SettingsModel
  /// The app whose profile is in effect, `nil` = Default. See blockers-batch-14 #1.
  let frontmostApp: String?
  @State private var lastTouches: [LiveTouch] = []
  @State private var lastKnownSize: Size2D?

  public init(model: SettingsModel) {
    self.init(model: model, frontmostApp: nil)
  }

  /// The mini mirror for the profile in effect while `frontmostApp` is in front.
  public init(model: SettingsModel, frontmostApp: String?) {
    self.model = model
    self.frontmostApp = frontmostApp
  }

  public var body: some View {
    let state = model.mirrorState(forApp: frontmostApp)
    let device = model.mirroredDevice
    let sizeMM =
      state == .noTrackpad
      ? MirrorGeometry.defaultSensorSizeMM : device?.sensorSizeMM ?? lastKnownSize ?? MirrorGeometry.defaultSensorSizeMM
    let geometry = MirrorGeometry(
      sensorSizeMM: sizeMM, settings: model.editor.config.gestures, pointsPerMM: Tokens.miniMirrorPointsPerMM)
    ZStack {
      MirrorPad(
        geometry: geometry, zones: model.mirrorZones(forApp: frontmostApp), selected: nil,
        touches: device == nil ? [] : (model.liveTouches.isEmpty ? lastTouches : model.liveTouches),
        faded: state.faded, dashedOutline: state == .noTrackpad, showsLabels: false,
        message: state == .noTrackpad ? MirrorMessage(text: MirrorCopy.noTrackpadMini) : nil
      )
      .id(device?.id)
      .transition(.opacity)
    }
    .animation(.easeInOut(duration: 0.15), value: device?.id)
    .onChange(of: model.liveTouches, initial: true) { _, new in
      if !new.isEmpty { lastTouches = new }
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
