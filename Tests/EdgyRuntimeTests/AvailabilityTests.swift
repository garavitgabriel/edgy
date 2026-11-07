import EdgyCore
import Foundation
import Testing

@testable import EdgyRuntime

/// The fake catalog plus a hold action and the actions `MachineDefaults` substitutes with.
enum MachineCatalog {
  static let hold = ActionDescriptor(id: "keyboard.hold", shape: .hold, displayName: "Hold Keys", category: .keyboard)
  static let switcher = ActionDescriptor(
    id: "apps.switcher", shape: .continuous, displayName: "Switch Apps", category: .apps)
  static let slideSteps = ActionDescriptor(
    id: "keyboard.slideSteps", shape: .continuous, displayName: "Slide to Repeat Keys", category: .keyboard,
    parameters: [
      ActionParameter(key: "upKeys", kind: .keyCombo, required: true, displayName: "Up"),
      ActionParameter(key: "downKeys", kind: .keyCombo, required: true, displayName: "Down"),
    ])
  static let descriptors = FakeCatalog.descriptors + [hold, switcher, slideSteps]

  static let noBrightness: [ActionID: ActionAvailability] = [
    "display.brightness": .unavailable(
      reason: "No built-in display, and the monitor doesn't accept brightness control.")
  ]

  /// An `ActionPerforming` with a settable availability map, so the editor is fed as the app feeds it.
  final class Registry: ActionPerforming {
    var catalog = MachineCatalog.descriptors
    var availabilities: [ActionID: ActionAvailability] = [:]
    private(set) var queries: [ActionID] = []
    var available: [ActionDescriptor] { catalog }
    func perform(_ id: ActionID, input: ActionInput, context: ActionContext) throws {}
    func availability(of id: ActionID) -> ActionAvailability {
      queries.append(id)
      return availabilities[id] ?? .available
    }
  }
}

@Suite struct HoldValidationTests {
  let validator = ConfigValidator(catalog: MachineCatalog.descriptors)

  func codes(_ zone: Zone, _ gesture: GestureKind, _ action: ActionID) -> [ValidationIssue.Code] {
    validator.validate(Binding(zone: zone, gesture: gesture, action: action)).map(\.code)
  }

  @Test func holdFitsLongPressOnly() {
    #expect(codes(.corner(.bottomLeft), .longPress, "keyboard.hold").isEmpty)
    #expect(codes(.edge(.bottom), .longPress, "keyboard.hold").isEmpty)
    for gesture in [GestureKind.tap, .doubleTap, .swipe(.left)] {
      #expect(codes(.edge(.bottom), gesture, "keyboard.hold") == [.shapeMismatch], "\(gesture)")
    }
    #expect(codes(.edge(.left), .slide, "keyboard.hold") == [.shapeMismatch])
  }

  @Test func shapeTableIsThreeWay() {
    for gesture in GestureKind.all {
      #expect(ConfigValidator.shape(.continuous, fits: gesture) == (gesture == .slide))
      #expect(ConfigValidator.shape(.hold, fits: gesture) == (gesture == .longPress))
      #expect(ConfigValidator.shape(.trigger, fits: gesture) == (gesture != .slide))
    }
  }

  @Test func compatibleActionsOfferHoldsOnLongPressOnly() {
    let longPress = validator.compatibleActions(zone: .corner(.topLeft), gesture: .longPress)
    #expect(longPress.contains(MachineCatalog.hold))
    #expect(longPress.allSatisfy { $0.shape == .trigger || $0.shape == .hold })
    #expect(longPress.count == MachineCatalog.descriptors.filter { $0.shape != .continuous }.count)
    let tap = validator.compatibleActions(zone: .corner(.topLeft), gesture: .tap)
    #expect(!tap.contains(MachineCatalog.hold))
    let slide = validator.compatibleActions(zone: .edge(.left), gesture: .slide)
    #expect(!slide.contains(MachineCatalog.hold) && slide.allSatisfy { $0.shape == .continuous })
  }

  @Test func supportedGesturesIncludeLongPressEverywhere() {
    for zone in [Zone.corner(.topRight), .edge(.left), .edge(.bottom, segment: 1, segments: 3)] {
      #expect(ConfigValidator.supportedGestures(for: zone).contains(.longPress))
    }
  }
}

