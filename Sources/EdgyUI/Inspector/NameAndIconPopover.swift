import EdgyCore
import EdgyRuntime
import SwiftUI

// Batch 29: the user's own name and icon for a binding (BRIEF § Binding parameters → "Your own
// name and icon for a binding"). Presentation only; the picker always shows real actions.

/// The row's "Name and Icon…" popover: a Name field (placeholder = the action's own name, focused
/// on open, Return saves), the icon grid (16 pt icons in 28 pt cells, grouped and ordered like the
/// picker with its 11 pt headers, an `ink` ring on the selected cell, "Default" on the action's
/// own), and "Reset name and icon" (quiet `ink2`) only while either is set. One column, ≤ 320 pt.
struct NameAndIconPopover: View {
  @Bindable var model: SettingsModel
  var row: InspectorRow
  @State private var name: String
  @FocusState private var nameFocused: Bool

  static let width: CGFloat = 320
  static let cell: CGFloat = 28
  static let iconSize: CGFloat = 16

  init(model: SettingsModel, row: InspectorRow) {
    self.model = model
    self.row = row
    _name = State(initialValue: row.binding.customName ?? "")
  }

  private var ownName: String { model.actionName(row.binding.action) }
  private var selectedIcon: ActionID { BindingNaming.iconID(row.binding) }
  private var isSet: Bool { row.binding.customName != nil || row.binding.customIcon != nil }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("Name").font(Tokens.font(Tokens.typeBody)).foregroundStyle(Tokens.ink2)
        .padding(.bottom, 4)
      TextField("", text: $name, prompt: Text(ownName).foregroundStyle(Tokens.ink2))
        .textFieldStyle(.plain)
        .font(Tokens.font(Tokens.typeBody))
        .foregroundStyle(Tokens.ink)
        .modifier(FieldChrome())
        .focused($nameFocused)
        .onSubmit { save(icon: row.binding.customIcon, close: true) }
        .onChange(of: name) { _, new in
          if new.count > SettingsEditor.customNameLimit { name = String(new.prefix(SettingsEditor.customNameLimit)) }
        }
        .accessibilityLabel("Name")

