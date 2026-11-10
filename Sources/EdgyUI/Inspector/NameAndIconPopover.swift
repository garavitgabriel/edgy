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

      ScrollView(.vertical) {
        VStack(alignment: .leading, spacing: 0) {
          ForEach(Array(Self.groups(model: model).enumerated()), id: \.element.title) { index, group in
            Text(group.title)
              .font(Tokens.font(Tokens.typeSmall, semibold: true))
              .foregroundStyle(Tokens.ink2)
              .padding(.top, index == 0 ? 0 : 14)
              .padding(.bottom, 4)
            LazyVGrid(columns: Self.columns, alignment: .leading, spacing: 0) {
              ForEach(group.ids, id: \.self) { id in iconCell(id) }
            }
          }
        }
        .padding(.vertical, 12)
      }
      .frame(maxHeight: 300)

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

  static let columns = Array(repeating: GridItem(.fixed(cell), spacing: 0), count: 10)

  private func iconCell(_ id: ActionID) -> some View {
    let selected = id == selectedIcon
    let own = id == row.binding.action
    return Button {
      save(icon: id, close: false)
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
    .help(own ? "Default" : model.actionName(id))
    .accessibilityLabel(own ? "Default" : model.actionName(id))
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  /// The icon library, grouped and ordered like the picker: catalog groups in order, icon-table
  /// order within each, only IDs the icon family draws ("Do nothing" has none to offer).
  struct Group: Equatable {
    var title: String
    var ids: [ActionID]
  }

  static func groups(model: SettingsModel) -> [Group] {
    model.mirrorGroups.compactMap { group in
      let ids = PickerCatalog.ordered(group.actions).map(\.id).filter { $0 != .doNothing && ActionIcons.has($0) }
      guard !ids.isEmpty else { return nil }
      return Group(title: PickerCatalog.Section(category: group.category, items: []).title, ids: ids)
    }
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
