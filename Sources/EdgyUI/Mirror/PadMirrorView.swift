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
///   still editable), paused, off in this app, disabled (faded to 40%).
/// - When the mirrored pad changes, the outline cross-fades over 150 ms.
public struct PadMirrorView: View {
  @Bindable var model: SettingsModel
  @State private var lastKnownSize: Size2D?

  public init(model: SettingsModel) {
    self.model = model
  }

  public var body: some View {
    let app = SettingsModel.app(of: model.selectedProfile)
    let state = model.mirrorState(forApp: app)
    let device = model.mirroredDevice
    let sizeMM = device?.sensorSizeMM ?? lastKnownSize ?? MirrorGeometry.defaultSensorSizeMM
    let geometry = MirrorGeometry(
      sensorSizeMM: sizeMM, settings: model.editor.config.gestures, pointsPerMM: Tokens.mirrorPointsPerMM)
    ZStack {
      MirrorPad(
        geometry: geometry, zones: model.mirrorZones(forApp: app), selected: model.selectedZone,
        touches: device == nil ? [] : model.liveTouches, faded: state.faded, dashedOutline: state == .noTrackpad,
        message: Self.message(for: state),
        onMessageButton: { model.performMirrorButton(state, app: app) },
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
    case .paused(let line): return MirrorMessage(text: line, button: MirrorCopy.resume)
    case .appOff(let name): return MirrorMessage(text: MirrorCopy.appOff(name), button: MirrorCopy.turnOn)
    case .disabled, .normal: return nil
    }
  }
}