@Suite struct ActionUnavailableTests {
  @Test func unavailableActionIsAWarningNotAnError() {
    let validator = ConfigValidator(catalog: MachineCatalog.descriptors, availability: MachineCatalog.noBrightness)
    let issues = validator.validate(EdgyConfig.defaults)
    #expect(issues.map(\.code) == [.actionUnavailable])
    #expect(issues.first?.severity == .warning)
    #expect(issues.first?.action == "display.brightness")
    #expect(issues.first?.binding == BindingKey(zone: .edge(.left), gesture: .slide))
  }

  @Test func limitedIsNotFlagged() {
    let validator = ConfigValidator(
      catalog: MachineCatalog.descriptors, availability: ["media.next": .limited(reason: "needs a player")])
    #expect(validator.validate(EdgyConfig.defaults).isEmpty)
  }

  @Test func unknownIdsCountAsAvailable() {
    let validator = ConfigValidator(catalog: MachineCatalog.descriptors)
    #expect(validator.availability(of: "audio.volume") == .available)
    #expect(validator.validate(EdgyConfig.defaults).isEmpty)
  }
}

@MainActor @Suite struct EditorAvailabilityTests {
  func editor(_ registry: MachineCatalog.Registry, config: EdgyConfig = .defaults) throws -> SettingsEditor {
    let store = ConfigStore(fileURL: Sample.tempConfigURL(), debounce: 0.3, logger: RecordingLogger())
    try store.save(config)
    return SettingsEditor(
      config: config, catalog: registry.available, store: store, scheduler: FakeScheduler(),
      actions: registry, logger: RecordingLogger(), apply: { _ in })
  }

  @Test func availabilityPassesThroughToTheRegistry() throws {
    let registry = MachineCatalog.Registry()
    registry.availabilities = MachineCatalog.noBrightness
    let editor = try editor(registry)
    #expect(editor.availability(of: "display.brightness") == MachineCatalog.noBrightness["display.brightness"])
    #expect(editor.availability(of: "audio.volume") == .available)
    // Live, not the snapshot: a change in the registry shows at once.
    registry.availabilities = [:]
    #expect(editor.availability(of: "display.brightness") == .available)
  }

  @Test func issuesWarnAboutUnavailableBindingsAndEditsStillWork() throws {
    let registry = MachineCatalog.Registry()
    registry.availabilities = MachineCatalog.noBrightness
    let editor = try editor(registry)
    #expect(editor.issues.map(\.code) == [.actionUnavailable])
    // A warning never blocks: binding brightness elsewhere is allowed.
    try editor.setBinding(Binding(zone: .edge(.right), gesture: .slide, action: "display.brightness"), in: .default)
    #expect(editor.issues.map(\.code) == [.actionUnavailable, .actionUnavailable])
  }

  @Test func refreshAvailabilityPicksUpAHardwareChange() throws {
    let registry = MachineCatalog.Registry()
    let editor = try editor(registry)
    #expect(editor.issues.isEmpty)
    registry.availabilities = MachineCatalog.noBrightness
    editor.refreshAvailability()
    #expect(editor.issues.map(\.code) == [.actionUnavailable])
    registry.availabilities = [:]
    editor.refreshAvailability()
    #expect(editor.issues.isEmpty)
  }

  @Test func editorWithoutAnAvailabilitySourceSeesEverythingAvailable() throws {
    let store = ConfigStore(fileURL: Sample.tempConfigURL(), debounce: 0.3, logger: RecordingLogger())
    let editor = SettingsEditor(
      config: .defaults, catalog: MachineCatalog.descriptors, store: store, scheduler: FakeScheduler(),
      logger: RecordingLogger(), apply: { _ in })
    #expect(editor.availability(of: "display.brightness") == .available)
    #expect(editor.machineDefaults() == .defaults)
  }

  @Test func machineDefaultsThroughTheEditor() throws {
    let registry = MachineCatalog.Registry()
    registry.availabilities = MachineCatalog.noBrightness
    let editor = try editor(registry)
    let defaults = editor.machineDefaults()
    #expect(defaults.defaultProfile.bindings.first { $0.zone == .edge(.left) }?.action == "apps.switcher")
    #expect(editor.validate(defaults).isEmpty)
  }
}

