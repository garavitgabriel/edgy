import Actions
import EdgyCore
import EdgyRuntime
import Foundation

@testable import EdgyUI

/// Invented apps for the add-app list (never a real product name). No paths exist on disk, so
/// marks draw the plain outline symbol.
struct FakeApps: InstalledAppsProviding {
  static let list: [InstalledApp] = [
    InstalledApp(
      name: "Quillpad", bundleID: "com.example.quillpad", path: "/nonexistent/Quillpad.app", isRunning: true),
    InstalledApp(name: "Wayfare", bundleID: "com.example.wayfare", path: "/nonexistent/Wayfare.app", isRunning: true),
    InstalledApp(name: "Huddle", bundleID: "com.example.huddle", path: "/nonexistent/Huddle.app", isRunning: false),
    InstalledApp(
      name: "Ledgerly", bundleID: "com.example.ledgerly", path: "/nonexistent/Ledgerly.app", isRunning: false),
    InstalledApp(
      name: "Tidepool", bundleID: "com.example.tidepool", path: "/nonexistent/Tidepool.app", isRunning: false),
  ]

  func installedApps() async -> [InstalledApp] { Self.list }
}

@MainActor
enum WindowFixtures {
  static let quillpad = "com.example.quillpad"

  /// The demo config plus a legacy (full-replace) Quillpad profile.
  static var legacyConfig: EdgyConfig {
    var config = PreviewFixtures.demoConfig
    config.appProfiles[quillpad] = Profile(
      bindings: EdgyConfig.defaults.defaultProfile.bindings, inheritsDefault: false)
    return config
  }

  /// The right edge's slide bound on the whole edge and on its upper half.
  static var overlapConfig: EdgyConfig {
    var config = PreviewFixtures.demoConfig
    config.defaultProfile.bindings.append(
      Binding(zone: .edge(.right, segment: 1, segments: 2), gesture: .slide, action: "display.brightness"))
    return config
  }

  static func status(
    devices: [TouchDeviceInfo] = [PreviewFixtures.externalPad], paused: Bool = false, pausedUntil: Date? = nil,
    testMode: Bool = false
  ) -> EngineStatus {
    EngineStatus(
      running: true, paused: paused, pausedUntil: pausedUntil, enabled: true, devices: devices, testMode: testMode)
  }
}
