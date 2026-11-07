import EdgyCore
import EdgyRuntime
import SwiftUI

/// Onboarding layout constants (sizes, not colours, type or radii; those live in `Tokens`).
enum OnboardingMetrics {
  /// The window (BRIEF § Onboarding: "the same 640 × 520 glass window").
  static let windowSize = CGSize(width: 640, height: 520)
  static let sideInset: CGFloat = 32
  /// Room for the window's traffic-light buttons above the step row.
  static let topInset: CGFloat = 40
  static let bottomInset: CGFloat = 24
  static let stepSpacing: CGFloat = 22
  static let stepMarkSize: CGFloat = 22
  static let headlineTop: CGFloat = 26
  static let bodyTop: CGFloat = 8
  /// The one box steps 1 and 2 fit the pad into, so both draw it at the same scale (critique 19
  /// should-fix 1; BRIEF § Onboarding "one scale"). Sized by step 1 (which has a body line) and
  /// step 2 (which keeps room for the rejection plate under the mirror). For a 160 × 115 mm pad it
  /// is 2.0 pt/mm (320 × 230 pt).
  static let mirrorBox = CGSize(width: 360, height: 230)
  /// Step 2's plate slot under the mirror, reserved even when empty so the mirror never jumps.
  static let plateGap: CGFloat = 12
  static let plateSlotHeight: CGFloat = 54
  static let primaryHeight: CGFloat = 50
  static let primaryMinWidth: CGFloat = 140
  static let primaryPadding: CGFloat = 30
  /// Step 3's mini mirrors (BRIEF: "a 120 pt mini mirror").
  static let presetMirrorWidth: CGFloat = 120
  /// Inside each preset row, above and below the mini mirror (critique 19 should-fix 5).
  static let presetRowPadding: CGFloat = 8
  static let presetRowSpacing: CGFloat = 0
  /// Step 3: "You can change any of it in Settings." to Back.
  static let noteGap: CGFloat = 10
  static let radioSize: CGFloat = 18
  static let radioDot: CGFloat = 8
  /// A disabled primary (none today: Continue is always enabled, critique 19 ruling 2).
  static let disabledOpacity = 0.4
  static let pressedOpacity = 0.85
  static let doneWash = 0.1
  static let rowEdgeOpacity = 0.35
}

/// "1 Accessibility (check)  2 Try it  3 Pick a preset  4 Launch at login": done steps take a check mark, the
/// current one is semibold.
struct OnboardingStepRow: View {
  let state: OnboardingState

  var body: some View {
    HStack(spacing: OnboardingMetrics.stepSpacing) {
      ForEach(OnboardingState.Step.allCases, id: \.self) { step in
        item(step)
      }
    }
    .accessibilityElement(children: .combine)
  }

  private func item(_ step: OnboardingState.Step) -> some View {
    let current = step == state.step
    let done = state.isDone(step)
    return HStack(spacing: 8) {
      mark(step, current: current, done: done)
      Text(step.title)
        .font(Tokens.font(Tokens.typeBody, semibold: current))
        .foregroundStyle(current ? Tokens.ink : Tokens.ink2)
    }
  }

  @ViewBuilder
  private func mark(_ step: OnboardingState.Step, current: Bool, done: Bool) -> some View {
    let size = OnboardingMetrics.stepMarkSize
    ZStack {
      if done {
        Circle().fill(Tokens.ink.opacity(OnboardingMetrics.doneWash))
        Image(systemName: "checkmark")
          .font(Tokens.font(Tokens.typeBody, semibold: true))
          .imageScale(.small)
          .foregroundStyle(Tokens.ink)
      } else if current {
        Circle().fill(Tokens.ink)
        Text("\(step.rawValue)")
          .font(Tokens.font(Tokens.typeBody, semibold: true))
          .foregroundStyle(Tokens.windowTint)
      } else {
        Circle().strokeBorder(Tokens.ink2, lineWidth: 1)
        Text("\(step.rawValue)")
          .font(Tokens.font(Tokens.typeBody))
          .foregroundStyle(Tokens.ink2)
      }
    }
    .frame(width: size, height: size)
  }
}

/// The round primary: the only chunky round control in the app (BRIEF § Onboarding, render C).
struct OnboardingPrimaryStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(Tokens.font(Tokens.typeValue, semibold: true))
      .foregroundStyle(Tokens.windowTint)
      .padding(.horizontal, OnboardingMetrics.primaryPadding)
      .frame(minWidth: OnboardingMetrics.primaryMinWidth, minHeight: OnboardingMetrics.primaryHeight)
      .background(Capsule().fill(Tokens.ink))
      .contentShape(Capsule())
      .opacity(
        isEnabled
          ? (configuration.isPressed ? OnboardingMetrics.pressedOpacity : 1) : OnboardingMetrics.disabledOpacity)
  }
}

