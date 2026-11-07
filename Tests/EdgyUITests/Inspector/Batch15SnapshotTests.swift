import Actions
import EdgyCore
import EdgyRuntime
import SwiftUI
import Testing

@testable import EdgyUI

/// Every batch 15 acceptance shot, light + dark, into `docs/design/build-shots/batch-15/`.
@MainActor @Suite(.serialized) struct Batch15SnapshotTests {
  static let folder = "batch-15"
  static let inspectorSize = CGSize(width: 460, height: 600)

  private func inspector(_ model: SettingsModel, size: CGSize = inspectorSize) -> some View {
    InspectorView(model: model).frame(width: size.width, height: size.height).background(Tokens.windowTint)
  }

  private func panel<V: View>(_ view: V, width: CGFloat = 400) -> some View {
    view.padding(16).frame(width: width, alignment: .leading).background(Tokens.windowTint)
  }

  private func write<V: View>(_ view: V, _ name: String, size: CGSize? = nil) throws {
    let urls = try Snapshot.write(view, folder: Self.folder, name: name, size: size)
    #expect(urls.count == 2)
  }

  // MARK: Inspector

  @Test func inspectorRightEdge() throws {
    let model = InspectorFixtures.model()
    model.selectedZone = .edge(.right)
    try write(inspector(model), "inspector-right-edge", size: Self.inspectorSize)
  }

  @Test func inspectorBottomEdgeWithTheNote() throws {
    let model = InspectorFixtures.model(config: InspectorFixtures.configWithBottomTap)
    model.selectedZone = .edge(.bottom)
    try write(
      inspector(model, size: CGSize(width: 460, height: 760)), "inspector-bottom-edge-note",
      size: CGSize(width: 460, height: 760))
  }

  @Test func inspectorRowWhilePicking() throws {
    let model = InspectorFixtures.model(config: InspectorFixtures.configWithBottomTap)
    model.selectedZone = .edge(.bottom)
    model.picking = PickerTarget(zone: .edge(.bottom), gesture: .tap)
    try write(
      inspector(model, size: CGSize(width: 460, height: 760)), "inspector-bottom-edge-picking",
      size: CGSize(width: 460, height: 760))
  }

  @Test func inspectorWayfareEachSource() throws {
    var config = PreviewFixtures.demoConfig
    var wayfare = config.appProfiles[PreviewFixtures.wayfare]!
    wayfare.bindings.append(Binding(zone: .edge(.bottom), gesture: .doubleTap, action: .doNothing))
    wayfare.bindings.append(Binding(zone: .edge(.bottom), gesture: .longPress, action: "system.showDesktop"))
    config.appProfiles[PreviewFixtures.wayfare] = wayfare
    let model = InspectorFixtures.model(config: config)
    model.selectedProfile = .app(PreviewFixtures.wayfare)
    model.selectedZone = .edge(.bottom)
    let size = CGSize(width: 460, height: 820)
    try write(inspector(model, size: size), "inspector-wayfare-sources", size: size)
  }

  @Test func inspectorNeedsKeysAndOpenApp() throws {
    let model = InspectorFixtures.model(apps: InspectorFixtures.apps)
    model.selectedZone = .corner(.bottomRight)
    model.choose("keyboard.hold", zone: .corner(.bottomRight), gesture: .longPress)
    try model.editor.setBinding(
      Binding(
        zone: .corner(.bottomRight), gesture: .doubleTap, action: "app.open",
        parameters: ["bundleID": "com.example.quillpad"]), in: .default)
    model.inspectorDrafts.focus = nil
    try write(inspector(model), "inspector-corner-needs-keys", size: Self.inspectorSize)
  }

  @Test func inspectorSplitOverlap() throws {
    var config = PreviewFixtures.demoConfig
    config.defaultProfile.bindings.append(
      Binding(zone: .edge(.right, segment: 1, segments: 2), gesture: .slide, action: "display.brightness"))
    let model = InspectorFixtures.model(config: config)
    model.selectedZone = .edge(.right, segment: 1, segments: 2)
    try write(inspector(model), "inspector-overlap-warning", size: Self.inspectorSize)
  }

