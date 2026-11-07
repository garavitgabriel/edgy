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

  static func editors(for descriptor: ActionDescriptor?) -> [ParameterEditor] {
    guard let descriptor, descriptor.id != .doNothing else { return [] }
    var editors = descriptor.parameters.map(ParameterEditor.action)
    if descriptor.shape == .continuous { editors.append(.sensitivity) }
    editors.append(.haptics)
    return editors
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

  var body: some View {
    let descriptor = model.editor.validator.descriptor(for: row.binding.action)
    let editors = ParameterEditor.editors(for: descriptor)
    VStack(alignment: .leading, spacing: 4) {
      ForEach(Array(editors.enumerated()), id: \.element.id) { index, editor in
        ParameterRow(model: model, row: row, editor: editor, autofocus: autofocus && index == 0)
      }
    }
    .padding(.leading, Self.indent)
  }
}

private struct ParameterRow: View {
  @Bindable var model: SettingsModel
  var row: InspectorRow
  var editor: ParameterEditor
  var autofocus: Bool

  var body: some View {
    switch editor {
    case .haptics:
      HapticsCheckbox(isOn: row.binding.parameters[AppSettings.hapticsParameter] != "off") { on in
        model.setParameter(AppSettings.hapticsParameter, to: on ? nil : "off", in: row)
      }
      .frame(minHeight: ParameterRowsView.rowHeight)
    case .sensitivity:
      LabeledParameter(label: "Sensitivity") {
        NumberParameterField(
          model: model, row: row, key: "sensitivity", range: ParameterEditor.sensitivityRange,
          fallback: ParameterEditor.sensitivityDefault, format: .percent)
      }
    case .action(let parameter):
      LabeledParameter(label: ActionNaming.parameterLabel(parameter, action: row.binding.action)) {
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
        recorder: model.keyRecorder, autostart: autofocus
      ) { combo in
        model.setParameter(parameter.key, to: combo?.description, in: row)
      }
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
        format: parameter.key == "maxSeconds" ? .seconds : .percent)
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

/// Label left (13, `ink2`), control right, one 28 pt row.
struct LabeledParameter<Control: View>: View {
  var label: String
  @ViewBuilder var control: Control

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 12) {
      Text(label).font(Tokens.font(Tokens.typeBody)).foregroundStyle(Tokens.ink2)
        .frame(minHeight: ParameterRowsView.rowHeight, alignment: .leading)
      Spacer(minLength: 8)
      control
    }
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
struct KeyRecorderField: View {
  var stored: String?
  var isHold: Bool
  var autostart = false
  var commit: (KeyCombo?) -> Void
  @State private var controller: KeyRecorderController
  @FocusState private var focused: Bool

  init(
    stored: String?, isHold: Bool, recorder: KeyComboRecording?, autostart: Bool = false,
    controller: KeyRecorderController? = nil, commit: @escaping (KeyCombo?) -> Void
  ) {
    self.stored = stored
    self.isHold = isHold
    self.autostart = autostart
    self.commit = commit
    _controller = State(
      initialValue: controller ?? KeyRecorderController(recorder: recorder, isHold: isHold) { commit($0) })
  }

  static let width: CGFloat = 170

  var body: some View {
    VStack(alignment: .trailing, spacing: 4) {
      Button {
        controller.isRecording ? controller.cancel() : controller.start()
      } label: {
        label.frame(width: Self.width, alignment: .leading).fieldChrome(active: controller.isRecording, ring: Tokens.accent)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .focusable()
      .focusEffectDisabled()
      .focused($focused)
      .onKeyPress(.delete) {
        guard !controller.isRecording else { return .ignored }
        commit(nil)
        return .handled
      }
      .accessibilityLabel(controller.isRecording ? "Press keys" : displayText ?? "Click to record")
      FieldError(text: controller.error).frame(width: Self.width + 16)
    }
    .onAppear {
      guard autostart else { return }
      focused = true
      if !controller.isRecording { controller.start() }
    }
    .onDisappear { if controller.isRecording { controller.cancel() } }
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
      } else {
        Text("Click to record").font(Tokens.font(Tokens.typeBody)).foregroundStyle(Tokens.ink2)
      }
    }
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
      .frame(width: Self.width)
      .fieldChrome()
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .popover(isPresented: $open, arrowEdge: .bottom) {
      AppListView(apps: apps, current: bundleID) { app in
        open = false
        commit(app.bundleID)
      }
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

/// The real app icon from its bundle (the system's own icon, never a drawn square).
struct AppIcon: View {
  var path: String
  var body: some View {
    Image(nsImage: NSWorkspace.shared.icon(forFile: path)).resizable().frame(width: 16, height: 16)
      .accessibilityHidden(true)
  }
}

/// Search, then Running (apps open now), then All apps — the same list as add-app.
struct AppListView: View {
  var apps: [InstalledApp]
  var current: String?
  var choose: (InstalledApp) -> Void
  @State private var query = ""
  @FocusState private var searching: Bool

  var body: some View {
    let filtered = apps.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
    VStack(alignment: .leading, spacing: 8) {
      SearchField(text: $query, prompt: "Search apps").focused($searching)
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 2) {
          section("Running", filtered.filter(\.isRunning))
          section("All apps", filtered)
        }
      }
    }
    .padding(12)
    .frame(width: 280, height: 320)
    .onAppear { searching = true }
  }

  @ViewBuilder private func section(_ title: String, _ apps: [InstalledApp]) -> some View {
    if !apps.isEmpty {
      Text(title).font(Tokens.font(Tokens.typeSmall, semibold: true)).foregroundStyle(Tokens.ink2)
        .padding(.top, 6)
      ForEach(apps) { app in
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
        TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(Tokens.ink2))
          .textFieldStyle(.plain)
          .font(Tokens.font(Tokens.typeBody))
          .foregroundStyle(Tokens.ink)
          .focused($focused)
          .onSubmit(apply)
          .frame(width: choosesPath ? Self.width - 70 : Self.width)
          .fieldChrome(active: focused)
        if choosesPath { TextAction(title: "Choose…", semibold: false, action: choosePath) }
      }
      FieldError(text: error).frame(width: Self.width + 16)
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

/// A slider with its value as text on the right, in proportional figures. One drag = one undo step.
struct NumberParameterField: View {
  enum Format { case percent, seconds }

  @Bindable var model: SettingsModel
  var row: InspectorRow
  var key: String
  var range: ClosedRange<Double>
  var fallback: Double
  var format: Format

  static let width: CGFloat = 150

  var body: some View {
    let stored = row.binding.parameters[key].flatMap(Double.init) ?? fallback
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
      .frame(width: Self.width)
      Text(Self.label(stored, format: format))
        .font(Tokens.font(Tokens.typeBody)).foregroundStyle(Tokens.ink)
        .frame(width: 44, alignment: .trailing)
    }
  }

  static func text(for value: Double) -> String {
    let rounded = (value * 1000).rounded() / 1000
    return rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
  }

  /// "150%" (no space before %), "120 s".
  static func label(_ value: Double, format: Format) -> String {
    switch format {
    case .percent: return "\(Int((value * 100).rounded()))%"
    case .seconds: return "\(Int(value.rounded())) s"
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

/// "Haptics for this gesture", on by default (BRIEF § Binding parameters → Per-binding haptics).
struct HapticsCheckbox: View {
  var isOn: Bool
  var set: (Bool) -> Void

  var body: some View {
    Toggle(isOn: SwiftUI.Binding(get: { isOn }, set: set)) {
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
