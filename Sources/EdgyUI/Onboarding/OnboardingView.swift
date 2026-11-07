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
      OnboardingMirror(model: model, box: OnboardingMetrics.accessibilityMirrorBox)
    case .tryIt:
      // The system's own volume indicator carries the level beside the window (bone 8); Edgy
      // draws nothing next to the mirror.
      OnboardingMirror(model: model, box: OnboardingMetrics.tryItMirrorBox, onlyTaughtZone: true)
    case .preset:
      presets
    case .launchAtLogin:
      launchRow
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
      .frame(width: OnboardingMetrics.switchRowWidth)
      .padding(.top, 20)
      Spacer()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var footer: some View {
    HStack(alignment: .bottom) {
      VStack(alignment: .leading, spacing: 18) {
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
