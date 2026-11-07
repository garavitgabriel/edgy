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

  /// Leading and trailing inset (render A: about 22 pt from the column's edge).
  static let inset: CGFloat = 22

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
    VStack(alignment: .leading, spacing: 0) {
      Text(Self.title(zone))
        .font(Tokens.font(Tokens.typeTitle, semibold: true))
        .foregroundStyle(Tokens.ink)
        .accessibilityAddTraits(.isHeader)
      if case .edge(let edge, _, let count) = zone {
        // No Split on app tabs: hidden, not greyed out (§ App profiles, chief ruling).
        if model.selectedProfile == .default {
          SplitControl(model: model, zone: zone, enabled: model.canSplit).padding(.top, 12)
        }
        ForEach(Array(model.overlaps(onEdgeOf: zone).enumerated()), id: \.offset) { _, overlap in
          IssueLine(style: .warning, text: IssueCopy.overlap(overlap.0, overlap.1, gesture: overlap.2)) {
            TextAction(title: "Show") { model.selectedZone = overlap.1 == zone ? overlap.0 : overlap.1 }
          }
          .padding(.top, 8)
        }
        InspectorRule().padding(.top, 14).padding(.bottom, 10)
        if count > 1 {
          // A split edge's bindings group by segment (§ Split control), in reading order.
          VStack(alignment: .leading, spacing: 14) {
            ForEach(SplitNaming.readingOrder(edge: edge, segments: count), id: \.self) { segment in
              if case .edge(_, let index, _) = segment {
                VStack(alignment: .leading, spacing: 6) {
                  Text(SplitNaming.heading(edge: edge, segment: index, segments: count))
                    .font(Tokens.font(Tokens.typeBody, semibold: true)).foregroundStyle(Tokens.ink2)
                    .accessibilityAddTraits(.isHeader)
                  SegmentBindings(model: model, zone: segment, rules: false)
                }
              }
            }
          }
        } else {
          SegmentBindings(model: model, zone: zone, rules: true)
        }
      } else {
        InspectorRule().padding(.top, 14).padding(.bottom, 10)
        SegmentBindings(model: model, zone: zone, rules: true)
      }
    }
  }

  /// The 26 pt title. A split edge is named as the edge ("Right edge"); its parts are the headings.
  static func title(_ zone: Zone) -> String {
    if case .edge(let edge, _, let count) = zone, count > 1 { return ZoneNaming.title(.edge(edge)) }
    return ZoneNaming.title(zone)
  }
}

/// One zone's (or one segment's) mapped gestures, the pending row while picking, "Add gesture…" and
/// its interaction notes.
private struct SegmentBindings: View {
  @Bindable var model: SettingsModel
  var zone: Zone
  /// Hairlines around the rows (a whole zone); a segment group is spaced, not ruled.
  var rules: Bool

  var body: some View {
    let rows = model.inspectorRows(for: zone)
    let drafts = model.inspectorDrafts
    let open = model.openBinding(in: zone, rows: rows)
    let pending = pendingGesture(rows: rows)
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 12) {
        ForEach(rows) { row in
          let key = InspectorDrafts.Key(profile: model.selectedProfile, binding: row.id)
          BindingRowView(
            model: model, row: row,
            isPicking: model.picking == PickerTarget(zone: zone, gesture: row.gesture),
            isOpen: open == row.id,
            autofocus: drafts.focus == key)
        }
        if let pending { PendingRowView(gesture: pending) }
      }
      if rules, !rows.isEmpty || pending != nil { InspectorRule().padding(.vertical, 10) }
      if !model.unmappedGestures(for: zone).isEmpty {
        Button {
          drafts.open = nil
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
        .padding(.top, rules || (rows.isEmpty && pending == nil) ? 0 : 4)
      }
      TapNotes(model: model, zone: zone, rows: rows).padding(.top, rules ? 14 : 4)
    }
    .onChange(of: drafts.focus) { _, focus in
      // The focused field has drawn; one handoff per choice.
      guard focus != nil else { return }
      DispatchQueue.main.async { drafts.focus = nil }
    }
  }

  /// While the picker is open for a gesture this zone doesn't have yet, that gesture's row shows
  /// with a blank value (bone 6; batch-14 design answer 4). It goes away if the picker closes
  /// without a choice.
  private func pendingGesture(rows: [InspectorRow]) -> GestureKind? {
    guard let target = model.picking, target.zone == zone, let gesture = target.gesture else { return nil }
    return rows.contains { $0.gesture == gesture } ? nil : gesture
  }
}

/// The row of a gesture being chosen in the picker: gesture icon and name, value blank.
struct PendingRowView: View {
  var gesture: GestureKind

  var body: some View {
    HStack(spacing: 10) {
      GestureIcon(gesture: gesture)
      Text(GestureNaming.name(gesture)).foregroundStyle(Tokens.ink)
      Spacer(minLength: 8)
    }
    .font(Tokens.font(Tokens.typeBody))
    .frame(minHeight: 28)
    .padding(.horizontal, 6)
    .background(RoundedRectangle(cornerRadius: Tokens.radiusControl).fill(Tokens.bar.opacity(0.35)))
    .padding(.horizontal, -6)
  }
}

/// One mapped gesture: icon, gesture, action in plain text, source marks (§ App profiles rows),
/// the "…" menu, issue lines, then its parameter rows.
struct BindingRowView: View {
  @Bindable var model: SettingsModel
  var row: InspectorRow
  var isPicking: Bool
  /// The one open binding: only it shows its parameter rows (§ Binding parameters).
  var isOpen = false
  var autofocus: Bool

