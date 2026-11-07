import EdgyCore
import EdgyRuntime
import SwiftUI

/// The inspector for the selected zone: name, Split into, mapped gestures, Add gesture…, parameter
/// rows, notes (bones 6–7, § Binding parameters, § App profiles rows, § Issue states).
///
/// Every edit goes through `model.editor` (see `InspectorModel.swift`). Clicking a row sets
/// `model.picking`; the pad popover (`ActionPickerView`) is the one place to map.
public struct InspectorView: View {
  @Bindable var model: SettingsModel

  public init(model: SettingsModel) {
    self.model = model
  }

  static let inset: CGFloat = 32

  public var body: some View {
    let _ = model.revision
    ScrollView(.vertical) {
      Group {
        if isOffInApp {
          // "Edgy is off in this app": the inspector stays empty (§ App profiles).
          Color.clear.frame(height: 1)
        } else if let zone = model.selectedZone {
          ZoneInspector(model: model, zone: zone)
        } else {
          Text("Click an edge or corner on the pad.")
            .font(Tokens.font(Tokens.typeBody)).foregroundStyle(Tokens.ink2)
        }
      }
      .frame(maxWidth: .infinity, alignment: .topLeading)
      .padding(.horizontal, Self.inset)
      .padding(.vertical, 28)
    }
    .scrollIndicators(.automatic)
  }

  private var isOffInApp: Bool {
    guard case .app = model.selectedProfile else { return false }
    return model.editor.profile(model.selectedProfile)?.disabled == true
  }
}

private struct ZoneInspector: View {
  @Bindable var model: SettingsModel
  var zone: Zone

  var body: some View {
    let rows = model.inspectorRows(for: zone)
    let drafts = model.inspectorDrafts
    VStack(alignment: .leading, spacing: 0) {
      Text(ZoneNaming.title(zone))
        .font(Tokens.font(Tokens.typeTitle, semibold: true))
        .foregroundStyle(Tokens.ink)
        .accessibilityAddTraits(.isHeader)
      if let count = model.splitCount(for: zone) {
        SplitControl(count: count, enabled: model.canSplit) { model.split(zone, into: $0) }
          .padding(.top, 12)
        ForEach(Array(model.overlaps(onEdgeOf: zone).enumerated()), id: \.offset) { _, overlap in
          IssueLine(style: .warning, text: IssueCopy.overlap(overlap.0, overlap.1, gesture: overlap.2)) {
            TextAction(title: "Show") { model.selectedZone = overlap.1 == zone ? overlap.0 : overlap.1 }
          }
          .padding(.top, 8)
        }
      }
      InspectorRule().padding(.top, 14).padding(.bottom, 10)
      VStack(alignment: .leading, spacing: 12) {
        ForEach(rows) { row in
          let key = InspectorDrafts.Key(profile: model.selectedProfile, binding: row.id)
          BindingRowView(
            model: model, row: row,
            isPicking: model.picking == PickerTarget(zone: zone, gesture: row.gesture),
            autofocus: drafts.focus == key)
        }
      }
      if !rows.isEmpty { InspectorRule().padding(.vertical, 10) }
      if !model.unmappedGestures(for: zone).isEmpty {
        Button {
          model.picking = PickerTarget(zone: zone, gesture: nil)
        } label: {
          HStack(spacing: 10) {
            Image(systemName: "plus").frame(width: GestureIcon.size)
            Text("Add gesture…")
          }
          .font(Tokens.font(Tokens.typeBody)).foregroundStyle(Tokens.ink)
          .frame(minHeight: 28).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
      TapNotes(model: model, zone: zone, rows: rows).padding(.top, 14)
    }
    .onChange(of: drafts.focus) { _, focus in
      // The focused field has drawn; one handoff per choice.
      guard focus != nil else { return }
      DispatchQueue.main.async { drafts.focus = nil }
    }
  }
}

/// "Split into 1 2 3 4" (bone 6).
struct SplitControl: View {
  var count: Int
  var enabled: Bool
  var set: (Int) -> Void

  var body: some View {
    HStack(spacing: 12) {
      Text("Split into").font(Tokens.font(Tokens.typeBody)).foregroundStyle(Tokens.ink2)
      Picker("Split into", selection: SwiftUI.Binding(get: { count }, set: set)) {
        ForEach(1...4, id: \.self) { Text("\($0)").tag($0) }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .fixedSize()
      .disabled(!enabled)
    }
  }
}

/// One mapped gesture: icon, gesture, action in plain text, source marks (§ App profiles rows),
/// the "…" menu, issue lines, then its parameter rows.
struct BindingRowView: View {
  @Bindable var model: SettingsModel
  var row: InspectorRow
  var isPicking: Bool
  var autofocus: Bool

  private static let textInset = GestureIcon.size + 10

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 10) {
        GestureIcon(gesture: row.gesture)
        Text(GestureNaming.name(row.gesture)).foregroundStyle(Tokens.ink)
        Spacer(minLength: 8)
        // While the picker is open the value is blank: its header already says it (bone 6).
        if !isPicking { value }
        RowMenu(model: model, row: row)
      }
      .font(Tokens.font(Tokens.typeBody))
      .frame(minHeight: 28)
      .padding(.horizontal, 6)
      .background(
        RoundedRectangle(cornerRadius: Tokens.radiusControl).fill(isPicking ? Tokens.bar.opacity(0.35) : .clear)
      )
      .contentShape(Rectangle())
      .onTapGesture { model.picking = PickerTarget(zone: row.binding.zone, gesture: row.gesture) }
      .padding(.horizontal, -6)
      .accessibilityElement(children: .combine)
      .accessibilityAddTraits(.isButton)

      Group {
        if let base = row.defaultBinding, row.source == .overridden || row.source == .turnedOff {
          Text("Default: \(model.actionName(base.action))").foregroundStyle(Tokens.ink2)
        }
        ForEach(Array(issueLines.enumerated()), id: \.offset) { _, line in
          IssueLine(style: line.0, text: line.1)
        }
      }
      .font(Tokens.font(Tokens.typeBody))
      .padding(.leading, Self.textInset)

      if row.showsParameters {
        ParameterRowsView(model: model, row: row, autofocus: autofocus)
          .padding(.leading, Self.textInset - ParameterRowsView.indent + 4)
          .padding(.top, 2)
      }
    }
  }