      ScrollViewReader { proxy in
        ScrollView(.vertical) {
          VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(groups.enumerated()), id: \.element.title) { index, group in
              Text(group.title)
                .font(Tokens.font(Tokens.typeSmall, semibold: true))
                .foregroundStyle(Tokens.ink2)
                .padding(.top, index == 0 ? 0 : 14)
                .padding(.bottom, 4)
              // Not lazy: every cell exists on open, so the selected one can be scrolled to.
              Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                ForEach(Self.rows(group.ids), id: \.self) { row in
                  GridRow { ForEach(row, id: \.self) { id in iconCell(id).id(id) } }
                }
              }
            }
          }
          .padding(.vertical, 12)
        }
        .frame(maxHeight: 300)
        // The selected cell in view on open, like the picker's checked row (critique 29 should-fix 2).
        .onAppear { proxy.scrollTo(Self.cell(for: selectedIcon, in: groups), anchor: .center) }
      }

      if isSet {
        Button("Reset name and icon") { reset() }
          .buttonStyle(.plain)
          .font(Tokens.font(Tokens.typeBody))
          .foregroundStyle(Tokens.ink2)
          .padding(.top, 4)
      }
    }
    .padding(12)
    .frame(width: Self.width)
    .onAppear { nameFocused = true }
    .onDisappear { saveNameIfChanged() }
  }

  static let columnCount = 10

  /// `ids` in rows of `columnCount`.
  static func rows(_ ids: [ActionID]) -> [[ActionID]] {
    stride(from: 0, to: ids.count, by: columnCount).map { Array(ids[$0..<min($0 + columnCount, ids.count)]) }
  }

  private var groups: [Group] { Self.groups(model: model) }

  private func iconCell(_ id: ActionID) -> some View {
    let sharing = Self.sharing(id, in: groups)
    let selected = id == Self.cell(for: selectedIcon, in: groups)
    let own = sharing.contains(row.binding.action)
    return Button {
      // A shared cell on the action's own drawing is the default, not a custom icon.
      save(icon: own ? row.binding.action : id, close: false)
    } label: {
      ActionIcon(id: id, size: Self.iconSize)
        .foregroundStyle(Tokens.ink)
        .frame(width: Self.cell, height: Self.cell)
        .overlay {
          if selected {
            RoundedRectangle(cornerRadius: Tokens.radiusControl).strokeBorder(Tokens.ink, lineWidth: 1.5)
          }
        }
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .help(own ? "Default" : Self.tooltip(sharing, model: model))
    .accessibilityLabel(own ? "Default" : Self.tooltip(sharing, model: model))
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  /// The icon library, grouped and ordered like the picker: catalog groups in order, icon-table
  /// order within each, only IDs the icon family draws ("Do nothing" has none to offer).
  ///
  /// Each drawing appears once (critique 29 design answer 4): an action whose drawing an earlier
  /// cell already shows joins that cell (`shared`), whose tooltip names both.
  struct Group: Equatable {
    var title: String
    var ids: [ActionID]
    /// Every action a cell stands for, the cell's own first, for cells drawn by more than one.
    var shared: [ActionID: [ActionID]] = [:]
  }

  static func groups(model: SettingsModel) -> [Group] {
    var seen: [(drawing: IconDrawing, cell: ActionID)] = []
    var groups: [Group] = []
    for group in model.mirrorGroups {
      var result = Group(title: PickerCatalog.Section(category: group.category, items: []).title, ids: [])
      for id in PickerCatalog.ordered(group.actions).map(\.id) where id != .doNothing {
        guard let drawing = ActionIcons.drawing(for: id) else { continue }
        if let twin = seen.first(where: { $0.drawing == drawing })?.cell {
          for index in groups.indices where groups[index].ids.contains(twin) {
            groups[index].shared[twin, default: [twin]].append(id)
          }
          if result.ids.contains(twin) { result.shared[twin, default: [twin]].append(id) }
          continue
        }
        seen.append((drawing, id))
        result.ids.append(id)
      }
      if !result.ids.isEmpty { groups.append(result) }
    }
    return groups
  }

  /// Every action the cell `id` stands for (just `id` unless its drawing is shared).
  static func sharing(_ id: ActionID, in groups: [Group]) -> [ActionID] {
    groups.lazy.compactMap { $0.shared[id] }.first ?? [id]
  }

  /// The cell that shows `icon`: its own, or the cell it shares a drawing with.
  static func cell(for icon: ActionID, in groups: [Group]) -> ActionID {
    for group in groups {
      if group.ids.contains(icon) { return icon }
      if let cell = group.shared.first(where: { $0.value.contains(icon) })?.key { return cell }
    }
    return icon
  }

  /// "Keyboard Brightness", or both names for a shared drawing: "Keyboard Brightness and
  /// Keyboard Backlight On/Off".
  static func tooltip(_ sharing: [ActionID], model: SettingsModel) -> String {
    sharing.map { model.actionName($0) }.joined(separator: " and ")
  }

  private func save(icon: ActionID?, close: Bool) {
    model.setNameAndIcon(row, name: name, icon: icon)
    if close { model.inspectorDrafts.naming = nil }
  }

  private func saveNameIfChanged() {
    let current = row.binding.customName ?? ""
    guard
      SettingsEditor.customName(name, actionName: ownName) != SettingsEditor.customName(current, actionName: ownName)
    else { return }
    // The popover may close with the row already re-read; use the model's current binding.
    model.setNameAndIcon(row, name: name, icon: nil, keepIcon: true)
  }

  private func reset() {
    name = ""
    model.setNameAndIcon(row, name: nil, icon: nil)
  }
}

extension SettingsModel {
  /// Saves the row's name and icon as one undo step (`SettingsEditor.setNameAndIcon`). On an app
  /// tab an inherited row becomes an override. `keepIcon`: leave the current custom icon as it is.
  func setNameAndIcon(_ row: InspectorRow, name: String?, icon: ActionID?, keepIcon: Bool = false) {
    let current = editor.effectiveBindings(forApp: inspectorProfile.bundleID).first { $0.binding.key == row.id }?
      .binding
    let icon = keepIcon ? current?.customIcon : icon
    try? editor.setNameAndIcon(
      row.id, in: inspectorProfile, name: name, icon: icon,
      library: BindingNaming.library(catalog: Array(mirrorCatalog.values)))
  }
}

extension ProfileRef {
  fileprivate var bundleID: String? {
    if case .app(let id) = self { return id }
    return nil
  }
}