  @Test func inspectorUnavailableActionWarning() throws {
    var config = PreviewFixtures.demoConfig
    config.defaultProfile.bindings.append(
      Binding(zone: .corner(.bottomLeft), gesture: .tap, action: "keyboard.backlightToggle"))
    let model = InspectorFixtures.model(config: config)
    model.selectedZone = .corner(.bottomLeft)
    try write(inspector(model), "inspector-unavailable-warning", size: Self.inspectorSize)
  }

  // MARK: Picker

  private func picker(_ model: SettingsModel, query: String = "", showOthers: Bool = false, height: CGFloat)
    -> some View
  {
    ActionPickerView(model: model, query: query, showOthers: showOthers)
      .frame(width: PickerPlacement.width, height: height)
      .background(Tokens.windowTint)
  }

  @Test func pickerTapBottomEdge() throws {
    let model = InspectorFixtures.model(config: InspectorFixtures.configWithBottomTap)
    model.picking = PickerTarget(zone: .edge(.bottom), gesture: .tap)
    try write(picker(model, height: 420), "picker-tap-bottom-edge", size: CGSize(width: 320, height: 420))
    // The whole list, to show the end: the "need a slide" disclosure, expanded.
    try write(
      picker(model, showOthers: true, height: 1500), "picker-tap-bottom-edge-full",
      size: CGSize(width: 320, height: 1500))
  }

  @Test func pickerSearched() throws {
    let model = InspectorFixtures.model()
    model.picking = PickerTarget(zone: .edge(.bottom), gesture: .tap)
    try write(picker(model, query: "key", height: 420), "picker-searched", size: CGSize(width: 320, height: 420))
  }

  @Test func pickerAppTabDoNothing() throws {
    let model = InspectorFixtures.model()
    model.selectedProfile = .app(PreviewFixtures.wayfare)
    model.picking = PickerTarget(zone: .edge(.top), gesture: .swipe(.left))
    // Empty search and the whole list, so the end shows: the disclosure, the separator, then
    // "Do nothing here" (batch-15 must-fix 3).
    try write(
      picker(model, height: 1600), "picker-app-tab-do-nothing", size: CGSize(width: 320, height: 1600))
  }

  @Test func pickerAddGesture() throws {
    let model = InspectorFixtures.model()
    model.picking = PickerTarget(zone: .edge(.right), gesture: nil)
    try write(picker(model, height: 260), "picker-add-gesture", size: CGSize(width: 320, height: 260))
  }

  /// Anchored to a placeholder mirror (batch 14's mirror publishes the same anchors).
  @Test func pickerAnchoredToItsZone() throws {
    for (name, target) in [
      ("picker-anchored-bottom", PickerTarget(zone: .edge(.bottom), gesture: .tap)),
      ("picker-anchored-right", PickerTarget(zone: .edge(.right), gesture: .slide)),
    ] {
      let model = InspectorFixtures.model(config: InspectorFixtures.configWithBottomTap)
      model.picking = target
      let size = CGSize(width: 860, height: 560)
      try write(
        PlaceholderMirror().actionPickerHost(model: model).frame(width: size.width, height: size.height), name,
        size: size)
    }
  }

  // MARK: Parameter editors

  private func recorder(_ name: String, stored: String?, hold: Bool, state: [KeyRecorderState]) throws {
    let fake = FakeRecorder()
    let clock = TestClock()
    let controller = KeyRecorderController(recorder: fake, isHold: hold, now: { clock.now }, commit: { _ in })
    if !state.isEmpty { controller.start() }
    for s in state {
      clock.advance(0.3)
      controller.handle(s)
    }
    let label = hold ? "Keys to hold" : "Keys"
    try write(
      panel(
        LabeledParameter(label: label) {
          KeyRecorderField(stored: stored, isHold: hold, recorder: fake, controller: controller) { _ in }
        }), name)
  }

