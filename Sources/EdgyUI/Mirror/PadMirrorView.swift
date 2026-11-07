import EdgyCore
import EdgyRuntime
import SwiftUI

/// The trackpad mirror: to scale, zone states by shape, joined labels, live touches (BRIEF bones 1–4). Settings window size.
///
/// - Draws the effective bindings of `model.selectedProfile` (Default, or what will actually
///   happen in that app) with the zone geometry of `Gestures.PadLayout` at
///   `Tokens.mirrorPointsPerMM`, from `model.mirroredDevice` (the pad touched last).
/// - Clicking a zone sets `model.selectedZone`. Every zone's drawn frame is published through
///   `PadMirrorView.ZoneAnchor` (`ZoneAnchorKey`) for the picker popover's arrow.
/// - System states on the pad: no trackpad (dashed outline, zones from the last-known size,
///   still editable, "Connect a trackpad to see it here."), off in this app (faded to 40%, every
///   zone a hairline), disabled (faded to 40%). Paused, and the "Edgy is off in <App> · Turn on"
///   line, are drawn by the settings window around the mirror (batch 16 `WindowStatus.padLine`),
///   so the mirror doesn't repeat them (each status is said once).
/// - When the mirrored pad changes, the outline cross-fades over 150 ms.
public struct PadMirrorView: View {
  @Bindable var model: SettingsModel
  @State private var lastKnownSize: Size2D?

  public init(model: SettingsModel) {
    self.model = model
  }

  public var body: some View {
    let app = SettingsModel.app(of: model.selectedProfile)
    let state = model.mirrorState(forApp: app, includesPaused: false)
    let device = model.mirroredDevice
    let sizeMM = device?.sensorSizeMM ?? lastKnownSize ?? MirrorGeometry.defaultSensorSizeMM
    let geometry = MirrorGeometry(
      sensorSizeMM: sizeMM, settings: model.editor.config.gestures, pointsPerMM: Tokens.mirrorPointsPerMM)
    ZStack {
      MirrorPad(
        geometry: geometry, zones: model.mirrorZones(forApp: app), selected: model.selectedZone,
        touches: device == nil ? [] : model.liveTouches, faded: state.faded, dashedOutline: state == .noTrackpad,
        message: Self.message(for: state),
        onSelect: { model.selectZone($0) }
      )
      .id(device?.id)
      .transition(.opacity)
    }
    .animation(.easeInOut(duration: 0.15), value: device?.id)
    .onChange(of: device, initial: true) { _, new in
      if let new { lastKnownSize = new.sensorSizeMM }
    }
    .onAppear { model.startFeed() }
  }

  static func message(for state: MirrorState) -> MirrorMessage? {
    switch state {
    case .noTrackpad: return MirrorMessage(text: MirrorCopy.noTrackpadWindow)
    case .paused, .appOff, .disabled, .normal: return nil
    }
  }
}
