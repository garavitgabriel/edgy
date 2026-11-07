import Actions
import EdgyCore
import EdgyRuntime
import Foundation
import SwiftUI
import Testing

@testable import EdgyUI

/// Every acceptance shot for batch 16, light and dark, into `docs/design/build-shots/batch-16/`.
/// The mirror and inspector are still the skeleton stubs until batches 14 and 15 merge; popover
/// and sheet content is rendered standalone (presentations don't draw headlessly).
@MainActor
struct WindowSnapshotTests {
  static let folder = "batch-16"
  let size = SettingsWindowView.minimumSize

  private func window(
    _ model: SettingsModel, conditions: WindowConditions = .normal, name: String
  ) throws {
    let urls = try Snapshot.write(
      SettingsWindowView(model: model).environment(\.windowConditions, conditions).withExportedAppIcon(),
      folder: Self.folder, name: name,
      size: size)
    #expect(urls.count == 2)
  }

  @Test func windowDefault() throws {
    let model = PreviewFixtures.model()
    model.selectedZone = .edge(.right)
    try window(model, name: "window-default")
  }

  @Test func windowWithPicker() throws {
    let model = PreviewFixtures.model()
    model.selectedZone = .edge(.bottom)
    model.picking = PickerTarget(zone: .edge(.bottom), gesture: .tap)
    try window(model, name: "window-picker")
  }

  @Test func wayfareTab() throws {
    let model = PreviewFixtures.model()
    model.selectProfile(.app(PreviewFixtures.wayfare))
    model.selectedZone = .edge(.bottom)
    try window(model, name: "tab-wayfare")
  }

  @Test func huddleOff() throws {
    let model = PreviewFixtures.model()
    model.selectProfile(.app(PreviewFixtures.huddle))
    try window(model, name: "tab-huddle-off")
  }

  @Test func legacyNote() throws {
    let model = PreviewFixtures.model(config: WindowFixtures.legacyConfig)
    model.selectProfile(.app(WindowFixtures.quillpad))
    model.selectedZone = .edge(.right)
    try window(model, name: "legacy-note")
  }

  @Test func noAccessibility() throws {
    let model = PreviewFixtures.model()
    model.selectedZone = .edge(.right)
    try window(model, conditions: WindowConditions(accessibility: .denied), name: "state-no-accessibility")
  }

  @Test func paused() throws {
    let model = PreviewFixtures.model()
    model.simulate(WindowFixtures.status(paused: true, pausedUntil: Date().addingTimeInterval(47 * 60 + 30)))
    try window(model, name: "state-paused")
  }

  @Test func noTrackpad() throws {
    let model = PreviewFixtures.model()
    model.simulate(WindowFixtures.status(devices: []))
    try window(model, name: "state-no-trackpad")
  }

  @Test func disabled() throws {
    var config = PreviewFixtures.demoConfig
    config.app.enabled = false
    try window(PreviewFixtures.model(config: config), name: "state-disabled")
  }

  @Test func overlappingZones() throws {
    let model = PreviewFixtures.model(config: WindowFixtures.overlapConfig)
    model.selectedZone = .edge(.right)
    try window(model, name: "issue-overlapping-zones")
  }

  @Test func brokenConfig() throws {
    let model = PreviewFixtures.model()
    model.selectedZone = .edge(.right)
    let problem = ConfigProblem(line: 14, message: "expected ',' after a value")
    try window(model, conditions: WindowConditions(configProblem: problem), name: "issue-broken-config")
  }

  @Test func addAppSteps() throws {
    let model = PreviewFixtures.model()
    let apps = FakeApps.list
    try Snapshot.write(
      AddAppView(model: model, apps: apps).background(WindowMaterial()), folder: Self.folder, name: "add-app-step1")
    try Snapshot.write(
      AddAppView(model: model, apps: apps, step: .startFrom(apps[0])).background(WindowMaterial()),
      folder: Self.folder, name: "add-app-step2")
  }

  @Test func advancedSheet() throws {
    try Snapshot.write(AdvancedSettingsView(model: PreviewFixtures.model()), folder: Self.folder, name: "advanced")
    var config = PreviewFixtures.demoConfig
    config.gestures.edgeWidthMM = 90
    try Snapshot.write(
      AdvancedSettingsView(model: PreviewFixtures.model(config: config)), folder: Self.folder,
      name: "advanced-out-of-range")
  }
}