/// Back / Skip for now: a quiet text button.
struct OnboardingQuietStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(Tokens.font(Tokens.typeBody))
      .foregroundStyle(Tokens.ink2)
      .contentShape(Rectangle())
      .opacity(configuration.isPressed ? OnboardingMetrics.pressedOpacity : 1)
  }
}

/// The live pad on steps 1 and 2: the mirror's own drawing (`MirrorPad`, zones from
/// `PadLayout`), fitted into `OnboardingMetrics.mirrorBox` at the pad's real proportion, the
/// same scale on both steps. `PadMirrorView` draws at the settings window's 3.7 pt/mm, which
/// doesn't fit a 640 × 520 window, and scaling it down would take its labels under 13 pt; drawing
/// the same pad at a fitted scale keeps them at 13.
///
/// - `illustration` (step 1): zone shapes and corner icons only, no label tabs or in-bar text
///   (critique 19 ruling 1; BRIEF § Onboarding).
/// - `onlyTaughtZone` (step 2, render C): only the right edge is drawn as mapped, every other zone
///   as unmapped, so the one thing to try stands out. Presentation only; the config is untouched.
struct OnboardingMirror: View {
  let model: SettingsModel
  var illustration = false
  var onlyTaughtZone = false

  /// The pad's size on screen; one scale for every onboarding mirror.
  static func pointsPerMM(for sizeMM: Size2D) -> CGFloat {
    let box = OnboardingMetrics.mirrorBox
    return min(box.width / sizeMM.width, box.height / sizeMM.height)
  }

  static func sensorSize(_ model: SettingsModel) -> Size2D {
    model.mirroredDevice?.sensorSizeMM ?? model.lastKnownPadSizeMM ?? MirrorGeometry.defaultSensorSizeMM
  }

  var body: some View {
    let state = model.mirrorState(forApp: nil, includesPaused: false)
    let device = model.mirroredDevice
    let sizeMM = Self.sensorSize(model)
    let geometry = MirrorGeometry(
      sensorSizeMM: sizeMM, settings: model.editor.config.gestures, pointsPerMM: Self.pointsPerMM(for: sizeMM))
    MirrorPad(
      geometry: geometry, zones: zones, selected: nil, touches: device == nil ? [] : model.liveTouches,
      faded: state.faded, dashedOutline: state == .noTrackpad, showsLabels: !illustration,
      message: state == .noTrackpad ? MirrorMessage(text: MirrorCopy.noTrackpadWindow) : nil
    )
    .id(device?.id)
    .transition(.opacity)
    .animation(MirrorMotion.padSwitch, value: device?.id)
  }

  private var zones: [MirrorZone] {
    let all = model.mirrorZones(forApp: nil)
    guard onlyTaughtZone else { return all }
    return all.map { zone in
      guard !OnboardingState.isRightEdge(zone.zone) else { return zone }
      var quiet = zone
      quiet.style = .unmapped
      quiet.label = nil
      quiet.symbol = nil
      quiet.overridden = false
      return quiet
    }
  }
}

/// One of step 3's radio rows: radio, the preset's 120 pt mini mirror, name and one line.
struct PresetRow: View {
  let preset: Presets.Preset
  let config: EdgyConfig
  let sensorSizeMM: Size2D?
  let selected: Bool
  let choose: () -> Void

  var body: some View {
    Button(action: choose) {
      HStack(spacing: 16) {
        radio
        PresetMirrorView(config: config, sensorSizeMM: sensorSizeMM, width: OnboardingMetrics.presetMirrorWidth)
        VStack(alignment: .leading, spacing: 2) {
          Text(OnboardingCopy.name(preset))
            .font(Tokens.font(Tokens.typeBody, semibold: true))
            .foregroundStyle(Tokens.ink)
          Text(OnboardingCopy.line(preset))
            .font(Tokens.font(Tokens.typeBody))
            .foregroundStyle(Tokens.ink2)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, OnboardingMetrics.presetRowPadding)
      .background {
        if selected {
          RoundedRectangle(cornerRadius: Tokens.radiusControl)
            .fill(Tokens.windowTint)
            .overlay(
              RoundedRectangle(cornerRadius: Tokens.radiusControl)
                .strokeBorder(Tokens.line.opacity(OnboardingMetrics.rowEdgeOpacity), lineWidth: 1))
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(selected ? [.isSelected] : [])
  }

  private var radio: some View {
    ZStack {
      Circle().strokeBorder(Tokens.ink, lineWidth: 1.5)
      if selected {
        Circle().fill(Tokens.ink).frame(width: OnboardingMetrics.radioDot, height: OnboardingMetrics.radioDot)
      }
    }
    .frame(width: OnboardingMetrics.radioSize, height: OnboardingMetrics.radioSize)
  }
}
