import Actions
import EdgyCore
import EdgyRuntime
import Foundation
import SwiftUI
import Testing

@testable import EdgyUI

/// Batch 29 (picker half): Hold Keys first on a long-press, the Apps order with Last App, and a
/// binding's own name and icon kept when the picker changes its action. Shots in
/// `docs/design/build-shots/batch-29/`, light and dark.
@MainActor
@Suite(.serialized)
struct Batch29PickerTests {
  static let folder = "batch-29"

  /// Last App until batch 32 puts it in the real catalog (then the real one is used as is).
  static let lastApp = ActionDescriptor(id: "app.last", shape: .trigger, displayName: "Last App", category: .apps)

  /// The real catalog plus the Last App fixture (only if the catalog doesn't have it yet).
  static var catalog: [ActionDescriptor] {
    let real = makeLiveActionRegistry(settings: .defaults).available
    return real.contains { $0.id == lastApp.id } ? real : real + [lastApp]
  }

  /// `PreviewFixtures.model()`, but with the Last App fixture in its catalog.
  private func model(config: EdgyConfig = PreviewFixtures.demoConfig) -> SettingsModel {
    let editor = SettingsEditor(
      config: config, catalog: Self.catalog, store: MemoryStore(config), scheduler: ImmediateScheduler(),
      apply: { _ in })
    let model = SettingsModel(editor: editor, engine: nil, devices: [PreviewFixtures.externalPad])
    model.simulate(
      EngineStatus(
        running: true, paused: false, pausedUntil: nil, enabled: true, devices: [PreviewFixtures.externalPad]))
    return model
  }

  private func catalog(_ model: SettingsModel, _ gesture: GestureKind, query: String = "") -> PickerCatalog {
    PickerCatalog(
      groups: model.mirrorGroups, gesture: gesture, query: query, isAppTab: false, availability: { _ in .available })
  }

  private func picker(_ model: SettingsModel, _ name: String, query: String = "", height: CGFloat) throws {
    let view = ActionPickerView(model: model, query: query)
      .frame(width: PickerPlacement.width, height: height, alignment: .topLeading)
      .background(Tokens.windowTint)
    #expect(try Snapshot.write(view, folder: Self.folder, name: name).count == 2)
  }

  // MARK: 4. Hold Keys first on a long-press

  @Test func longPressPutsKeyboardFirstWithHoldKeysFirst() throws {
    let model = PreviewFixtures.model()
    let hold = catalog(model, .longPress)
    #expect(hold.sections.first?.category == .keyboard)
    #expect(hold.sections.dropFirst().first?.category == .sound)
    #expect(hold.sections.first?.items.first?.id == "keyboard.hold")
    #expect(hold.selectable.first?.id == "keyboard.hold")
    // The rest keep catalog order after it.
    let rest = hold.sections.dropFirst().map(\.title)
    let full = ["Sound", "Display", "Media", "System", "Windows", "Apps", "Shortcuts"]
    #expect(rest == full.filter(rest.contains))
    // A search keeps the long-press order.
    let searched = catalog(model, .longPress, query: "key")
    #expect(searched.sections.first?.category == .keyboard)
    #expect(searched.sections.first?.items.first?.id == "keyboard.hold")

    model.selectedZone = .corner(.bottomRight)
    model.picking = PickerTarget(zone: .corner(.bottomRight), gesture: .longPress)
    try picker(model, "picker-long-press-order", height: 420)
  }

