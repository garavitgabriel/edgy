import EdgyCore
import EdgyRuntime
import Foundation
import SwiftUI
import Testing

@testable import EdgyUI

/// Snapshots for review against `docs/design/final/26F-1TVB-C.png` and `supp/26F-SUPP-S6/S7.png`.
/// Written to `docs/design/build-shots/batch-19/<name>-<light|dark>.png` at the window's 640 × 520.
@MainActor
@Suite(.serialized)
struct OnboardingSnapshotTests {
  private func shoot(_ state: OnboardingState, _ name: String) throws {
    try Snapshot.write(
      OnboardingView(model: state.model, state: state), folder: "batch-19", name: name,
      size: OnboardingMetrics.windowSize)
  }

  @Test func step1Accessibility() throws {
    let state = OnboardingState(model: OnboardingFixtures.model())
    state.setAccessibility(.denied)
    try shoot(state, "step1-accessibility")
  }

  @Test func step1Granted() throws {
    let state = OnboardingState(model: OnboardingFixtures.model())
    state.setAccessibility(.granted)
    try shoot(state, "step1-granted")
  }

  @Test func step2TryIt() throws {
    let model = OnboardingFixtures.model()
    let state = OnboardingState(model: model)
    state.setAccessibility(.granted)
    state.primary()
    try shoot(state, "step2-try-it")
  }

  @Test func step2AfterASlide() throws {
    let model = OnboardingFixtures.model()
    let state = OnboardingState(model: model)
    state.setAccessibility(.granted)
    state.primary()
    model.simulate(MirrorFixtures.touch(0.975, 0.62, .claimed))
    state.receive([OnboardingFixtures.rightSlide])
    #expect(state.canContinue)
    try shoot(state, "step2-after-slide")
  }

  @Test(arguments: Presets.Preset.allCases)
  func step3Preset(_ preset: Presets.Preset) throws {
    let state = OnboardingFixtures.state(at: .preset, model: OnboardingFixtures.model())
    state.setAccessibility(.granted)
    state.choose(preset)
    try shoot(state, "step3-\(preset.rawValue)")
  }

  @Test func step4LaunchAtLogin() throws {
    let state = OnboardingFixtures.state(at: .launchAtLogin, model: OnboardingFixtures.model())
    state.setAccessibility(.granted)
    try shoot(state, "step4-launch-at-login")
  }
}
