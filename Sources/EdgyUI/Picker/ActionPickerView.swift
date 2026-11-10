import EdgyCore
import EdgyRuntime
import SwiftUI

/// The action picker popover content for `model.picking` (bone 5, § Picker at catalog scale):
/// header naming what it sets, search pinned and focused, one scrolling column of groups in
/// catalog order, shape-incompatible actions in one disclosure at the end, "Do nothing here" last
/// on app tabs. Choosing writes through the editor (`SettingsModel.choose`).
///
/// For "Add gesture…" (`picking.gesture == nil`) it first lists the zone's free gestures.
/// Present it anchored to its zone with `.actionPickerHost(model:)` (see `PickerPopover.swift`).
public struct ActionPickerView: View {
  @Bindable var model: SettingsModel
  @State private var query: String
  @State private var chosenGesture: GestureKind?
  @State private var showOthers: Bool
  @State private var highlighted: ActionID?
  @FocusState private var searchFocused: Bool

  public init(model: SettingsModel) {
    self.init(model: model, query: "")
  }

  /// For previews and snapshot tests: open with a search typed, or the disclosure expanded.
  init(model: SettingsModel, query: String, showOthers: Bool = false) {
    self.model = model
    _query = State(initialValue: query)
    _showOthers = State(initialValue: showOthers)
  }

  public var body: some View {
    let _ = model.revision
    if let target = model.picking {
      let gesture = target.gesture ?? chosenGesture
      VStack(alignment: .leading, spacing: 10) {
        Text(GestureNaming.pickerHeader(gesture: gesture, zone: target.zone))
          .font(Tokens.font(Tokens.typeBody, semibold: true))
          .foregroundStyle(Tokens.ink)
          .accessibilityAddTraits(.isHeader)
        if let gesture {
          actions(zone: target.zone, gesture: gesture)
        } else {
          gestures(zone: target.zone)
        }
      }
      .padding(12)
      .frame(maxWidth: PickerPlacement.maxWidth, maxHeight: .infinity, alignment: .topLeading)
      .onExitCommand { model.picking = nil }
    }
  }

  // MARK: Gestures (Add gesture…)

