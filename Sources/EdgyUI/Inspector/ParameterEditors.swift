import Actions
import AppKit
import EdgyCore
import EdgyRuntime
import SwiftUI

/// What one parameter row edits. Pure: built from the action's descriptor plus the cross-cutting
/// parameters every binding takes (sensitivity on continuous actions, haptics last).
enum ParameterEditor: Equatable, Identifiable {
  case action(ActionParameter)
  /// Slide sensitivity (continuous actions), a multiplier shown as a percentage.
  case sensitivity
  /// "Haptics for this gesture", always the last row.
  case haptics

  var id: String {
    switch self {
    case .action(let parameter): return parameter.key
    case .sensitivity: return "sensitivity"
    case .haptics: return AppSettings.hapticsParameter
    }
  }

  static let sensitivityRange: ClosedRange<Double> = 0.25...4
  static let sensitivityDefault = 1.0

  /// The rows in order: the action's parameters ("Let go after" last of them, batch-15 design
  /// answer 2), then sensitivity on continuous actions, then "Press time" on a long-press whose
  /// action has no `holdMS` of its own (`ConfigValidator.pressTimeParameter`), then haptics.
  static func editors(for descriptor: ActionDescriptor?, gesture: GestureKind? = nil) -> [ParameterEditor] {
    guard let descriptor, descriptor.id != .doNothing else { return [] }
    var parameters = descriptor.parameters
    if let index = parameters.firstIndex(where: { $0.key == "maxSeconds" }) {
      parameters.append(parameters.remove(at: index))
    }
    var editors = parameters.map(ParameterEditor.action)
    // The generic Sensitivity row hides where "Distance per app/press" (`stepMM`) already sets the
    // feel (batch-20 critique): Switch Apps and Slide to Repeat Keys. Levels keep it.
    if descriptor.shape == .continuous, !parameters.contains(where: { $0.key == "stepMM" }) {
      editors.append(.sensitivity)
    }
    let pressTime = ConfigValidator.pressTimeParameter
    if gesture == .longPress, !parameters.contains(where: { $0.key == pressTime.key }) {
      editors.append(.action(pressTime))
    }
    editors.append(.haptics)
    return editors
  }

  /// The label a row shows in the label column (`nil` for checkbox rows, which carry their own).
  func columnLabel(action: ActionID) -> String? {
    switch self {
    case .haptics: return nil
    case .sensitivity: return "Sensitivity"
    case .action(let parameter):
      return ActionNaming.isOnOff(parameter) ? nil : ActionNaming.parameterLabel(parameter, action: action)
    }
  }
}

/// The parameter rows' alignment: a row's label lines up with its control's field, not with the
/// field and the message hanging under it.
extension VerticalAlignment {
  private enum ParameterRowAlignment: AlignmentID {
    static func defaultValue(in d: ViewDimensions) -> CGFloat { d[VerticalAlignment.center] }
  }

  static let parameterRow = VerticalAlignment(ParameterRowAlignment.self)
}

extension View {
  /// Marks this view (a field) as what its row's label lines up with.
  func parameterRowField() -> some View {
    alignmentGuide(.parameterRow) { d in d[VerticalAlignment.center] }
  }
}

/// The parameter rows under one binding row (BRIEF § Binding parameters → One rule): indented
/// 24 pt, 28 pt rows, label `ink2` on the left, control on the right, errors under the control.
struct ParameterRowsView: View {
  @Bindable var model: SettingsModel
  var row: InspectorRow
  /// Focus (or start recording in) the first field: the picker just handed off to this row.
  var autofocus = false

  static let indent: CGFloat = 24
  static let rowHeight: CGFloat = 28
  /// The label column never grows past this; labels stay on one line.
  static let maxLabelWidth: CGFloat = 170

  var body: some View {
    let descriptor = model.editor.validator.descriptor(for: row.binding.action)
    let editors = ParameterEditor.editors(for: descriptor, gesture: row.gesture)
    let labelWidth = Self.labelWidth(editors.compactMap { $0.columnLabel(action: row.binding.action) })
    VStack(alignment: .leading, spacing: 4) {
      ForEach(Array(editors.enumerated()), id: \.element.id) { index, editor in
        ParameterRow(
          model: model, row: row, editor: editor, labelWidth: labelWidth, autofocus: autofocus && index == 0)
      }
    }
    .padding(.leading, Self.indent)
  }

