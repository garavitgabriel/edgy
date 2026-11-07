import Actions
import EdgyCore
import EdgyRuntime
import Foundation
import Testing

@testable import EdgyUI

@MainActor @Suite struct InspectorRowTests {
  @Test func rowsAreOnlyTheMappedGestures() {
    let model = InspectorFixtures.model()
    let right = model.inspectorRows(for: .edge(.right))
    #expect(right.map(\.gesture) == [.slide])
    #expect(right.first?.binding.action == "audio.volume")
    let bottom = model.inspectorRows(for: .edge(.bottom))
    #expect(bottom.map(\.gesture) == [.doubleTap, .swipe(.left), .swipe(.right)])
    #expect(model.inspectorRows(for: .corner(.bottomLeft)).isEmpty)
  }

  @Test func zoneAndGestureNames() {
    #expect(ZoneNaming.title(.edge(.right)) == "Right edge")
    #expect(ZoneNaming.title(.edge(.right, segment: 1, segments: 2)) == "Right edge, upper half")
    #expect(ZoneNaming.title(.edge(.bottom, segment: 0, segments: 3)) == "Bottom edge, left third")
    #expect(ZoneNaming.title(.corner(.bottomRight)) == "Bottom-right corner")
    #expect(GestureNaming.pickerHeader(gesture: .tap, zone: .edge(.bottom)) == "Tap, bottom edge")
    #expect(GestureNaming.pickerHeader(gesture: .slide, zone: .edge(.left)) == "Slide, left edge")
  }

  @Test func appTabRowsCarryTheirSource() {
    let model = InspectorFixtures.model()
    model.selectedProfile = .app(PreviewFixtures.wayfare)
    let bottom = model.inspectorRows(for: .edge(.bottom))
    #expect(bottom.first { $0.gesture == .swipe(.left) }?.source == .overridden)
    #expect(bottom.first { $0.gesture == .swipe(.right) }?.source == .inherited)
    #expect(model.inspectorRows(for: .edge(.left)).first?.source == .turnedOff)
    #expect(model.inspectorRows(for: .corner(.bottomRight)).first?.source == .appOnly)
    // Inherited and turned-off rows have no parameter rows; owned rows do.
    #expect(bottom.first { $0.gesture == .swipe(.right) }?.showsParameters == false)
    #expect(bottom.first { $0.gesture == .swipe(.left) }?.showsParameters == true)
  }

  @Test func revertAndTurnOffGoThroughTheEditor() {
    let model = InspectorFixtures.model()
    model.selectedProfile = .app(PreviewFixtures.wayfare)
    let overridden = model.inspectorRows(for: .edge(.bottom)).first { $0.gesture == .swipe(.left) }!
    model.revert(overridden)
    #expect(model.inspectorRows(for: .edge(.bottom)).first { $0.gesture == .swipe(.left) }?.source == .inherited)
    let inherited = model.inspectorRows(for: .edge(.right)).first!
    model.turnOff(inherited)
    #expect(model.inspectorRows(for: .edge(.right)).first?.source == .turnedOff)
    #expect(model.editor.canUndo)
  }

  @Test func addGestureOffersOnlyFreeGestures() {
    let model = InspectorFixtures.model()
    #expect(model.unmappedGestures(for: .edge(.right)) == [.tap, .doubleTap, .longPress, .swipe(.up), .swipe(.down)])
    #expect(model.unmappedGestures(for: .corner(.topRight)) == [.tap, .longPress])
  }
}

