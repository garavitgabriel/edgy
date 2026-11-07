import EdgyCore
import EdgyRuntime
import SwiftUI

/// The four-step onboarding (§ Surfaces C, § Onboarding steps): the 640 × 520 glass window's
/// content. A step row, one 26 pt headline (one clause, no colon), at most one body sentence, the
/// round primary at the bottom right and a quiet text button at the bottom left.
///
/// `OnboardingView(model:)` keeps its own `OnboardingState` (previews); the controller passes
/// its state with `OnboardingView(model:state:)` so it can feed the permission and finish.
public struct OnboardingView: View {
  @Bindable var model: SettingsModel
  @State private var state: OnboardingState

  public init(model: SettingsModel) {
    self.init(model: model, state: OnboardingState(model: model))
  }

  public init(model: SettingsModel, state: OnboardingState) {
    self.model = model
    _state = State(initialValue: state)
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      OnboardingStepRow(state: state)
        .padding(.top, OnboardingMetrics.topInset)
      Text(headline)
        .font(Tokens.font(Tokens.typeTitle, semibold: true))
        .foregroundStyle(Tokens.ink)
        .padding(.top, OnboardingMetrics.headlineTop)
        .accessibilityAddTraits(.isHeader)
      if let body = bodyText {
        Text(body)
          .font(Tokens.font(Tokens.typeBody))
          .foregroundStyle(Tokens.ink2)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, OnboardingMetrics.bodyTop)
      }
      content
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      footer
        .padding(.bottom, OnboardingMetrics.bottomInset)
    }
    .padding(.horizontal, OnboardingMetrics.sideInset)
    .frame(width: OnboardingMetrics.windowSize.width, height: OnboardingMetrics.windowSize.height)
    .background(WindowMaterial())
    .onAppear { state.start() }
  }

  // MARK: Per step

  private var headline: String {
    switch state.step {
    case .accessibility: return OnboardingCopy.accessibilityHeadline
    case .tryIt: return OnboardingCopy.tryItHeadline
    case .preset: return OnboardingCopy.presetHeadline
    case .launchAtLogin: return OnboardingCopy.launchHeadline
    }
  }

  private var bodyText: String? {
    guard state.step == .accessibility else { return nil }
    return state.isAccessibilityGranted ? OnboardingCopy.accessibilityGranted : OnboardingCopy.accessibilityBody
  }

  @ViewBuilder
  private var content: some View {
    switch state.step {
    case .accessibility:
      OnboardingMirror(model: model, illustration: true)
    case .tryIt:
      tryIt
    case .preset:
      presets
    case .launchAtLogin:
      launchRow
    }
  }

  /// The mirror and, under it, the plate slot. A landed slide draws nothing here: the system's
  /// own volume indicator carries the level wherever the system puts it (bone 8, ruling 4). A
  /// rejected touch shows the one dark plate (bone 9, ruling 3): the struck contact on the mirror
  /// and "Ignored: …" under it, centred on the mirror (critique 24, design answer 2). The slot is
  /// always reserved, so the mirror never moves.
  private var tryIt: some View {
    VStack(alignment: .center, spacing: OnboardingMetrics.plateGap) {
      OnboardingMirror(model: model, onlyTaughtZone: true)
      // A zero-width slot on the mirror's centre line: the plate (wider than the mirror) hangs
      // centred from it without widening the stack, so the mirror never moves when a plate appears.
      Color.clear
        .frame(width: 0, height: OnboardingMetrics.plateSlotHeight)
        .overlay(alignment: .top) {
          if let plate = state.rejection {
            PlateView(plate)
              .fixedSize()
              .transition(.opacity)
          }
        }
        .animation(OnboardingMotion.plate, value: state.rejection)
    }
  }

  private var presets: some View {
    let size = model.mirroredDevice?.sensorSizeMM ?? model.lastKnownPadSizeMM
    return VStack(spacing: OnboardingMetrics.presetRowSpacing) {
      ForEach(Presets.Preset.allCases, id: \.self) { preset in
        PresetRow(
          preset: preset, config: model.editor.machineDefaults(from: preset.config), sensorSizeMM: size,
          selected: state.preset == preset, choose: { state.choose(preset) })
      }
    }
    .padding(.horizontal, -14)
  }

  private var launchRow: some View {
    VStack {
      HStack {
        Text(OnboardingCopy.launchSwitch)
          .font(Tokens.font(Tokens.typeBody))
          .foregroundStyle(Tokens.ink)
        Spacer()
        Toggle(OnboardingCopy.launchSwitch, isOn: $state.launchAtLogin)
          .toggleStyle(.switch)
          .labelsHidden()
          .tint(Tokens.accent)
      }
      // Full width: the switch's right edge lines up with Done's (critique 19 should-fix 4).
      .frame(maxWidth: .infinity)
      .padding(.top, 20)
      Spacer()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var footer: some View {
    HStack(alignment: .bottom) {
      VStack(alignment: .leading, spacing: OnboardingMetrics.noteGap) {
        if state.step == .preset {
          Text(OnboardingCopy.presetNote)
            .font(Tokens.font(Tokens.typeBody))
            .foregroundStyle(Tokens.ink2)
        }
        if let quiet = state.quietTitle {
          Button(quiet) { state.quiet() }
            .buttonStyle(OnboardingQuietStyle())
            .padding(.bottom, 16)
        }
      }
      Spacer()
      Button(state.primaryTitle) { state.primary() }
        .buttonStyle(OnboardingPrimaryStyle())
        .disabled(!state.canContinue)
        .keyboardShortcut(.defaultAction)
    }
  }
}

/// Onboarding's one animation: the step-2 plate's fade (the overlay's 200 ms).
enum OnboardingMotion {
  static let plate = Animation.easeOut(duration: 0.2)
}