  /// One label column per binding, as wide as its longest label (so every control and slider
  /// track under one binding starts at the same x), capped at `maxLabelWidth`.
  static func labelWidth(_ labels: [String]) -> CGFloat {
    let font = NSFont.systemFont(ofSize: Tokens.typeBody)
    let widest = labels.map { ceil(($0 as NSString).size(withAttributes: [.font: font]).width) }.max() ?? 0
    return min(widest + 2, maxLabelWidth)
  }
}

/// Owner's ruling (batch 27): while Hold Keys has no keys, one line under the recorder says what
/// to press (13, `ink2`, the helper line's style). It goes once keys are set. No suggestion chips.
enum HoldKeysHint {
  static let empty =
    "Press the shortcut your app uses while held. For a key like fn alone, hold it a second, then let go."

  static func text(_ parameter: ActionParameter, in binding: EdgyCore.Binding) -> String? {
    guard binding.action == "keyboard.hold", parameter.kind == .keyCombo else { return nil }
    let keys = binding.parameters[parameter.key]?.trimmingCharacters(in: .whitespaces) ?? ""
    return keys.isEmpty ? empty : nil
  }
}

private struct ParameterRow: View {
  @Bindable var model: SettingsModel
  var row: InspectorRow
  var editor: ParameterEditor
  var labelWidth: CGFloat
  var autofocus: Bool

  var body: some View {
    switch editor {
    case .haptics:
      HapticsCheckbox(isOn: row.binding.parameters[AppSettings.hapticsParameter] != "off") { on in
        model.setParameter(AppSettings.hapticsParameter, to: on ? nil : "off", in: row)
      }
      .frame(minHeight: ParameterRowsView.rowHeight)
    case .sensitivity:
      LabeledParameter(label: "Sensitivity", labelWidth: labelWidth) {
        NumberParameterField(
          model: model, row: row, key: "sensitivity", range: ParameterEditor.sensitivityRange,
          fallback: ParameterEditor.sensitivityDefault, format: .percent)
      }
    case .action(let parameter) where ActionNaming.isOnOff(parameter):
      // On/off (`speedUp`): a checkbox with its helper line (BRIEF § Slide feel).
      let isOn = (row.binding.parameters[parameter.key] ?? parameter.defaultValue ?? "off") == "on"
      let set = { (on: Bool) in
        let value = on ? "on" : "off"
        model.setParameter(parameter.key, to: value == parameter.defaultValue ? nil : value, in: row)
      }
      // The helper starts at the label's x, not the box's, and has 8 pt after it like every other
      // helper line (critique 22 should-fix 1).
      HStack(alignment: .firstTextBaseline, spacing: CheckboxHelperRow.boxSpacing) {
        Toggle(isOn: SwiftUI.Binding(get: { isOn }, set: set)) {
          Text(ActionNaming.parameterLabel(parameter, action: row.binding.action))
        }
        .toggleStyle(.checkbox)
        .labelsHidden()
        .tint(Tokens.ink)
        VStack(alignment: .leading, spacing: 2) {
          Text(ActionNaming.parameterLabel(parameter, action: row.binding.action))
            .font(Tokens.font(Tokens.typeBody)).foregroundStyle(Tokens.ink)
            .frame(minHeight: ParameterRowsView.rowHeight)
            .contentShape(Rectangle())
            .onTapGesture { set(!isOn) }
            .accessibilityHidden(true)
          if let help = ActionNaming.parameterHelp(parameter) {
            Text(help).font(Tokens.font(Tokens.typeBody)).foregroundStyle(Tokens.ink2)
              .fixedSize(horizontal: false, vertical: true)
              .padding(.bottom, LabeledParameter<EmptyView>.helperSpacing)
          }
        }
      }
    case .action(let parameter):
      LabeledParameter(
        label: ActionNaming.parameterLabel(parameter, action: row.binding.action), labelWidth: labelWidth,
        help: ActionNaming.parameterHelp(parameter) ?? HoldKeysHint.text(parameter, in: row.binding)
      ) {
        control(for: parameter)
      }
    }
  }