@MainActor @Suite struct ChoosingTests {
  @Test func choosingOnDefaultWritesTheBindingAndClosesThePicker() {
    let model = InspectorFixtures.model()
    model.picking = PickerTarget(zone: .edge(.bottom), gesture: .tap)
    model.choose("audio.mute", zone: .edge(.bottom), gesture: .tap)
    #expect(model.picking == nil)
    #expect(
      model.editor.config.defaultProfile.bindings.contains(
        Binding(zone: .edge(.bottom), gesture: .tap, action: "audio.mute")))
  }

  @Test func choosingOnAnAppTabCreatesAnOverride() {
    let model = InspectorFixtures.model()
    model.selectedProfile = .app(PreviewFixtures.wayfare)
    model.choose("audio.mute", zone: .edge(.bottom), gesture: .doubleTap)
    let app = model.editor.config.appProfiles[PreviewFixtures.wayfare]!
    #expect(app.bindings.contains(Binding(zone: .edge(.bottom), gesture: .doubleTap, action: "audio.mute")))
    #expect(model.editor.config.defaultProfile.bindings.contains { $0.action == "media.playPause" })
    #expect(model.inspectorRows(for: .edge(.bottom)).first { $0.gesture == .doubleTap }?.source == .overridden)
  }

  @Test func choosingDefaultsOwnActionOnAnAppTabReverts() {
    let model = InspectorFixtures.model()
    model.selectedProfile = .app(PreviewFixtures.wayfare)
    model.choose("media.previous", zone: .edge(.bottom), gesture: .swipe(.left))
    #expect(model.inspectorRows(for: .edge(.bottom)).first { $0.gesture == .swipe(.left) }?.source == .inherited)
  }

  @Test func doNothingHereTurnsTheGestureOff() {
    let model = InspectorFixtures.model()
    model.selectedProfile = .app(PreviewFixtures.wayfare)
    model.choose(.doNothing, zone: .edge(.right), gesture: .slide)
    #expect(model.inspectorRows(for: .edge(.right)).first?.source == .turnedOff)
  }

  @Test func anActionWithAnEmptyRequiredParameterWaitsAsADraft() {
    let model = InspectorFixtures.model()
    let before = model.editor.config
    model.choose("keyboard.shortcut", zone: .edge(.bottom), gesture: .tap)
    #expect(model.editor.config == before)
    let row = model.inspectorRows(for: .edge(.bottom)).first { $0.gesture == .tap }!
    #expect(row.isDraft)
    #expect(model.needsLabel(row.binding) == "Needs keys")
    #expect(model.inspectorDrafts.focus?.binding == row.id)

    #expect(model.setParameter("keys", to: "cmd+shift+4", in: row) == nil)
    let saved = model.editor.config.defaultProfile.bindings.first { $0.key == row.id }
    #expect(saved?.parameters["keys"] == "cmd+shift+4")
    #expect(model.inspectorDrafts.drafts.isEmpty)
  }

  @Test func needsAnAppForOpenApp() {
    let model = InspectorFixtures.model()
    model.choose("app.open", zone: .corner(.bottomLeft), gesture: .tap)
    let row = model.inspectorRows(for: .corner(.bottomLeft)).first!
    #expect(model.needsLabel(row.binding) == "Needs an app")
  }
}

@MainActor @Suite struct ValidationTests {
  private func urlRow(_ model: SettingsModel) -> InspectorRow {
    model.choose("url.open", zone: .corner(.bottomLeft), gesture: .tap)
    return model.inspectorRows(for: .corner(.bottomLeft)).first!
  }

  @Test func aURLWithoutASchemeIsRefusedUnderTheControl() {
    let model = InspectorFixtures.model()
    let row = urlRow(model)
    let before = model.editor.config
    let issue = model.setParameter("url", to: "example.com", in: row)
    #expect(issue?.code == .invalidURL)
    #expect(IssueCopy.message(for: issue!) == "Needs a scheme, like https://")
    #expect(model.editor.config == before)
    #expect(model.setParameter("url", to: "https://example.com", in: row) == nil)
    #expect(model.editor.config != before)
  }

  @Test func aRelativePathIsRefused() {
    let model = InspectorFixtures.model()
    model.choose("file.open", zone: .corner(.bottomLeft), gesture: .tap)
    let row = model.inspectorRows(for: .corner(.bottomLeft)).first!
    let issue = model.setParameter("path", to: "Documents", in: row)
    #expect(IssueCopy.message(for: issue!) == "Use a full path or start with ~")
  }

  @Test func modifiersAloneOnATriggerAskForAKey() {
    let model = InspectorFixtures.model()
    model.choose("keyboard.shortcut", zone: .corner(.bottomLeft), gesture: .tap)
    let row = model.inspectorRows(for: .corner(.bottomLeft)).first!
    let issue = model.setParameter("keys", to: "fn", in: row)
    #expect(issue?.code == .invalidKeyCombo)
    #expect(IssueCopy.message(for: issue!) == "Add a key. Modifiers alone work only on Hold Keys.")
    // On a hold, modifiers alone are fine.
    model.choose("keyboard.hold", zone: .corner(.bottomLeft), gesture: .longPress)
    let hold = model.inspectorRows(for: .corner(.bottomLeft)).first { $0.gesture == .longPress }!
    #expect(model.setParameter("keys", to: "fn", in: hold) == nil)
  }

