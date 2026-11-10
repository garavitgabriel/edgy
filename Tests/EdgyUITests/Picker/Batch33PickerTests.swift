import EdgyCore
import EdgyRuntime
import Testing

@testable import EdgyUI

/// Batch 33, critique 29 design answer 6: a custom name carries only within the same binding.
@MainActor
@Suite(.serialized)
struct Batch33PickerTests {
  static let key = BindingKey(zone: .edge(.bottom), gesture: .tap)

  private func model() -> SettingsModel {
    var config = PreviewFixtures.demoConfig
    config.defaultProfile.bindings.removeAll { $0.key == Self.key }
    config.defaultProfile.bindings.append(
      EdgyCore.Binding(zone: .edge(.bottom), gesture: .tap, action: "audio.mute", customName: "Hush"))
    config.appProfiles[PreviewFixtures.wayfare]?.bindings.removeAll { $0.key == Self.key }
    let model = PreviewFixtures.model(config: config)
    model.selectedProfile = .app(PreviewFixtures.wayfare)
    return model
  }

  private func override(_ model: SettingsModel) -> EdgyCore.Binding? {
    model.editor.config.appProfiles[PreviewFixtures.wayfare]?.bindings.first { $0.key == Self.key }
  }

  @Test func aNewActionOnAnInheritedRowStartsWithoutDefaultsName() throws {
    let model = model()
    let row = try #require(model.inspectorRows(for: .edge(.bottom)).first { $0.id == Self.key })
    #expect(row.source == .inherited)
    #expect(row.binding.customName == "Hush")
    model.choose("media.next", zone: .edge(.bottom), gesture: .tap)
    #expect(override(model)?.action == "media.next")
    // Before critique 29 design answer 6 (no carry from an inherited row):
    // #expect(override(model)?.customName == "Hush")
    #expect(override(model)?.customName == nil)
    // Default keeps its own name.
    #expect(
      model.editor.config.defaultProfile.bindings.first { $0.key == Self.key }?.customName == "Hush")
  }

  @Test func aNameSetOnTheOverrideCarries() throws {
    let model = model()
    model.choose("media.next", zone: .edge(.bottom), gesture: .tap)
    try model.editor.setNameAndIcon(Self.key, in: .app(PreviewFixtures.wayfare), name: "Skip", icon: nil)
    #expect(override(model)?.customName == "Skip")
    model.choose("media.previous", zone: .edge(.bottom), gesture: .tap)
    #expect(override(model)?.action == "media.previous")
    #expect(override(model)?.customName == "Skip")
  }

  @Test func carryIsPure() {
    let old = EdgyCore.Binding(zone: .edge(.bottom), gesture: .tap, action: "audio.mute", customName: "Hush")
    var inherited = EdgyCore.Binding(zone: .edge(.bottom), gesture: .tap, action: "media.next")
    PickerChoice.carry(from: old, oldIsInherited: true, into: &inherited, actionName: "Next Track")
    #expect(inherited.customName == nil)
    var own = EdgyCore.Binding(zone: .edge(.bottom), gesture: .tap, action: "media.next")
    PickerChoice.carry(from: old, into: &own, actionName: "Next Track")
    #expect(own.customName == "Hush")
  }
}