  @ViewBuilder private func control(for parameter: ActionParameter) -> some View {
    let value = row.binding.parameters[parameter.key]
    switch parameter.kind {
    case .keyCombo:
      KeyRecorderField(
        stored: value, isHold: model.editor.validator.descriptor(for: row.binding.action)?.shape == .hold,
        allowsSequence: KeyRecorderController.allowsSequence(action: row.binding.action, parameter: parameter.key),
        recorder: model.keyRecorder, autostart: autofocus
      ) { model.setParameter(parameter.key, to: $0, in: row) }
    case .appBundleID:
      AppChooserField(bundleID: value, provider: model.installedApps) { bundleID in
        model.setParameter(parameter.key, to: bundleID, in: row)
      }
    case .url:
      TextParameterField(
        text: value ?? "", placeholder: "https://…", autofocus: autofocus, issueFor: issueFor(parameter)
      ) { model.setParameter(parameter.key, to: $0, in: row) }
    case .filePath:
      TextParameterField(
        text: value ?? "", placeholder: "~/Documents", autofocus: autofocus, choosesPath: true,
        issueFor: issueFor(parameter)
      ) { model.setParameter(parameter.key, to: $0, in: row) }
    case .text:
      ShortcutNameField(
        name: value ?? "", listing: model.shortcuts, autofocus: autofocus, issueFor: issueFor(parameter)
      ) { model.setParameter(parameter.key, to: $0, in: row) }
    case .number(let range):
      NumberParameterField(
        model: model, row: row, key: parameter.key, range: range,
        fallback: parameter.defaultValue.flatMap(Double.init) ?? range.lowerBound,
        format: parameter.unit != nil ? .plain : parameter.key == "maxSeconds" ? .seconds : .percent,
        parameter: parameter)
    case .choice(let choices):
      ChoiceParameterField(
        choices: ActionNaming.orderedChoices(choices, parameter: parameter.key), parameter: parameter.key,
        selection: value ?? parameter.defaultValue ?? choices.first ?? ""
      ) { model.setParameter(parameter.key, to: $0, in: row) }
    }
  }

  /// Copy for an issue the editor returns for this parameter.
  private func issueFor(_ parameter: ActionParameter) -> (ValidationIssue?) -> String? {
    { issue in issue.flatMap { IssueCopy.message(for: $0, parameter: parameter) } }
  }
}

/// Label left (13, `ink2`, one line, in the binding's label column), control right, one 28 pt
/// row. The label lines up with the control's field; a validation message hangs below it.
struct LabeledParameter<Control: View>: View {
  var label: String
  /// The label column's width (`ParameterRowsView.labelWidth`); `nil` sizes to the label.
  var labelWidth: CGFloat? = nil
  /// The one helper line under the row (13, `ink2`), only when the parameter has one.
  var help: String? = nil
  @ViewBuilder var control: Control

  /// Space after a helper line, before the next parameter row.
  static var helperSpacing: CGFloat { 8 }

  /// The least a control gets beside its label before the label moves above it.
  static var controlMinWidth: CGFloat { 140 }

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      // A label never breaks mid-word: when label and control don't fit one 28 pt row, the label
      // takes its own line above the control (chief, 2026-11-07, from the live window).
      ViewThatFits(in: .horizontal) {
        HStack(alignment: .parameterRow, spacing: 8) {
          labelText
            .lineLimit(1)
            .fixedSize()
            .frame(minWidth: labelWidth, minHeight: ParameterRowsView.rowHeight, alignment: .leading)
          control.frame(minWidth: Self.controlMinWidth, maxWidth: .infinity, alignment: .trailing)
        }
        VStack(alignment: .leading, spacing: 2) {
          labelText.fixedSize(horizontal: false, vertical: true)
          control.frame(maxWidth: .infinity, alignment: .trailing)
        }
      }
      if let help {
        // 8 pt after a helper line so it doesn't crowd the next row (critique 21 should-fix 2).
        Text(help).font(Tokens.font(Tokens.typeBody)).foregroundStyle(Tokens.ink2)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.bottom, Self.helperSpacing)
      }
    }
  }
}

extension LabeledParameter {
  fileprivate var labelText: some View {
    Text(label).font(Tokens.font(Tokens.typeBody)).foregroundStyle(Tokens.ink2)
  }
}

