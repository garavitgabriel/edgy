import EdgyCore
import Foundation
import Testing

@testable import EdgyRuntime

/// The customization audit: every setting the config holds is reachable through `SettingsEditor`,
/// survives save + reload, and is written up in `docs/settings-reference.md`. Adding a field to
/// `AppSettings` or `GestureSettings` without extending the tables below fails here.
@MainActor
@Suite struct SettingsAuditTests {
  /// Each `AppSettings` field → an edit to a non-default value.
  static let appEdits: [String: (inout AppSettings) -> Void] = [
    "enabled": { $0.enabled = false },
    "showMenuBarIcon": { $0.showMenuBarIcon = false },
    "hud": { $0.hud = .none },
    "haptics": { $0.haptics = false },
    "hapticEvents": { $0.hapticEvents = [.actionFired] },
    "hapticTickStrength": { $0.hapticTickStrength = 2 },
    "hapticClickStrength": { $0.hapticClickStrength = 3 },
    "launchAtLogin": { $0.launchAtLogin = true },
    "unresponsiveDisplays": { $0.unresponsiveDisplays = ["desk-34"] },
    "confirmedDisplays": { $0.confirmedDisplays = ["desk-27"] },
    "displayCheckAsks": { $0.displayCheckAsks = ["desk-34": 1] },
  ]

  /// Each `GestureSettings` field → an edit to a non-default value inside its limits.
  static let gestureEdits: [String: (inout GestureSettings) -> Void] = [
    "edgeWidthMM": { $0.edgeWidthMM = 10 },
    "cornerSizeMM": { $0.cornerSizeMM = 14 },
    "dwellMS": { $0.dwellMS = 200 },
    "palmMajorAxisMM": { $0.palmMajorAxisMM = 20 },
    "typingSuppressionMS": { $0.typingSuppressionMS = 800 },
    "doubleTapWindowMS": { $0.doubleTapWindowMS = 400 },
    "longPressMS": { $0.longPressMS = 700 },
    "fingers": { $0.fingers = 2 },
  ]

  static func labels(_ value: Any) -> Set<String> { Set(Mirror(reflecting: value).children.compactMap(\.label)) }

  static func child(_ label: String, of value: Any) -> String {
    String(describing: Mirror(reflecting: value).children.first { $0.label == label }!.value)
  }

  static let reference: String = {
    let url = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("docs/settings-reference.md")
    return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
  }()

  func reloaded(_ h: EditorHarness) throws -> EdgyConfig {
    try ConfigStore(fileURL: h.store.fileURL, debounce: 0.3, logger: RecordingLogger()).load()
  }

  @Test func everyAppSettingIsListedSettableAndSurvivesReload() throws {
    #expect(Set(Self.appEdits.keys) == Self.labels(AppSettings.defaults))
    for (name, edit) in Self.appEdits {
      let h = try EditorHarness()
      try h.editor.updateAppSettings(edit)
      #expect(Self.child(name, of: h.editor.config.app) != Self.child(name, of: AppSettings.defaults), "\(name)")
      #expect(try reloaded(h) == h.editor.config, "\(name)")
    }
  }