  @Test func otherGesturesKeepCatalogOrder() {
    let model = PreviewFixtures.model()
    let full = ["Sound", "Display", "Media", "System", "Windows", "Apps", "Keyboard", "Shortcuts"]
    for gesture in [GestureKind.tap, .doubleTap, .slide, .swipe(.up)] {
      let order = catalog(model, gesture).sections.map(\.title)
      #expect(order == full.filter(order.contains), "\(gesture)")
      #expect(order.first == "Sound", "\(gesture)")
    }
    // Hold Keys stays last in Keyboard everywhere else (icon-table order).
    let keyboard = PickerCatalog.ordered(
      model.mirrorGroups.first { $0.category == .keyboard }?.actions ?? [], for: .tap)
    #expect(keyboard.last?.id == "keyboard.hold")
    // On a tap it is in the disclosure, sub-line and all.
    let tap = catalog(model, .tap)
    #expect(
      tap.others.first { $0.id == "keyboard.hold" }?.subtitle == "Hold any app's shortcut while your finger rests")
  }

  // MARK: 9. Apps order and Last App

  @Test func appsOrderPutsLastAppSecond() throws {
    let model = model()
    let apps = try #require(model.mirrorGroups.first { $0.category == .apps })
    #expect(
      PickerCatalog.ordered(apps.actions).map(\.id) == [
        "app.open", "app.last", "apps.switcher", "url.open", "file.open",
      ])
    // A tap lists the trigger ones in that order (Switch Apps needs a slide).
    let tap = try #require(catalog(model, .tap).sections.first { $0.category == .apps })
    #expect(tap.items.map(\.id) == ["app.open", "app.last", "url.open", "file.open"])

    model.selectedZone = .edge(.bottom)
    model.picking = PickerTarget(zone: .edge(.bottom), gesture: .tap)
    try picker(model, "picker-apps-last-app", query: "app", height: 300)
  }

  @Test func lastAppHasNoSubLine() throws {
    let model = model()
    let last = try #require(catalog(model, .tap).selectable.first { $0.id == "app.last" })
    #expect(last.subtitle == nil)
    #expect(last.title == "Last App")
    #expect(!last.isDimmed)
  }

  @Test func searchFindsLastAppByWhatItDoes() {
    let model = model()
    for query in ["back", "previous", "return", "toggle", "Back", "last"] {
      #expect(catalog(model, .tap, query: query).selectable.contains { $0.id == "app.last" }, "\(query)")
    }
    #expect(!catalog(model, .tap, query: "volume").selectable.contains { $0.id == "app.last" })
  }

  // MARK: 3. Own name and icon kept when the action changes

  private func named(_ action: ActionID, icon: ActionID? = "media.next") -> EdgyConfig {
    var config = PreviewFixtures.demoConfig
    config.defaultProfile.bindings.removeAll { $0.key == BindingKey(zone: .edge(.bottom), gesture: .tap) }
    config.defaultProfile.bindings.append(
      EdgyCore.Binding(zone: .edge(.bottom), gesture: .tap, action: action, customName: "Hush", customIcon: icon))
    return config
  }

  private func bottomTap(_ model: SettingsModel) -> EdgyCore.Binding? {
    model.editor.config.defaultProfile.bindings.first { $0.key == BindingKey(zone: .edge(.bottom), gesture: .tap) }
  }

  @Test func customNameAndIconKeptOnActionChange() throws {
    let model = model(config: named("audio.mute"))
    model.picking = PickerTarget(zone: .edge(.bottom), gesture: .tap)
    model.choose("media.playPause", zone: .edge(.bottom), gesture: .tap)
    #expect(bottomTap(model)?.action == "media.playPause")
    #expect(bottomTap(model)?.customName == "Hush")
    #expect(bottomTap(model)?.customIcon == "media.next")
    #expect(model.picking == nil)
    // One undo step brings the old binding back whole.
    #expect(try model.editor.undo())
    #expect(
      bottomTap(model)
        == EdgyCore.Binding(
          zone: .edge(.bottom), gesture: .tap, action: "audio.mute", customName: "Hush", customIcon: "media.next"))
  }

  @Test func customIconDropsWhenItIsTheNewActionsOwn() {
    let model = model(config: named("audio.mute"))
    model.choose("media.next", zone: .edge(.bottom), gesture: .tap)
    #expect(bottomTap(model)?.customName == "Hush")
    #expect(bottomTap(model)?.customIcon == nil)
  }

  @Test func aNameEqualToTheNewActionsOwnDrops() {
    var config = named("audio.mute", icon: nil)
    config.defaultProfile.bindings[config.defaultProfile.bindings.count - 1].customName = "Play/Pause"
    let model = model(config: config)
    model.choose("media.playPause", zone: .edge(.bottom), gesture: .tap)
    #expect(bottomTap(model)?.customName == nil)
  }

  @Test func aDraftCarriesTheNameUntilItsParameterIsSet() throws {
    let model = model(config: named("audio.mute"))
    model.choose("app.open", zone: .edge(.bottom), gesture: .tap)
    let row = try #require(model.inspectorRows(for: .edge(.bottom)).first { $0.gesture == .tap })
    #expect(row.isDraft && row.binding.customName == "Hush" && row.binding.customIcon == "media.next")
    let app = try #require(
      model.editor.validator.descriptor(for: "app.open")?.parameters.first { $0.required })
    model.setParameter(app.key, to: "com.example.wayfare", in: row)
    #expect(bottomTap(model)?.action == "app.open")
    #expect(bottomTap(model)?.customName == "Hush")
  }

  @Test func doNothingCarriesNothing() {
    var binding = EdgyCore.Binding(zone: .edge(.bottom), gesture: .tap, action: .doNothing)
    let old = EdgyCore.Binding(zone: .edge(.bottom), gesture: .tap, action: "audio.mute", customName: "Hush")
    PickerChoice.carry(from: old, into: &binding, actionName: "Do nothing")
    #expect(binding.customName == nil && binding.customIcon == nil)
    var fromOff = EdgyCore.Binding(zone: .edge(.bottom), gesture: .tap, action: "audio.mute")
    PickerChoice.carry(from: old, oldIsTurnedOff: true, into: &fromOff, actionName: "Mute")
    #expect(fromOff.customName == nil)
  }

  @Test func pickerRowsShowRealNames() throws {
    let model = model(config: named("audio.mute"))
    let mute = try #require(catalog(model, .tap).selectable.first { $0.id == "audio.mute" })
    #expect(mute.title == "Mute")
    #expect(!catalog(model, .tap).selectable.contains { $0.title == "Hush" })
  }
}