  @ViewBuilder private var value: some View {
    let name = model.actionName(row.binding.action, withEllipsis: true)
    let needs = model.needsLabel(row.binding)
    switch row.source {
    case .inherited:
      HStack(spacing: 12) {
        Text(name)
        Text("from Default")
      }
      .foregroundStyle(Tokens.ink2)
    case .turnedOff:
      HStack(spacing: 12) {
        Text("Off here").foregroundStyle(Tokens.ink2)
        TextAction(title: "Revert") { model.revert(row) }
      }
    case .overridden:
      HStack(spacing: 12) {
        HStack(spacing: 6) {
          Circle().fill(Tokens.ink).frame(width: 5, height: 5)
          Text(needs ?? name).foregroundStyle(needs == nil ? Tokens.ink : Tokens.ink2)
        }
        TextAction(title: "Revert") { model.revert(row) }
      }
    case .appOnly, nil:
      Text(needs ?? name).foregroundStyle(needs == nil ? Tokens.ink : Tokens.ink2)
    }
  }

  /// Warnings and errors attached to this binding, said once under it. Overlaps sit under the
  /// split control and the tap note has its own line; "Needs …" is the row's value.
  private var issueLines: [(IssueCopy.Style, String)] {
    guard row.source != .inherited, row.source != .turnedOff else { return [] }
    let descriptor = model.editor.validator.descriptor(for: row.binding.action)
    return model.inspectorIssues(for: row.id).compactMap { issue in
      switch issue.code {
      case .tapWaitsForDoubleTap, .overlappingZones, .missingParameter: return nil
      default:
        let parameter = descriptor?.parameters.first { $0.key == issue.parameter }
        let text = IssueCopy.message(
          for: issue, parameter: parameter, availability: model.editor.availability(of: row.binding.action))
        return text.map { (IssueCopy.Style(issue.severity), $0) }
      }
    }
  }
}

/// Every row's "…" menu (§ App profiles): Change action…, Turn off here, Revert to Default, each
/// greyed out when it doesn't apply. Default-tab and app-only rows get "Remove gesture" instead.
struct RowMenu: View {
  @Bindable var model: SettingsModel
  var row: InspectorRow

  var body: some View {
    Menu {
      Button("Change action…") { model.picking = PickerTarget(zone: row.binding.zone, gesture: row.gesture) }
      switch row.source {
      case nil, .appOnly:
        Button("Remove gesture") { model.remove(row) }
      case .inherited, .overridden, .turnedOff:
        Button("Turn off here") { model.turnOff(row) }.disabled(row.source == .turnedOff)
        Button("Revert to Default") { model.revert(row) }.disabled(row.source == .inherited)
      }
    } label: {
      Image(systemName: "ellipsis").foregroundStyle(Tokens.ink2)
    }
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    .fixedSize()
    .accessibilityLabel("More for \(GestureNaming.name(row.gesture))")
  }
}

/// Bone 7: the informational tap-waits note with its one fix.
private struct TapNotes: View {
  @Bindable var model: SettingsModel
  var zone: Zone
  var rows: [InspectorRow]

  var body: some View {
    let notes = rows.filter { $0.gesture == .tap }.flatMap { row in
      model.inspectorIssues(for: row.id).filter { $0.code == .tapWaitsForDoubleTap }.map { (row, $0) }
    }
    let longPressFree = !rows.contains { $0.gesture == .longPress && $0.source != .turnedOff }
    ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
      IssueLine(style: .info, text: IssueCopy.tapWaits(ms: note.1.detail ?? "300")) {
        if longPressFree {
          TextAction(title: IssueCopy.useLongPress) { model.useLongPressInstead(for: note.0.id) }
        }
      }
    }
  }
}

extension SettingsModel {
  /// The action's display name; "Open App…" style when `withEllipsis` and it takes parameters.
  func actionName(_ id: ActionID, withEllipsis: Bool = false) -> String {
    if id == .doNothing { return "Do nothing" }
    guard let descriptor = editor.validator.descriptor(for: id) else { return id.rawValue }
    return withEllipsis ? ActionNaming.pickerName(descriptor) : descriptor.displayName
  }

  /// "Needs keys" when a required parameter is empty, else `nil`.
  func needsLabel(_ binding: EdgyCore.Binding) -> String? {
    guard let descriptor = editor.validator.descriptor(for: binding.action) else { return nil }
    return descriptor.parameters.first {
      $0.required && (binding.parameters[$0.key] ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    }.map(ActionNaming.needs)
  }
}