/// Validation text under its control: 13, `ink`, a small error icon, never red or accent.
struct FieldError: View {
  var text: String?
  var body: some View {
    if let text {
      IssueLine(style: .error, text: text).frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

// MARK: - Key combo recorder

/// Idle: the combo as key symbols, or "Click to record" in `ink2`. Recording: a 2 pt accent ring,
/// "Press keys…", held modifiers live in `ink2`. Esc cancels; ⌫ while idle clears.
///
/// On a sequence field (Keyboard Shortcut's `keys`, BRIEF § Key sequences):
/// - The value shows as keycap groups joined by ", " ("⌃ B, N").
/// - "+ Then…" (quiet `ink2`) sits right of the field once a combo is set, and records the next
///   step. It's hidden while recording and at 4 steps.
/// - ⌫ while idle removes the last step.
/// - While recording, "Use Escape" sits under the field: Esc itself cancels, so this commits
///   `escape` as the step (§ Recording Escape itself).
///
/// Hold Keys and the slide-repeat keys take one combo and get neither button.
struct KeyRecorderField: View {
  var stored: String?
  var isHold: Bool
  var allowsSequence = false
  var autostart = false
  /// The new stored value (`nil` clears it).
  var commit: (String?) -> Void
  @State private var controller: KeyRecorderController
  @FocusState private var focused: Bool

  init(
    stored: String?, isHold: Bool, allowsSequence: Bool = false, recorder: KeyComboRecording?,
    autostart: Bool = false, controller: KeyRecorderController? = nil, commit: @escaping (String?) -> Void
  ) {
    self.stored = stored
    self.isHold = isHold
    self.allowsSequence = allowsSequence && !isHold
    self.autostart = autostart
    self.commit = commit
    _controller = State(
      initialValue: controller
        ?? KeyRecorderController(recorder: recorder, isHold: isHold) { _, value in commit(value) })
  }

  static let width: CGFloat = 170
  static let thenLabel = "+ Then…"
  static let thenTooltip = "Send another shortcut after this one"
  static let escapeLabel = "Use Escape"
  static let escapeTooltip = "Record the Escape key itself"

  /// Whether "Use Escape" shows: a sequence field (Keyboard Shortcut), while recording.
  static func showsUseEscape(allowsSequence: Bool, isRecording: Bool) -> Bool {
    allowsSequence && isRecording
  }

  var body: some View {
    VStack(alignment: .trailing, spacing: 4) {
      HStack(spacing: 8) {
        field
        if KeyRecorderController.showsThen(
          stored: stored, allowsSequence: allowsSequence, isRecording: controller.isRecording)
        {
          QuietTextButton(title: Self.thenLabel, tooltip: Self.thenTooltip) {
            focused = true
            controller.start(after: stored)
          }
        }
      }
      if Self.showsUseEscape(allowsSequence: allowsSequence, isRecording: controller.isRecording) {
        QuietTextButton(title: Self.escapeLabel, tooltip: Self.escapeTooltip) { controller.useEscape() }
      }
      FieldError(text: controller.error).frame(maxWidth: Self.width + 16)
    }
    .onAppear {
      guard autostart else { return }
      focused = true
      if !controller.isRecording { controller.start() }
    }
    .onDisappear { if controller.isRecording { controller.cancel() } }
  }

  private var field: some View {
    Button {
      controller.isRecording ? controller.cancel() : controller.start()
    } label: {
      label.frame(maxWidth: Self.width, alignment: .leading).fieldChrome(
        active: controller.isRecording, ring: Tokens.accent
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .parameterRowField()
    .focusable()
    .focusEffectDisabled()
    .focused($focused)
    // While recording, every key belongs to the recorder (Return, Tab, Space and Delete record
    // directly): none may press the field, move focus or clear the value. The tap only listens,
    // so the key also reaches this view; the key that commits is swallowed for a moment after.
    .onKeyPress(phases: .all) { _ in controller.swallowsKeys ? .handled : .ignored }
    .onKeyPress(.delete) {
      guard !controller.swallowsKeys else { return .handled }
      commit(KeyRecorderController.removingLastStep(stored))
      return .handled
    }
    .accessibilityLabel(controller.isRecording ? "Press keys" : displayText ?? "Click to record")
  }

  private var displayText: String? {
    guard let stored, !stored.isEmpty else { return nil }
    return KeyComboText.display(stored)
  }

  @ViewBuilder private var label: some View {
    switch controller.phase {
    case .recording(let held):
      HStack(spacing: 6) {
        if !held.isEmpty { Text(KeyComboText.symbols(held)).foregroundStyle(Tokens.ink2) }
        Text("Press keys…").foregroundStyle(Tokens.ink2)
      }
      .font(Tokens.font(Tokens.typeBody))
    case .idle:
      if let displayText {
        Text(displayText).font(Tokens.font(Tokens.typeBody)).foregroundStyle(Tokens.ink)
          .lineLimit(1).truncationMode(.middle)
      } else {
        Text("Click to record").font(Tokens.font(Tokens.typeBody)).foregroundStyle(Tokens.ink2)
      }
    }
  }
}

/// A quiet text button beside or under a field: 13 regular `ink2`, no bezel, with a tooltip.
struct QuietTextButton: View {
  var title: String
  var tooltip: String
  var action: () -> Void

  var body: some View {
    Button(title, action: action)
      .buttonStyle(.plain)
      .font(Tokens.font(Tokens.typeBody))
      .foregroundStyle(Tokens.ink2)
      .lineLimit(1)
      .fixedSize()
      .help(tooltip)
  }
}

// MARK: - App chooser

/// A pop-up button with the app's icon and name; opens the app list (search, Running, All apps).
struct AppChooserField: View {
  var bundleID: String?
  var provider: InstalledAppsProviding?
  var commit: (String) -> Void
  @State private var apps: [InstalledApp]
  @State private var open = false

  init(
    bundleID: String?, provider: InstalledAppsProviding?, apps: [InstalledApp] = [],
    commit: @escaping (String) -> Void
  ) {
    self.bundleID = bundleID
    self.provider = provider
    self.commit = commit
    _apps = State(initialValue: apps)
  }

  static let width: CGFloat = 170

  var body: some View {
    Button {
      open = true
    } label: {
      HStack(spacing: 6) {
        if let app = current { AppIcon(path: app.path) }
        Text(current?.name ?? bundleID ?? "Choose an app")
          .foregroundStyle(bundleID == nil ? Tokens.ink2 : Tokens.ink)
          .lineLimit(1)
        Spacer(minLength: 4)
        Image(systemName: "chevron.up.chevron.down").foregroundStyle(Tokens.ink2)
      }
      .font(Tokens.font(Tokens.typeBody))
      .frame(maxWidth: Self.width)
      .fieldChrome()
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .popover(isPresented: $open, arrowEdge: .bottom) {
      // Batch 28: the list loads itself when the popover opens (the field's `.task` result never
      // reached an already-open popover), and icons load off the main thread.
      AppListView(apps: apps, current: bundleID, provider: provider) { app in
        open = false
        commit(app.bundleID)
      }
      .environment(\.appIconsLoadOffMain, true)
    }
    .task {
      guard apps.isEmpty, let provider else { return }
      apps = await provider.installedApps()
    }
  }

  private var current: InstalledApp? {
    guard let bundleID else { return nil }
    return apps.first { $0.bundleID == bundleID }
  }
}

/// The real app icon from its bundle. A bundle with no icon of its own gets the Open App tile in
/// `ink2` (critique 22 must-fix), never the system's generic pale square.
struct AppIcon: View {
  var path: String
  @Environment(\.appIconsLoadOffMain) private var offMain
  @State private var loaded: AppIconCache.Icon?

  var body: some View {
    Group {
      switch loaded ?? (offMain ? AppIconCache.shared.cached(path) : AppIconCache.shared.icon(path)) {
      case .image(let icon)?:
        Image(nsImage: icon).resizable().frame(width: 16, height: 16)
      case .none?:
        ActionIcon(id: "app.open", size: 16).foregroundStyle(Tokens.ink2)
      case nil:
        // Loading off the main thread: hold the row's place.
        Color.clear.frame(width: 16, height: 16)
      }
    }
    .accessibilityHidden(true)
    .task(id: path) {
      guard offMain, AppIconCache.shared.cached(path) == nil else { return }
      loaded = await AppIconCache.shared.load(path)
    }
  }
}

/// App icons by bundle path, read once (batch 28). `icon(_:)` reads on the calling thread (fixed
/// lists in previews and snapshots); `load(_:)` reads off the main thread for live lists.
@MainActor
final class AppIconCache {
  enum Icon: @unchecked Sendable {
    case image(NSImage)
    /// The bundle has no icon of its own: the Open App tile.
    case none
  }

  static let shared = AppIconCache()
  private var icons: [String: Icon] = [:]
  /// For tests: how many icons were read.
  private(set) var reads = 0

  func cached(_ path: String) -> Icon? { icons[path] }

  func icon(_ path: String) -> Icon {
    if let known = icons[path] { return known }
    let icon = Self.read(path)
    store(icon, path)
    return icon
  }

  func load(_ path: String) async -> Icon {
    if let known = icons[path] { return known }
    let icon = await Task.detached(priority: .userInitiated) { Self.read(path) }.value
    store(icon, path)
    return icon
  }

  private func store(_ icon: Icon, _ path: String) {
    icons[path] = icon
    reads += 1
  }

  nonisolated private static func read(_ path: String) -> Icon {
    AppMark.icon(path).map(Icon.image) ?? .none
  }
}

extension EnvironmentValues {
  /// Live lists load app icons off the main thread; previews and snapshots read them in place.
  @Entry var appIconsLoadOffMain = false
}

/// Search, then Running (apps open now), then All apps — the same list as add-app.
struct AppListView: View {
  var current: String?
  var provider: InstalledAppsProviding?
  var choose: (InstalledApp) -> Void
  @State private var apps: [InstalledApp]
  @State private var loading: Bool
  @State private var query = ""
  @FocusState private var searching: Bool

  static let loadingCopy = "Loading apps\u{2026}"

  /// `apps`: what the caller already has. Empty with a `provider`: the list loads when it opens
  /// and says "Loading apps…" until the apps arrive.
  init(
    apps: [InstalledApp], current: String?, provider: InstalledAppsProviding? = nil,
    choose: @escaping (InstalledApp) -> Void
  ) {
    self.current = current
    self.provider = provider
    self.choose = choose
    _apps = State(initialValue: apps)
    _loading = State(initialValue: apps.isEmpty && provider != nil)
  }

  /// One row per app per section. IDs carry the section, so the app that sits in both Running and
  /// All apps is two distinct rows (a lazy stack keyed by the app alone drew the repeat empty).
  struct Row: Identifiable, Equatable {
    var section: String
    var app: InstalledApp
    var isHeader = false
    var id: String { isHeader ? "header|\(section)" : "\(section)|\(app.bundleID)" }
  }

  static func rows(_ apps: [InstalledApp], query: String) -> [Row] {
    let filtered = apps.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
    var rows: [Row] = []
    for (title, list) in [("Running", filtered.filter(\.isRunning)), ("All apps", filtered)] where !list.isEmpty {
      rows.append(Row(section: title, app: list[0], isHeader: true))
      rows += list.map { Row(section: title, app: $0) }
    }
    return rows
  }

  /// Loads the apps once; safe to call again.
  static func load(from provider: InstalledAppsProviding) async -> [InstalledApp] {
    await provider.installedApps()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      SearchField(text: $query, prompt: "Search apps").focused($searching)
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 2) {
          if loading {
            Text(Self.loadingCopy).font(Tokens.font(Tokens.typeBody)).foregroundStyle(Tokens.ink2)
              .padding(.top, 6)
          }
          ForEach(Self.rows(apps, query: query)) { row in
            if row.isHeader { header(row.section) } else { appRow(row.app) }
          }
        }
      }
    }
    .padding(12)
    .frame(width: 280, height: 320)
    .onAppear { searching = true }
    .task {
      guard apps.isEmpty, let provider else { return }
      let loaded = await Self.load(from: provider)
      apps = loaded
      loading = false
    }
  }

  /// Section headers are 13 semibold `ink2`: 11 pt is for the action picker's group headers only
  /// (batch-15 design answer 3).
  private func header(_ title: String) -> some View {
    Text(title).font(Tokens.font(Tokens.typeBody, semibold: true)).foregroundStyle(Tokens.ink2)
      .padding(.top, 6)
  }

  private func appRow(_ app: InstalledApp) -> some View {
    Button {
      choose(app)
    } label: {
      HStack(spacing: 8) {
        AppIcon(path: app.path)
        Text(app.name).font(Tokens.font(Tokens.typeBody, semibold: app.bundleID == current))
          .foregroundStyle(Tokens.ink)
        Spacer()
      }
      .frame(minHeight: 24)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Text, URL, path

/// A text field that keeps the user's input when the edit is refused and shows why under it.
struct TextParameterField: View {
  var placeholder: String
  var autofocus = false
  var choosesPath = false
  var issueFor: (ValidationIssue?) -> String?
  var commit: (String?) -> ValidationIssue?
  @State private var text: String
  @State private var error: String?
  @FocusState private var focused: Bool

  init(
    text: String, placeholder: String, autofocus: Bool = false, choosesPath: Bool = false, error: String? = nil,
    issueFor: @escaping (ValidationIssue?) -> String?, commit: @escaping (String?) -> ValidationIssue?
  ) {
    self.placeholder = placeholder
    self.autofocus = autofocus
    self.choosesPath = choosesPath
    self.issueFor = issueFor
    self.commit = commit
    _text = State(initialValue: text)
    _error = State(initialValue: error)
  }

  static let width: CGFloat = 170

  var body: some View {
    VStack(alignment: .trailing, spacing: 4) {
      HStack(spacing: 6) {
        // The field takes the room left; a long path is cut in the middle so the file's name shows.
        TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(Tokens.ink2))
          .textFieldStyle(.plain)
          .font(Tokens.font(Tokens.typeBody))
          .foregroundStyle(Tokens.ink)
          .lineLimit(1)
          .truncationMode(.middle)
          .focused($focused)
          .onSubmit(apply)
          .frame(maxWidth: choosesPath ? .infinity : Self.width)
          .fieldChrome(active: focused)
        if choosesPath {
          // A real bordered button that never wraps (§ Binding parameters: "plus a Choose… button").
          Button("Choose…", action: choosePath)
            .buttonStyle(.bordered)
            .font(Tokens.font(Tokens.typeBody))
            .fixedSize()
        }
      }
      .parameterRowField()
      FieldError(text: error).frame(maxWidth: choosesPath ? .infinity : Self.width + 16)
    }
    .onChange(of: focused) { _, now in if !now { apply() } }
    .onAppear { if autofocus { focused = true } }
  }

  private func apply() {
    let trimmed = text.trimmingCharacters(in: .whitespaces)
    error = issueFor(commit(trimmed.isEmpty ? nil : trimmed))
  }

  private func choosePath() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    text = url.path.hasPrefix(home) ? "~" + url.path.dropFirst(home.count) : url.path
    apply()
  }
}

/// Run Shortcut's name: a pop-up of the user's shortcuts when the runtime lists any, else text.
struct ShortcutNameField: View {
  var name: String
  var listing: ShortcutsListing?
  var autofocus = false
  var issueFor: (ValidationIssue?) -> String?
  var commit: (String?) -> ValidationIssue?
  @State private var names: [String]

  init(
    name: String, listing: ShortcutsListing?, names: [String] = [], autofocus: Bool = false,
    issueFor: @escaping (ValidationIssue?) -> String?, commit: @escaping (String?) -> ValidationIssue?
  ) {
    self.name = name
    self.listing = listing
    self.autofocus = autofocus
    self.issueFor = issueFor
    self.commit = commit
    _names = State(initialValue: names)
  }

  var body: some View {
    Group {
      if names.isEmpty {
        TextParameterField(
          text: name, placeholder: "Shortcut name", autofocus: autofocus, issueFor: issueFor, commit: commit)
      } else {
        Menu {
          ForEach(names, id: \.self) { option in
            Button(option) { _ = commit(option) }
          }
        } label: {
          HStack {
            Text(name.isEmpty ? "Choose a shortcut" : name)
              .foregroundStyle(name.isEmpty ? Tokens.ink2 : Tokens.ink).lineLimit(1)
            Spacer(minLength: 4)
            Image(systemName: "chevron.up.chevron.down").foregroundStyle(Tokens.ink2)
          }
          .font(Tokens.font(Tokens.typeBody))
          .frame(width: TextParameterField.width)
          .fieldChrome()
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
      }
    }
    .task {
      guard names.isEmpty, let listing else { return }
      names = await listing.shortcuts().names
    }
  }
}

// MARK: - Number, choice, haptics

/// A slider with its value (and unit) as text on the right, in proportional figures. The value is
/// `ink2` at its default and `ink` once changed; a parameter with an app-wide `fallback` reads
/// "Default (500 ms)" until changed, then offers Reset. One drag = one undo step.
struct NumberParameterField: View {
  enum Format { case percent, seconds, plain }

  @Bindable var model: SettingsModel
  var row: InspectorRow
  var key: String
  var range: ClosedRange<Double>
  var fallback: Double
  var format: Format
  var parameter: ActionParameter? = nil

  static let width: CGFloat = 130
  /// The value column: fixed, so every slider track under a binding ends at the same x.
  static let valueWidth: CGFloat = 56

  var body: some View {
    let raw = row.binding.parameters[key].flatMap(Double.init)
    let stored = raw ?? baseValue
    let changed = raw != nil && raw != baseValue
    HStack(spacing: 8) {
      Slider(
        value: SwiftUI.Binding(
          get: { stored },
          set: { model.setParameter(key, to: Self.text(for: $0), in: row) }),
        in: range
      ) { editing in
        if editing {
          model.editor.beginContinuousEdit("parameter.\(key)")
        } else {
          try? model.editor.endContinuousEdit()
        }
      }
      .tint(Tokens.ink)
      .controlSize(.small)
      // The slider gives way so the value (and Reset) always read in full on one line.
      .frame(minWidth: 70, maxWidth: Self.width)
      .layoutPriority(-1)
      Text(valueText(stored, isAbsent: raw == nil))
        .font(Tokens.font(Tokens.typeBody)).foregroundStyle(changed ? Tokens.ink : Tokens.ink2)
        .lineLimit(1).fixedSize().frame(minWidth: Self.valueWidth, alignment: .trailing)
      if parameter?.fallback != nil, raw != nil {
        TextAction(title: "Reset") { model.setParameter(key, to: nil, in: row) }.fixedSize()
      }
    }
  }

  /// The value when the parameter is absent: the app-wide setting it falls back to, else its default.
  var baseValue: Double {
    switch parameter?.fallback {
    case .longPressMS: return model.editor.config.gestures.longPressMS
    case nil: return fallback
    }
  }

  func valueText(_ value: Double, isAbsent: Bool) -> String {
    let text = Self.label(value, format: format, parameter: parameter)
    return parameter?.fallback != nil && isAbsent ? "Default (\(text))" : text
  }

  static func text(for value: Double) -> String {
    let rounded = (value * 1000).rounded() / 1000
    return rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
  }

  /// "150%" (no space before %), "120 s", "8 mm", or the parameter's zero label ("Off").
  static func label(_ value: Double, format: Format, parameter: ActionParameter? = nil) -> String {
    if value == 0, let zero = parameter?.zeroLabel { return zero }
    if let unit = parameter?.unit {
      let number = value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
      return unit == "%" ? "\(number)%" : "\(number) \(unit)"
    }
    switch format {
    case .percent: return "\(Int((value * 100).rounded()))%"
    case .seconds: return "\(Int(value.rounded())) s"
    case .plain: return text(for: value)
    }
  }
}

/// Segmented for ≤3 options, a pop-up otherwise.
struct ChoiceParameterField: View {
  var choices: [String]
  var parameter: String
  var selection: String
  var commit: (String) -> ValidationIssue?

  var body: some View {
    let binding = SwiftUI.Binding(get: { selection }, set: { _ = commit($0) })
    if choices.count <= 3 {
      Picker("", selection: binding) {
        ForEach(choices, id: \.self) { Text(ActionNaming.choiceLabel($0, parameter: parameter)).tag($0) }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .fixedSize()
    } else {
      Picker("", selection: binding) {
        ForEach(choices, id: \.self) { Text(ActionNaming.choiceLabel($0, parameter: parameter)).tag($0) }
      }
      .pickerStyle(.menu)
      .labelsHidden()
      .fixedSize()
    }
  }
}

/// A checkbox row whose label and helper line share one leading edge.
enum CheckboxHelperRow {
  /// The gap between the box and its label (the system checkbox's own).
  static let boxSpacing: CGFloat = 6
}

/// "Haptics for this gesture", on by default (BRIEF § Binding parameters → Per-binding haptics).
struct HapticsCheckbox: View {
  var isOn: Bool
  var set: (Bool) -> Void

  var body: some View {
    Toggle(isOn: SwiftUI.Binding(get: { isOn }, set: { set($0) })) {
      Text("Haptics for this gesture").font(Tokens.font(Tokens.typeBody)).foregroundStyle(Tokens.ink)
    }
    .toggleStyle(.checkbox)
    .tint(Tokens.ink)
  }
}

/// The picker's and app list's search field: magnifier, plain field, drawn border.
struct SearchField: View {
  @SwiftUI.Binding var text: String
  var prompt: String

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: "magnifyingglass").foregroundStyle(Tokens.ink2)
      TextField("", text: $text, prompt: Text(prompt).foregroundStyle(Tokens.ink2))
        .textFieldStyle(.plain)
        .foregroundStyle(Tokens.ink)
    }
    .font(Tokens.font(Tokens.typeBody))
    .frame(height: 28)
    .fieldChrome()
  }
}