  private static let textInset = GestureIcon.size + 10

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 10) {
        GestureIcon(gesture: row.gesture)
        Text(GestureNaming.name(row.gesture)).foregroundStyle(Tokens.ink).lineLimit(1).fixedSize()
        Spacer(minLength: 8)
        // While the picker is open the value is blank: its header already says it (bone 6).
        // One line: the gesture name stays whole; a long action name shortens (the inspector's
        // "…" for a cut is the system's; the pad never uses one).
        if !isPicking { value.lineLimit(1) }
        RowMenu(model: model, row: row)
      }
      .font(Tokens.font(Tokens.typeBody))
      .frame(minHeight: 28)
      .padding(.horizontal, 6)
      .background(
        RoundedRectangle(cornerRadius: Tokens.radiusControl).fill(isPicking ? Tokens.bar.opacity(0.35) : .clear)
      )
      .contentShape(Rectangle())
      .onTapGesture { model.openRow(row.id) }
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

      if row.showsParameters, isOpen {
        // Indented 24 pt under the binding row (§ Binding parameters → One rule).
        ParameterRowsView(model: model, row: row, autofocus: autofocus)
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
      guard issue.severity != .info else { return nil }  // notes have their own lines
      switch issue.code {
      case .overlappingZones, .missingParameter: return nil
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

  /// The items, in order, with whether each applies.
  static func items(for source: EffectiveBinding.Source?) -> [(title: String, enabled: Bool)] {
    switch source {
    case nil, .appOnly: return [("Change action…", true), ("Remove gesture", true)]
    case .inherited, .overridden, .turnedOff:
      return [
        ("Change action…", true), ("Turn off here", source != .turnedOff),
        ("Revert to Default", source != .inherited),
      ]
    }
  }

  var body: some View {
    let drafts = model.inspectorDrafts
    // A popover list, not a system `Menu`, so a note's fix can open it (BRIEF: "opens its … menu").
    Button {
      drafts.openMenu = row.id
    } label: {
      Image(systemName: "ellipsis").foregroundStyle(Tokens.ink2).frame(width: 20, height: 20)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("More for \(GestureNaming.name(row.gesture))")
    .popover(
      isPresented: SwiftUI.Binding(
        get: { drafts.openMenu == row.id }, set: { if !$0, drafts.openMenu == row.id { drafts.openMenu = nil } }),
      arrowEdge: .bottom
    ) {
      VStack(alignment: .leading, spacing: 2) {
        ForEach(Self.items(for: row.source), id: \.title) { item in
          Button {
            drafts.openMenu = nil
            perform(item.title)
          } label: {
            Text(item.title).font(Tokens.font(Tokens.typeBody))
              .foregroundStyle(item.enabled ? Tokens.ink : Tokens.ink2)
              .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading).contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .disabled(!item.enabled)
        }
      }
      .padding(8)
      .frame(width: 180)
    }
  }

  private func perform(_ title: String) {
    switch title {
    case "Change action…": model.openRow(row.id)
    case "Remove gesture": model.remove(row)
    case "Turn off here": model.turnOff(row)
    default: model.revert(row)
    }
  }
}

/// Bone 7 pattern: informational notes (info icon, `ink2`) with their one inline fix. The tap-waits
/// note, batch 20's slide-plus-swipes note, and any other `.info` code by its detail.
private struct TapNotes: View {
  @Bindable var model: SettingsModel
  var zone: Zone
  var rows: [InspectorRow]

  var body: some View {
    let notes = model.interactionNotes(for: zone, rows: rows)
    VStack(alignment: .leading, spacing: 10) {
      ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
        IssueLine(style: .info, text: note.text) {
          if let fix = note.fix {
            TextAction(title: fix.title) { model.apply(fix) }
          }
        }
      }
    }
  }
}

/// One informational note and its fix.
struct InteractionNote: Equatable {
  enum Fix: Equatable {
    case useLongPress(BindingKey)
    /// Select the swipe row and open its "…" menu (nothing is removed automatically).
    case openMenu(BindingKey)

    var title: String {
      switch self {
      case .useLongPress: return IssueCopy.useLongPress
      case .openMenu: return IssueCopy.moveSwipes
      }
    }
  }

  var text: String
  var fix: Fix?
}

extension SettingsModel {
  /// Info notes on this zone's bindings, said once each.
  func interactionNotes(for zone: Zone, rows: [InspectorRow]) -> [InteractionNote] {
    let issues = rows.flatMap { inspectorIssues(for: $0.id) }.filter { $0.severity == .info }
    let longPressFree = !rows.contains { $0.gesture == .longPress && $0.source != .turnedOff }
    var notes: [InteractionNote] = []
    for issue in issues {
      guard let text = IssueCopy.note(for: issue), !notes.contains(where: { $0.text == text }) else { continue }
      var fix: InteractionNote.Fix?
      if issue.code == .tapWaitsForDoubleTap, longPressFree, let key = issue.binding {
        fix = .useLongPress(key)
      } else if issue.code.rawValue == IssueCopy.slideAndSwipesCode,
        let swipe = rows.first(where: { if case .swipe = $0.gesture { return true } else { return false } })
      {
        fix = .openMenu(swipe.id)
      }
      notes.append(InteractionNote(text: text, fix: fix))
    }
    return notes
  }

  func apply(_ fix: InteractionNote.Fix) {
    switch fix {
    case .useLongPress(let key): useLongPressInstead(for: key)
    case .openMenu(let key):
      selectedZone = key.zone
      inspectorDrafts.openMenu = key
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