  private func gestures(zone: Zone) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 2) {
        ForEach(model.unmappedGestures(for: zone), id: \.self) { gesture in
          Button {
            chosenGesture = gesture
          } label: {
            HStack(spacing: 10) {
              GestureIcon(gesture: gesture, zone: zone)
              Text(GestureNaming.name(gesture)).foregroundStyle(Tokens.ink)
              Spacer()
            }
            .font(Tokens.font(Tokens.typeBody))
            .padding(.horizontal, 8).frame(minHeight: 28).contentShape(Rectangle())
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.bottom, PickerScrollEdge.inset)
    }
    .mask(PickerScrollEdge())
  }

  // MARK: Actions

  private func actions(zone: Zone, gesture: GestureKind) -> some View {
    let catalog = PickerCatalog(
      groups: model.mirrorGroups, gesture: gesture, query: query,
      isAppTab: model.selectedProfile != .default, availability: model.mirrorAvailability(of:))
    let current = model.inspectorRows(for: zone).first { $0.gesture == gesture && $0.source != .turnedOff }?
      .binding.action
    let selectable = catalog.selectable.map(\.id) + (catalog.offersDoNothing ? [ActionID.doNothing] : [])
    return VStack(alignment: .leading, spacing: 8) {
      SearchField(text: $query, prompt: "Search actions")
        .focused($searchFocused)
        .onKeyPress(.downArrow) { move(1, in: selectable, from: current) }
        .onKeyPress(.upArrow) { move(-1, in: selectable, from: current) }
        .onKeyPress(.return) {
          guard let id = highlighted ?? selectable.first else { return .ignored }
          model.choose(id, zone: zone, gesture: gesture)
          return .handled
        }
        .onChange(of: query) { highlighted = nil }
      ScrollViewReader { proxy in
        ScrollView {
          // Rhythm (§ Picker clarity): 11 pt headers, 14 above / 4 below, no separator lines; the
          // first group has no top space under the search field.
          VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(catalog.sections.enumerated()), id: \.element.id) { index, section in
              PickerGroupHeader(title: section.title, first: index == 0)
              ForEach(section.items) { item in
                PickerRow(
                  item: item, isBound: current == item.id, isHighlighted: highlighted == item.id, enabled: true
                ) { model.choose(item.id, zone: zone, gesture: gesture) }
                .id(item.id)
              }
            }
            if let title = catalog.othersTitle {
              // A search expands the section too; the chevron follows what's shown.
              let expanded = Self.othersExpanded(showOthers: showOthers, query: query)
              Button {
                showOthers.toggle()
              } label: {
                HStack(spacing: 0) {
                  Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    .frame(width: PickerRow.iconColumn, alignment: .leading)
                  Text(title)
                  Spacer(minLength: 0)
                }
                .font(Tokens.font(Tokens.typeBody)).foregroundStyle(Tokens.ink2)
                .padding(.horizontal, PickerRow.inset).frame(minHeight: PickerRow.height).contentShape(Rectangle())
              }
              .buttonStyle(.plain)
              .padding(.top, catalog.sections.isEmpty ? 0 : PickerGroupHeader.above)
              .accessibilityLabel(title)
              .accessibilityValue(expanded ? "Expanded" : "Collapsed")
              if expanded {
                ForEach(catalog.others) { item in
                  PickerRow(item: item, isBound: false, isHighlighted: false, enabled: false) {}
                }
              }
            }
            if catalog.offersDoNothing {
              // "Do nothing here": last, after a separator (§ Picker at catalog scale).
              InspectorRule().padding(.vertical, 6)
              PickerRow(
                icon: .doNothing, title: "Do nothing here", subtitle: nil, dimmed: false,
                isBound: current == .doNothing, isHighlighted: highlighted == .doNothing, enabled: true
              ) { model.choose(.doNothing, zone: zone, gesture: gesture) }
              .id(ActionID.doNothing)
            }
            if catalog.isEmpty, let message = PickerCatalog.noMatches(query) {
              Text(message)
                .font(Tokens.font(Tokens.typeBody)).foregroundStyle(Tokens.ink2)
                .padding(.horizontal, PickerRow.inset).frame(minHeight: PickerRow.height, alignment: .leading)
            }
          }
          // The list ends clear of the panel's edge: a bottom inset equal to the panel's top one,
          // and a 12 pt fade where rows scroll out (critique 22 should-fix 3).
          .padding(.bottom, PickerScrollEdge.inset)
        }
        .mask(PickerScrollEdge())
        .onChange(of: highlighted) { _, id in
          if let id { proxy.scrollTo(id) }
        }
        .onAppear {
          // On open the bound (checkmarked) row is visible; with nothing bound, the top.
          if let current { proxy.scrollTo(current, anchor: .center) }
        }
      }
    }
    .onAppear { searchFocused = true }
  }

  /// The disclosure is open when the user opened it or a search is typed.
  static func othersExpanded(showOthers: Bool, query: String) -> Bool {
    showOthers || !query.trimmingCharacters(in: .whitespaces).isEmpty
  }

  private func move(_ step: Int, in ids: [ActionID], from current: ActionID?) -> KeyPress.Result {
    guard !ids.isEmpty else { return .ignored }
    let start = (highlighted ?? current).flatMap(ids.firstIndex(of:)) ?? (step > 0 ? -1 : ids.count)
    highlighted = ids[min(max(start + step, 0), ids.count - 1)]
    return .handled
  }
}

/// A group header (§ Picker clarity: icons and rhythm): 11 pt semibold `ink2`, 14 pt above (none
/// for the first group) and 4 pt below. The only 11 pt type in the app.
struct PickerGroupHeader: View {
  var title: String
  var first: Bool

  static let above: CGFloat = 14
  static let below: CGFloat = 4

