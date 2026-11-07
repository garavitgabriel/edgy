import EdgyCore
import EdgyRuntime
import Foundation
import SwiftUI
import Testing

@testable import EdgyUI

/// The batch-17 shots (light + dark) in `docs/design/build-shots/batch-17/`.
@MainActor
@Suite struct PopoverSnapshotTests {
  static let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

  private func shot(_ name: String, model: SettingsModel, state: MenuBarState = MenuBarState()) throws {
    state.now = { Self.now }
    if state.accessibility == .unknown { state.accessibility = .granted }
    let view = MenuPopoverView(model: model).environment(state)
    let urls = try Snapshot.write(view, folder: "batch-17", name: name)
    #expect(urls.count == 2)
  }

  @Test func normal() throws {
    try shot("popover-normal", model: PreviewFixtures.model())
  }

  @Test func testModeOn() throws {
    let model = PreviewFixtures.model()
    let state = MenuBarState()
    state.setTestMode(true, model: model)
    try shot("popover-test-mode", model: model, state: state)
  }

  @Test func testModeDontRunActions() throws {
    let model = PreviewFixtures.model()
    let state = MenuBarState()
    state.setTestMode(true, model: model)
    state.setDontRunActions(true, model: model)
    try shot("popover-test-mode-dont-run", model: model, state: state)
  }

  @Test func paused() throws {
    let model = PreviewFixtures.model()
    model.simulate(
      EngineStatus(
        running: true, paused: true, pausedUntil: Self.now.addingTimeInterval(47 * 60 + 20), enabled: true,
        devices: [PreviewFixtures.externalPad]))
    try shot("popover-paused", model: model)
  }

  @Test func noAccessibility() throws {
    let state = MenuBarState()
    state.accessibility = .denied
    try shot("popover-no-accessibility", model: PreviewFixtures.model(), state: state)
  }

  @Test func noTrackpad() throws {
    let model = PreviewFixtures.model()
    model.simulate(EngineStatus(running: true, enabled: true, devices: []))
    try shot("popover-no-trackpad", model: model)
  }

  @Test func disabled() throws {
    let model = PreviewFixtures.model()
    model.setEnabled(false)
    try shot("popover-disabled", model: model)
  }

  @Test func brokenConfig() throws {
    let state = MenuBarState()
    state.configProblem = EdgyUI.ConfigProblem(
      line: 14, message: "Unexpected character 'x' around line 14, column 3")
    try shot("popover-broken-config", model: PreviewFixtures.model(), state: state)
  }

  @Test func appChipLive() throws {
    let state = MenuBarState()
    state.frontmostBundleID = PreviewFixtures.wayfare
    try shot("popover-app-chip-live", model: PreviewFixtures.model(), state: state)
  }
}