  @Test func hapticsCheckboxWritesThePerBindingOverride() {
    let model = InspectorFixtures.model()
    let row = model.inspectorRows(for: .edge(.right)).first!
    model.setParameter(AppSettings.hapticsParameter, to: "off", in: row)
    #expect(model.editor.config.defaultProfile.bindings.first { $0.key == row.id }?.parameters["haptics"] == "off")
    model.setParameter(AppSettings.hapticsParameter, to: nil, in: row)
    #expect(model.editor.config.defaultProfile.bindings.first { $0.key == row.id }?.parameters["haptics"] == nil)
  }

  @Test func parameterRowsFollowTheDescriptor() {
    let catalog = makeLiveActionRegistry(settings: .defaults).available
    func ids(_ id: ActionID) -> [String] {
      ParameterEditor.editors(for: catalog.first { $0.id == id }).map(\.id)
    }
    #expect(ids("audio.volume") == ["sensitivity", "haptics"])
    #expect(ids("app.open") == ["bundleID", "whenFrontmost", "haptics"])
    #expect(ids("media.next") == ["haptics"])
    #expect(ActionNaming.orderedChoices(["stay", "hide"], parameter: "whenFrontmost") == ["hide", "stay"])
    #expect(NumberParameterField.label(1.5, format: .percent) == "150%")
  }

  @Test func issueStylesAreIconAndWording() {
    #expect(IssueCopy.Style(.error).symbol == "xmark.octagon")
    #expect(IssueCopy.Style(.warning).symbol == "exclamationmark.triangle")
    #expect(IssueCopy.Style(.info).symbol == "info.circle")
    let unavailable = ValidationIssue(.warning, .actionUnavailable)
    #expect(
      IssueCopy.message(for: unavailable, availability: .unavailable(reason: "Needs a backlit keyboard"))
        == "Needs a backlit keyboard")
    #expect(
      IssueCopy.overlap(.edge(.right), .edge(.right, segment: 1, segments: 2), gesture: .swipe(.up))
        == "The whole edge and the upper half both use Swipe up.")
  }

  @Test func overlapsAreFoundOnTheEdge() {
    var config = PreviewFixtures.demoConfig
    config.defaultProfile.bindings.append(
      Binding(zone: .edge(.right, segment: 1, segments: 2), gesture: .slide, action: "display.brightness"))
    let model = InspectorFixtures.model(config: config)
    let found = model.overlaps(onEdgeOf: .edge(.right))
    #expect(found.count == 1)
    #expect(found.first?.0 == .edge(.right))
  }
}

@MainActor @Suite struct SplitAndNoteTests {
  @Test func splittingCopiesTheEdgeIntoEachPartAsOneUndoStep() throws {
    let model = InspectorFixtures.model()
    model.selectedZone = .edge(.right)
    model.split(.edge(.right), into: 2)
    let right = model.editor.config.defaultProfile.bindings.filter {
      if case .edge(.right, _, _) = $0.zone { return true }
      return false
    }
    #expect(Set(right.map(\.zone)) == [.edge(.right, segment: 0, segments: 2), .edge(.right, segment: 1, segments: 2)])
    #expect(right.allSatisfy { $0.action == "audio.volume" })
    #expect(model.selectedZone == .edge(.right, segment: 1, segments: 2))
    try model.editor.undo()
    #expect(model.editor.config == PreviewFixtures.demoConfig)
  }

  @Test func mergingKeepsThePartUnderEachCentre() {
    let bindings = [
      Binding(zone: .edge(.left, segment: 0, segments: 2), gesture: .slide, action: "audio.volume"),
      Binding(zone: .edge(.left, segment: 1, segments: 2), gesture: .slide, action: "display.brightness"),
    ]
    #expect(SplitPlan.remap(bindings, edge: .left, to: 1).map(\.action) == ["display.brightness"])
    #expect(
      SplitPlan.remap(bindings, edge: .left, to: 4).map(\.action)
        == ["audio.volume", "audio.volume", "display.brightness", "display.brightness"])
    #expect(
      SplitPlan.selection(after: .edge(.left, segment: 1, segments: 2), segments: 4)
        == .edge(.left, segment: 3, segments: 4))
  }

  @Test func tapWaitsNoteUsesTheRealWindowAndItsFixMovesTheTap() throws {
    var config = InspectorFixtures.configWithBottomTap
    config.gestures.doubleTapWindowMS = 450
    let model = InspectorFixtures.model(config: config)
    let tap = BindingKey(zone: .edge(.bottom), gesture: .tap)
    let note = model.inspectorIssues(for: tap).first { $0.code == .tapWaitsForDoubleTap }
    #expect(note.flatMap { IssueCopy.message(for: $0) } == "Tap waits 450 ms here to tell it from a double-tap.")
    model.useLongPressInstead(for: tap)
    let gestures = model.inspectorRows(for: .edge(.bottom)).map(\.gesture)
    #expect(gestures.contains(.longPress) && !gestures.contains(.tap))
  }
}