  @Test func parameterRecorderStates() throws {
    try recorder("param-recorder-idle-empty", stored: nil, hold: false, state: [])
    try recorder("param-recorder-idle", stored: "ctrl+opt+space", hold: false, state: [])
    try recorder("param-recorder-recording", stored: nil, hold: true, state: [.listening(held: [.ctrl, .opt])])
    try recorder("param-recorder-fn-result", stored: "fn", hold: true, state: [])
    try recorder(
      // The field keeps the refused input, "⌘" alone (§ Issue states), beside its message.
      "param-recorder-error", stored: "cmd", hold: false,
      state: [.listening(held: [.fn]), .recorded(KeyCombo(modifiers: [.fn])!)])
  }

  @Test func parameterAppChooser() throws {
    try write(
      panel(
        VStack(spacing: 4) {
          LabeledParameter(label: "App") {
            AppChooserField(bundleID: "com.example.quillpad", provider: nil, apps: InspectorFixtures.apps) { _ in }
          }
          LabeledParameter(label: "If already in front") {
            ChoiceParameterField(choices: ["hide", "stay"], parameter: "whenFrontmost", selection: "hide") { _ in nil }
          }
        }), "param-app-chooser")
    try write(
      AppListView(apps: InspectorFixtures.apps, current: "com.example.quillpad") { _ in }.background(Tokens.windowTint),
      "param-app-list", size: CGSize(width: 280, height: 320))
  }

  @Test func parameterTextFields() throws {
    try write(
      panel(
        LabeledParameter(label: "URL") {
          TextParameterField(text: "", placeholder: "https://…", issueFor: { _ in nil }) { _ in nil }
        }), "param-url")
    try write(
      panel(
        LabeledParameter(label: "URL") {
          TextParameterField(
            text: "example.com", placeholder: "https://…", error: IssueCopy.urlScheme, issueFor: { _ in nil }
          ) { _ in nil }
        }), "param-url-error")
    try write(
      panel(
        LabeledParameter(label: ActionNaming.sentenceCase("File or Folder")) {
          TextParameterField(
            text: "~/Documents/Notes", placeholder: "~/Documents", choosesPath: true,
            issueFor: { _ in nil }
          ) { _ in nil }
        }), "param-path")
    try write(
      panel(
        LabeledParameter(label: ActionNaming.sentenceCase("Shortcut Name")) {
          ShortcutNameField(
            name: "Start Focus", listing: nil, names: ["Start Focus", "Log Water"],
            issueFor: { _ in nil }
          ) { _ in nil }
        }), "param-shortcut")
  }

  @Test func parameterNumberChoiceHaptics() throws {
    let model = InspectorFixtures.model()
    let row = InspectorRow(
      binding: Binding(
        zone: .edge(.right), gesture: .slide, action: "keyboard.slideSteps",
        parameters: ["upKeys": "up", "downKeys": "down", "step": "0.125"]), source: nil)
    try write(
      panel(
        LabeledParameter(label: "Step") {
          NumberParameterField(
            model: model, row: row, key: "step", range: 0.02...0.5, fallback: 0.0625,
            format: .percent)
        }), "param-number")
    try write(
      panel(
        LabeledParameter(label: "Mode") {
          ChoiceParameterField(choices: ["one", "two", "three", "four"], parameter: "mode", selection: "two") { _ in
            nil
          }
        }), "param-choice-popup")
    try write(
      panel(
        LabeledParameter(label: "If already in front") {
          ChoiceParameterField(choices: ["hide", "stay"], parameter: "whenFrontmost", selection: "stay") { _ in nil }
        }), "param-choice-segmented")
    try write(panel(HapticsCheckbox(isOn: true) { _ in }), "param-haptics")
  }