@Suite struct MachineDefaultsTests {
  func build(
    _ availability: [ActionID: ActionAvailability], catalog: [ActionDescriptor] = MachineCatalog.descriptors,
    base: EdgyConfig = .defaults
  ) -> (config: EdgyConfig, substitutions: [MachineDefaults.Substitution]) {
    MachineDefaults.build(from: base, catalog: catalog) { availability[$0] ?? .available }
  }

  func leftEdge(_ config: EdgyConfig) -> Binding? {
    config.defaultProfile.bindings.first { $0.zone == .edge(.left) && $0.gesture == .slide }
  }

  @Test func everythingAvailableKeepsTheDefaults() {
    let result = build([:])
    #expect(result.config == .defaults)
    #expect(result.substitutions.isEmpty)
  }

  @Test func noBrightnessSwapsTheLeftEdgeForTheAppSwitcher() {
    let result = build(MachineCatalog.noBrightness)
    #expect(leftEdge(result.config) == Binding(zone: .edge(.left), gesture: .slide, action: "apps.switcher"))
    // Everything else is untouched, in the same order.
    let others = result.config.defaultProfile.bindings.filter { $0.zone != .edge(.left) }
    #expect(others == EdgyConfig.defaults.defaultProfile.bindings.filter { $0.zone != .edge(.left) })
    #expect(result.config.defaultProfile.bindings.firstIndex { $0.zone == .edge(.left) } == 1)
    #expect(result.substitutions.count == 1)
    #expect(result.substitutions.first?.original.action == "display.brightness")
    #expect(result.substitutions.first?.profile == .default)
    // And the result is clean on this Mac.
    let validator = ConfigValidator(catalog: MachineCatalog.descriptors, availability: MachineCatalog.noBrightness)
    #expect(validator.validate(result.config).isEmpty)
  }

  @Test func withoutTheSwitcherFallsBackToZoomKeys() {
    let result = build(MachineCatalog.noBrightness.merging(["apps.switcher": .unavailable(reason: "x")]) { a, _ in a })
    let binding = leftEdge(result.config)
    #expect(binding?.action == "keyboard.slideSteps")
    #expect(binding?.parameters == ["upKeys": "cmd+equal", "downKeys": "cmd+minus"])
  }

  @Test func alternativeMissingFromTheCatalogIsSkipped() {
    let catalog = MachineCatalog.descriptors.filter { $0.id != "apps.switcher" }
    #expect(leftEdge(build(MachineCatalog.noBrightness, catalog: catalog).config)?.action == "keyboard.slideSteps")
  }

  @Test func noUsableAlternativeDropsTheBinding() {
    let result = build(MachineCatalog.noBrightness, catalog: FakeCatalog.descriptors)
    #expect(leftEdge(result.config) == nil)
    #expect(result.config.defaultProfile.bindings.count == EdgyConfig.defaults.defaultProfile.bindings.count - 1)
    #expect(result.substitutions.first?.replacement == nil)
  }

  @Test func actionsWithNoTableEntryAreDropped() {
    let result = build(["media.playPause": .unavailable(reason: "x"), "mic.mute": .unavailable(reason: "y")])
    let actions = result.config.defaultProfile.bindings.map(\.action)
    #expect(!actions.contains("media.playPause") && !actions.contains("mic.mute"))
    #expect(result.substitutions.map(\.original.action) == ["media.playPause", "mic.mute"])
  }

  @Test func limitedActionsAreKept() {
    #expect(build(["display.brightness": .limited(reason: "external monitor only")]).config == .defaults)
  }

  @Test func appProfilesAreAdjustedToo() {
    var base = EdgyConfig.defaults
    base.appProfiles["com.example.editor"] = Profile(bindings: [
      Binding(zone: .edge(.right), gesture: .slide, action: "display.brightness")
    ])
    let result = build(MachineCatalog.noBrightness, base: base)
    #expect(result.config.appProfiles["com.example.editor"]?.bindings.map(\.action) == ["apps.switcher"])
    #expect(result.substitutions.map(\.profile) == [.default, .app("com.example.editor")])
  }

  @Test func liveRegistryOverload() {
    let registry = MachineCatalog.Registry()
    registry.availabilities = MachineCatalog.noBrightness
    let config = MachineDefaults.build(actions: registry)
    #expect(leftEdge(config)?.action == "apps.switcher")
    #expect(registry.queries.contains("display.brightness"))
  }
}