@MainActor @Suite struct RecorderTests {
  private func controller(hold: Bool, clock: TestClock, recorder: FakeRecorder = FakeRecorder())
    -> (KeyRecorderController, Box)
  {
    let box = Box()
    let c = KeyRecorderController(recorder: recorder, isHold: hold, now: { clock.now }, commit: { box.combo = $0 })
    return (c, box)
  }

  final class Box { var combo: KeyCombo? }

  @Test func aKeyComboCommits() {
    let clock = TestClock()
    let (c, box) = controller(hold: false, clock: clock)
    c.start()
    c.handle(.listening(held: [.ctrl, .opt]))
    #expect(c.phase == .recording(held: [.ctrl, .opt]))
    c.handle(.recorded(KeyCombo(modifiers: [.ctrl, .opt], key: "space")))
    #expect(c.phase == .idle)
    #expect(box.combo?.description == "ctrl+opt+space")
  }

  @Test func modifiersAloneCommitOnAHoldAfterSixTenths() {
    let clock = TestClock()
    let (c, box) = controller(hold: true, clock: clock)
    c.start()
    c.handle(.listening(held: [.fn]))
    clock.advance(0.7)
    c.handle(.recorded(KeyCombo(modifiers: [.fn])!))
    #expect(box.combo?.description == "fn")
  }

  @Test func aQuickModifierTapOnAHoldKeepsListening() {
    let clock = TestClock()
    let recorder = FakeRecorder()
    let (c, box) = controller(hold: true, clock: clock, recorder: recorder)
    c.start()
    c.handle(.listening(held: [.fn]))
    clock.advance(0.2)
    c.handle(.recorded(KeyCombo(modifiers: [.fn])!))
    #expect(box.combo == nil)
    #expect(c.isRecording)
    #expect(recorder.starts == 2)
  }

  @Test func modifiersAloneOnATriggerShowTheInlineError() {
    let clock = TestClock()
    let (c, box) = controller(hold: false, clock: clock)
    c.start()
    c.handle(.listening(held: [.fn]))
    clock.advance(1)
    c.handle(.recorded(KeyCombo(modifiers: [.fn])!))
    #expect(box.combo == nil)
    #expect(c.error == "Add a key. Modifiers alone work only on Hold Keys.")
    #expect(c.phase == .idle)
  }

  @Test func escCancelsAndCancelStopsTheRecorder() {
    let clock = TestClock()
    let recorder = FakeRecorder()
    let (c, box) = controller(hold: false, clock: clock, recorder: recorder)
    c.start()
    c.handle(.cancelled)
    #expect(c.phase == .idle && box.combo == nil)
    c.start()
    c.cancel()
    #expect(recorder.cancels == 1 && c.phase == .idle)
  }

  @Test func theLiveStreamDrivesTheField() async {
    let clock = TestClock()
    let recorder = FakeRecorder()
    let (c, box) = controller(hold: false, clock: clock, recorder: recorder)
    c.start()
    recorder.send(.listening(held: [.cmd]))
    recorder.send(.recorded(KeyCombo(modifiers: [.cmd, .shift], key: "4")))
    for _ in 0..<50 where box.combo == nil { await Task.yield() }
    #expect(box.combo?.description == "shift+cmd+4")
  }

  @Test func combosShowAsKeySymbols() {
    #expect(KeyComboText.display("ctrl+opt+space") == "⌃⌥ Space")
    #expect(KeyComboText.display("cmd+shift+4") == "⇧⌘ 4")
    #expect(KeyComboText.display("fn") == "fn")
    #expect(KeyComboText.display("ctrl+opt") == "⌃⌥")
    #expect(KeyComboText.display("fn+ctrl+f5") == "fn ⌃ F5")
  }
}