  /// The presentation fields on `ActionParameter` (batch 20 rows), with fake descriptors.
  @Test func parameterPresentationFields() throws {
    var config = PreviewFixtures.demoConfig
    config.gestures.longPressMS = 500
    let model = InspectorFixtures.model(config: config)
    let stepMM = ActionParameter(
      key: "stepMM", kind: .number(4...20), required: false, defaultValue: "8", displayName: "Distance per app",
      helpText: "Slide this far to move one app.", unit: "mm")
    let keepOpen = ActionParameter(
      key: "keepOpenMS", kind: .number(0...1000), required: false, defaultValue: "400",
      displayName: "Keep open between strokes", unit: "ms", zeroLabel: "Off")
    let holdMS = ActionParameter(
      key: "holdMS", kind: .number(100...1500), required: false, displayName: "Press time",
      helpText: "How long to press before it runs.", unit: "ms", fallback: .longPressMS)
    func row(_ parameters: [String: String]) -> InspectorRow {
      InspectorRow(
        binding: Binding(zone: .edge(.right), gesture: .longPress, action: "media.next", parameters: parameters),
        source: nil)
    }
    func number(_ p: ActionParameter, _ r: InspectorRow, _ range: ClosedRange<Double>) -> some View {
      LabeledParameter(label: p.displayName, help: p.helpText) {
        NumberParameterField(
          model: model, row: r, key: p.key, range: range, fallback: p.defaultValue.flatMap(Double.init) ?? 0,
          format: .plain, parameter: p)
      }
    }
    try write(
      panel(
        VStack(alignment: .leading, spacing: 6) {
          number(stepMM, row([:]), 4...20)
          number(keepOpen, row(["keepOpenMS": "0"]), 0...1000)
          number(holdMS, row([:]), 100...1500)
          number(holdMS, row(["holdMS": "800"]), 100...1500)
        }, width: 440), "param-presentation-fields")
  }

  // MARK: Issue lines

  @Test func issueLineEachSeverity() throws {
    try write(
      panel(
        VStack(alignment: .leading, spacing: 12) {
          IssueLine(style: .error, text: IssueCopy.urlScheme)
          IssueLine(style: .warning, text: "Needs a backlit keyboard")
          IssueLine(style: .info, text: IssueCopy.tapWaits(ms: "300")) {
            TextAction(title: IssueCopy.useLongPress) {}
          }
        }), "issue-lines")
  }
}

/// A stand-in for batch 14's mirror: a pad with zones that publish picker anchors.
private struct PlaceholderMirror: View {
  var body: some View {
    // To scale: the external pad at the window mirror's points per millimetre, 8 mm strips, 10 mm corners.
    let mm = Tokens.mirrorPointsPerMM
    let sensor = PreviewFixtures.externalPad.sensorSizeMM
    let pad = CGRect(x: 60, y: 60, width: sensor.width * mm, height: sensor.height * mm)
    let strip: CGFloat = 8 * mm
    let corner: CGFloat = 10 * mm
    let zones: [(Zone, CGRect)] = [
      (.edge(.bottom), CGRect(x: pad.minX + corner, y: pad.maxY - strip, width: pad.width - 2 * corner, height: strip)),
      (.edge(.top), CGRect(x: pad.minX + corner, y: pad.minY, width: pad.width - 2 * corner, height: strip)),
      (.edge(.left), CGRect(x: pad.minX, y: pad.minY + corner, width: strip, height: pad.height - 2 * corner)),
      (.edge(.right), CGRect(x: pad.maxX - strip, y: pad.minY + corner, width: strip, height: pad.height - 2 * corner)),
      (.corner(.topLeft), CGRect(x: pad.minX, y: pad.minY, width: corner, height: corner)),
      (.corner(.topRight), CGRect(x: pad.maxX - corner, y: pad.minY, width: corner, height: corner)),
      (.corner(.bottomLeft), CGRect(x: pad.minX, y: pad.maxY - corner, width: corner, height: corner)),
      (.corner(.bottomRight), CGRect(x: pad.maxX - corner, y: pad.maxY - corner, width: corner, height: corner)),
    ]
    ZStack(alignment: .topLeading) {
      Tokens.windowTint
      RoundedRectangle(cornerRadius: Tokens.radiusPlate)
        .fill(
          LinearGradient(colors: [Tokens.padTop, Tokens.padBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .frame(width: pad.width, height: pad.height)
        .pickerMirrorBounds()
        .position(x: pad.midX, y: pad.midY)
      ForEach(Array(zones.enumerated()), id: \.offset) { _, zone in
        Capsule().fill(Tokens.bar.opacity(0.8))
          .frame(width: zone.1.width - 8, height: zone.1.height - 8)
          .frame(width: zone.1.width, height: zone.1.height)
          .pickerAnchor(for: zone.0)
          .position(x: zone.1.midX, y: zone.1.midY)
      }
    }
  }
}
