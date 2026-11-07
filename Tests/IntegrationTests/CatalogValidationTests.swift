import Actions
import EdgyCore
import EdgyRuntime
import Foundation
import Testing

// The real action catalog checked against the settings validator, so the two sides of the
// v0.2 contract (descriptors from Actions, validation in EdgyRuntime) can't drift apart.
// Building the live registry only reads its catalog: construction has no side effects by contract
// (`makeLiveActionRegistry`), and nothing here performs an action.

private let catalog = makeLiveActionRegistry(settings: .defaults).available
private let validator = ConfigValidator(catalog: catalog)

/// A valid value for each parameter kind.
private func sample(_ parameter: ActionParameter) -> String {
  if let value = parameter.defaultValue { return value }
  switch parameter.kind {
  case .text: return "Sample"
  case .keyCombo: return "cmd+shift+4"
  case .appBundleID: return "com.example.app"
  case .url: return "https://example.com"
  case .filePath: return "~/Documents"
  case .number(let range): return String((range.lowerBound + range.upperBound) / 2)
  case .choice(let options): return options.first ?? ""
  }
}

/// A zone + gesture this descriptor's shape can run on.
private func placement(for descriptor: ActionDescriptor) -> (Zone, GestureKind) {
  switch descriptor.shape {
  case .continuous: (.edge(.right), .slide)
  case .trigger: (.corner(.topRight), .doubleTap)
  case .hold: (.corner(.topRight), .longPress)
  }
}

@Test func catalogIdsAreUnique() {
  #expect(Set(catalog.map(\.id)).count == catalog.count)
}

@Test func defaultConfigIsValidAgainstTheRealCatalog() {
  #expect(validator.validate(EdgyConfig.defaults).isEmpty)
}

@Test func everyActionValidatesWithSampleParameters() {
  for descriptor in catalog {
    let (zone, gesture) = placement(for: descriptor)
    let parameters = Dictionary(uniqueKeysWithValues: descriptor.parameters.map { ($0.key, sample($0)) })
    let binding = Binding(zone: zone, gesture: gesture, action: descriptor.id, parameters: parameters)
    let issues = validator.validate(binding)
    #expect(issues.isEmpty, "\(descriptor.id.rawValue): \(issues)")
  }
}

@Test func everyDefaultValuePassesItsOwnKindCheck() {
  for descriptor in catalog {
    for parameter in descriptor.parameters where parameter.defaultValue != nil {
      let (zone, gesture) = placement(for: descriptor)
      let binding = Binding(
        zone: zone, gesture: gesture, action: descriptor.id,
        parameters: Dictionary(uniqueKeysWithValues: descriptor.parameters.map { ($0.key, sample($0)) }))
      #expect(validator.validate(binding).isEmpty, "\(descriptor.id.rawValue).\(parameter.key)")
    }
    for parameter in descriptor.parameters where parameter.required {
      #expect(parameter.defaultValue == nil, "\(descriptor.id.rawValue).\(parameter.key) is required but has a default")
    }
  }
}

@Test func missingRequiredParameterIsReportedForEveryAction() {
  for descriptor in catalog {
    let (zone, gesture) = placement(for: descriptor)
    for required in descriptor.parameters where required.required {
      var parameters = Dictionary(uniqueKeysWithValues: descriptor.parameters.map { ($0.key, sample($0)) })
      parameters[required.key] = nil
      let binding = Binding(zone: zone, gesture: gesture, action: descriptor.id, parameters: parameters)
      let codes = validator.validate(binding).map(\.code)
      #expect(codes.contains(.missingParameter), "\(descriptor.id.rawValue).\(required.key)")
    }
  }
}

@Test func everyActionHasAtLeastOneCompatiblePlacement() {
  for descriptor in catalog {
    let (zone, gesture) = placement(for: descriptor)
    #expect(zone.supports(gesture))
    #expect(
      validator.validate(Binding(zone: zone, gesture: .slide, action: descriptor.id)).map(\.code)
        .contains(.shapeMismatch) == (descriptor.shape != .continuous && descriptor.id != .doNothing))
  }
}

/// The customization audit against the real catalog: every parameter of every action can be set
/// through `SettingsEditor` and comes back from disk unchanged.
@MainActor @Test func everyRealCatalogParameterIsSettableAndSurvivesReload() throws {
  let url = FileManager.default.temporaryDirectory.appendingPathComponent("edgy-\(UUID())/config.json")
  defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
  let store = ConfigStore(fileURL: url, debounce: 0.3, logger: SystemLogger(category: "test"))
  try store.save(.defaults)
  let editor = SettingsEditor(
    config: .defaults, catalog: catalog, store: store, scheduler: MainQueueScheduler(), apply: { _ in })
  for descriptor in catalog where !descriptor.parameters.isEmpty {
    let gesture: GestureKind =
      switch descriptor.shape {
      case .continuous: .slide
      case .hold: .longPress
      case .trigger: .tap
      }
    let parameters = Dictionary(uniqueKeysWithValues: descriptor.parameters.map { ($0.key, sample($0)) })
    let binding = Binding(zone: .edge(.top), gesture: gesture, action: descriptor.id, parameters: parameters)
    try editor.setBinding(binding, in: .default)
    #expect(try store.load().defaultProfile.bindings.contains(binding), "\(descriptor.id.rawValue)")
  }
}
