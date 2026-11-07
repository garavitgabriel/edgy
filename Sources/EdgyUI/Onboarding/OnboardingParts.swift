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
  /// The largest box the live mirror may fill, per step (the pad keeps its real proportion).
  static let tryItMirrorBox = CGSize(width: 440, height: 262)
  static let accessibilityMirrorBox = CGSize(width: 380, height: 214)
  static let primaryHeight: CGFloat = 50
  static let primaryMinWidth: CGFloat = 140
  static let primaryPadding: CGFloat = 30
  /// Step 3's mini mirrors (BRIEF: "a 120 pt mini mirror").
  static let presetMirrorWidth: CGFloat = 120
  static let presetRowPadding: CGFloat = 5
  static let presetRowSpacing: CGFloat = 2
  static let radioSize: CGFloat = 18
  static let radioDot: CGFloat = 8
  static let switchRowWidth: CGFloat = 380
  /// A control that can't be used yet (Continue before the slide).
  static let disabledOpacity = 0.4
  static let pressedOpacity = 0.85
  static let doneWash = 0.1
  static let rowEdgeOpacity = 0.35
}

/// "1 Accessibility ✓  2 Try it  3 Pick a preset  4 Launch at login": done steps take a ✓, the
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
/// `PadLayout`), fitted into the step's box at the pad's real proportion. `PadMirrorView` draws at
/// the settings window's 3.7 pt/mm, which doesn't fit a 640 × 520 window, and scaling it down
/// would take its labels under 13 pt; drawing the same pad at a fitted scale keeps them at 13.
///
/// `onlyTaughtZone` (step 2, render C): only the right edge is drawn as mapped, every other zone
/// as unmapped, so the one thing to try stands out. Presentation only; the config is untouched.
struct OnboardingMirror: View {
  let model: SettingsModel
  let box: CGSize
  var onlyTaughtZone = false

  var body: some View {
    let state = model.mirrorState(forApp: nil, includesPaused: false)
    let device = model.mirroredDevice
    let sizeMM = device?.sensorSizeMM ?? model.lastKnownPadSizeMM ?? MirrorGeometry.defaultSensorSizeMM
    let scale = min(box.width / sizeMM.width, box.height / sizeMM.height)
    let geometry = MirrorGeometry(sensorSizeMM: sizeMM, settings: model.editor.config.gestures, pointsPerMM: scale)
    MirrorPad(
      geometry: geometry, zones: zones, selected: nil, touches: device == nil ? [] : model.liveTouches,
      faded: state.faded, dashedOutline: state == .noTrackpad,
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
        Spacer(minLength: 0)
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