  @Test func everyGestureSettingIsListedSettableAndSurvivesReload() throws {
    #expect(Set(Self.gestureEdits.keys) == Self.labels(GestureSettings.defaults))
    for (name, edit) in Self.gestureEdits {
      let h = try EditorHarness()
      try h.editor.updateGestureSettings(edit)
      #expect(
        Self.child(name, of: h.editor.config.gestures) != Self.child(name, of: GestureSettings.defaults), "\(name)")
      #expect(try reloaded(h) == h.editor.config, "\(name)")
    }
  }

  /// A valid value for every parameter kind that differs from the default. The switch is
  /// exhaustive, so a new kind fails to compile until it has one.
  static func sampleValue(for parameter: ActionParameter) -> String {
    switch parameter.kind {
    case .text: return "Some text"
    case .keyCombo: return "cmd+shift+4"
    case .appBundleID: return "com.example.editor"
    case .url: return "https://example.com/path"
    case .filePath: return "~/Documents"
    case .number(let range): return String(range.upperBound)
    case .choice(let choices): return choices.last { $0 != parameter.defaultValue } ?? choices[0]
    }
  }

  @Test func everyCatalogParameterIsSettableAndSurvivesReload() throws {
    let h = try EditorHarness()
    var zones = (0..<4).map { Zone.edge(.top, segment: $0, segments: 4) }.makeIterator()
    for descriptor in FakeCatalog.descriptors {
      for parameter in descriptor.parameters {
        let gesture: GestureKind = descriptor.shape == .continuous ? .slide : .tap
        let zone = zones.next() ?? .corner(.bottomLeft)
        var parameters = [parameter.key: Self.sampleValue(for: parameter)]
        for other in descriptor.parameters where other.required && other.key != parameter.key {
          parameters[other.key] = Self.sampleValue(for: other)
        }
        let binding = Binding(zone: zone, gesture: gesture, action: descriptor.id, parameters: parameters)
        #expect(h.editor.validate(binding, in: .default).isEmpty, "\(descriptor.id.rawValue).\(parameter.key)")
        try h.editor.setBinding(binding, in: .default)
        #expect(try reloaded(h).defaultProfile.bindings.contains(binding), "\(descriptor.id.rawValue).\(parameter.key)")
        try h.editor.removeBinding(binding.key, from: .default)
      }
    }
    #expect(FakeCatalog.descriptors.flatMap(\.parameters).count >= 8)
  }

  @Test func crossCuttingParametersAreSettableOnEveryBindingShape() throws {
    let h = try EditorHarness()
    #expect(ConfigValidator.crossCuttingParameters == [AppSettings.hapticsParameter, "sensitivity"])
    let slide = Binding(
      zone: .edge(.right), gesture: .slide, action: "audio.volume", parameters: ["haptics": "off", "sensitivity": "2"])
    let tap = Binding(zone: .corner(.bottomLeft), gesture: .tap, action: "audio.mute", parameters: ["haptics": "off"])
    try h.editor.setBinding(slide, in: .default)
    try h.editor.setBinding(tap, in: .default)
    #expect(h.editor.issues.isEmpty)
    let back = try reloaded(h).defaultProfile.bindings
    #expect(back.contains(slide) && back.contains(tap))
  }

  @Test func everyProfileFeatureIsSettableAndSurvivesReload() throws {
    let h = try EditorHarness()
    let app = "com.example.app"
    try h.editor.addAppProfile(bundleID: app)
    try h.editor.overrideBinding(
      Binding(zone: .edge(.right), gesture: .slide, action: "display.brightness"), forApp: app)
    try h.editor.turnOff(BindingKey(zone: .corner(.topRight), gesture: .doubleTap), forApp: app)
    try h.editor.setProfileDisabled(true, for: .app(app))
    try h.editor.addAppProfile(bundleID: "com.example.full", startingAs: .copyOfDefault)
    let back = try reloaded(h)
    #expect(back == h.editor.config)
    #expect(back.appProfiles[app]?.inheritsDefault == true)
    #expect(back.appProfiles[app]?.disabled == true)
    #expect(back.appProfiles[app]?.bindings.contains { $0.action == .doNothing } == true)
    #expect(back.appProfiles["com.example.full"]?.inheritsDefault == false)
  }

  @Test func theReferenceDocumentsEverySettingAndCode() {
    #expect(!Self.reference.isEmpty, "docs/settings-reference.md is missing")
    let names =
      Self.labels(AppSettings.defaults).union(Self.labels(GestureSettings.defaults))
      .union(ConfigValidator.crossCuttingParameters)
      .union(["inheritsDefault", "disabled", "edgy.none"])
      .union(ValidationIssue.Code.allCases.map(\.rawValue))
    for name in names.sorted() {
      #expect(Self.reference.contains("`\(name)`"), "settings-reference.md doesn't mention `\(name)`")
    }
    for method in [
      "updateAppSettings", "updateGestureSettings", "setBinding", "removeBinding", "addAppProfile", "overrideBinding",
      "turnOff", "revertToDefault", "convertToInheriting", "setProfileDisabled", "resetProfile", "resetAll",
      "effectiveBindings", "setTestMode", "observeFeed",
    ] {
      #expect(Self.reference.contains(method), "settings-reference.md doesn't mention \(method)")
    }
  }
}