  var body: some View {
    Text(title)
      .font(Tokens.font(Tokens.typeSmall, semibold: true))
      .foregroundStyle(Tokens.ink2)
      .padding(.horizontal, PickerRow.inset)
      .padding(.top, first ? 0 : Self.above).padding(.bottom, Self.below)
      .accessibilityAddTraits(.isHeader)
  }
}

/// One picker row (§ Picker clarity): a 16 pt icon in a 24 pt column, the name (13), a trailing
/// `ink` checkmark on the action bound to this slot. 28 pt tall; with a sub-line (an unavailable
/// reason or a limited note, 13 `ink2`, aligned to the name) 44 pt. Unavailable rows draw icon and
/// name in `ink2` and stay selectable. The keyboard highlight and the hover share the 10% `ink` wash.
struct PickerRow: View {
  var icon: ActionID?
  var title: String
  var subtitle: String?
  var dimmed: Bool
  var isBound: Bool
  var isHighlighted: Bool
  var enabled: Bool
  var action: () -> Void
  @State private var hovering = false

  static let height: CGFloat = 28
  static let tallHeight: CGFloat = 44
  static let iconColumn: CGFloat = 24
  static let inset: CGFloat = 8

  init(item: PickerCatalog.Item, isBound: Bool, isHighlighted: Bool, enabled: Bool, action: @escaping () -> Void) {
    self.init(
      icon: item.id, title: item.title, subtitle: item.subtitle, dimmed: item.isDimmed || !enabled,
      isBound: isBound, isHighlighted: isHighlighted, enabled: enabled, action: action)
  }

  init(
    icon: ActionID?, title: String, subtitle: String?, dimmed: Bool, isBound: Bool, isHighlighted: Bool,
    enabled: Bool, action: @escaping () -> Void
  ) {
    self.icon = icon
    self.title = title
    self.subtitle = subtitle
    self.dimmed = dimmed
    self.isBound = isBound
    self.isHighlighted = isHighlighted
    self.enabled = enabled
    self.action = action
  }

  var body: some View {
    let colour = dimmed ? Tokens.ink2 : Tokens.ink
    Button(action: action) {
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 0) {
          Group {
            if let icon { ActionIcon(id: icon) }
          }
          .frame(width: Self.iconColumn, alignment: .leading)
          Text(title)
          Spacer(minLength: 8)
          if isBound {
            Image(systemName: "checkmark").font(Tokens.font(Tokens.typeBody, semibold: true))
              .foregroundStyle(Tokens.ink)
          }
        }
        .foregroundStyle(colour)
        if let subtitle {
          Text(subtitle).foregroundStyle(Tokens.ink2).lineLimit(3).fixedSize(horizontal: false, vertical: true)
            .padding(.leading, Self.iconColumn)
        }
      }
      .font(Tokens.font(Tokens.typeBody))
      .frame(maxWidth: .infinity, minHeight: subtitle == nil ? Self.height : Self.tallHeight, alignment: .leading)
      .padding(.horizontal, Self.inset)
      .background(
        RoundedRectangle(cornerRadius: Tokens.radiusControl)
          .fill(Tokens.ink.opacity((isHighlighted || (hovering && enabled)) ? 0.1 : 0))
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
    .allowsHitTesting(enabled)  // not `.disabled`: that fades `ink2` below 4.5:1
    .accessibilityAddTraits(isBound ? .isSelected : [])
  }
}

/// The picker list's lower scroll edge: opaque, then a 12 pt fade to clear at the very bottom.
struct PickerScrollEdge: View {
  /// Space under the last row: the panel's own top inset.
  static let inset: CGFloat = 12
  /// The fade's height (bone 3's 12 pt fade).
  static let fade: CGFloat = 12

  var body: some View {
    VStack(spacing: 0) {
      Rectangle()
      LinearGradient(colors: [.black, .black.opacity(0)], startPoint: .top, endPoint: .bottom)
        .frame(height: Self.fade)
    }
  }
}
