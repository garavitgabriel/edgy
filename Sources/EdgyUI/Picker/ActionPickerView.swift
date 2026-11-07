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
              GestureIcon(gesture: gesture)
              Text(GestureNaming.name(gesture)).foregroundStyle(Tokens.ink)
              Spacer()
            }
            .font(Tokens.font(Tokens.typeBody))
            .padding(.horizontal, 8).frame(minHeight: 28).contentShape(Rectangle())
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  // MARK: Actions

  private func actions(zone: Zone, gesture: GestureKind) -> some View {
    let catalog = PickerCatalog(
      groups: model.editor.catalogByCategory, gesture: gesture, query: query,
      isAppTab: model.selectedProfile != .default, availability: model.editor.availability(of:))
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
          LazyVStack(alignment: .leading, spacing: 2) {
            ForEach(catalog.sections) { section in
              Text(section.title)
                .font(Tokens.font(Tokens.typeSmall, semibold: true))
                .foregroundStyle(Tokens.ink2)
                .padding(.horizontal, 8).padding(.top, 8).padding(.bottom, 2)
              ForEach(section.items) { item in
                PickerRow(
                  item: item, isMarked: (highlighted ?? current) == item.id, enabled: true
                ) { model.choose(item.id, zone: zone, gesture: gesture) }
                .id(item.id)
              }
            }
            if let title = catalog.othersTitle {
              InspectorRule().padding(.vertical, 6)
              Button {
                showOthers.toggle()
              } label: {
                HStack(spacing: 6) {
                  Image(systemName: showOthers ? "chevron.down" : "chevron.right").frame(width: 12)
                  Text(title)
                }
                .font(Tokens.font(Tokens.typeBody)).foregroundStyle(Tokens.ink2)
                .padding(.horizontal, 8).frame(minHeight: 28).contentShape(Rectangle())
              }
              .buttonStyle(.plain)
              if showOthers || !query.isEmpty {
                ForEach(catalog.others) { item in
                  PickerRow(item: item, isMarked: false, enabled: false) {}
                }
              }
            }
            if catalog.offersDoNothing {
              InspectorRule().padding(.vertical, 6)
              PickerRow(
                title: "Do nothing here", subtitle: nil, dimmed: false,
                isMarked: highlighted == .doNothing, enabled: true
              ) { model.choose(.doNothing, zone: zone, gesture: gesture) }
              .id(ActionID.doNothing)
            }
          }
        }
        .onChange(of: highlighted) { _, id in
          if let id { proxy.scrollTo(id) }
        }
      }
    }
    .onAppear { searchFocused = true }
  }

  private func move(_ step: Int, in ids: [ActionID], from current: ActionID?) -> KeyPress.Result {
    guard !ids.isEmpty else { return .ignored }
    let start = (highlighted ?? current).flatMap(ids.firstIndex(of:)) ?? (step > 0 ? -1 : ids.count)
    highlighted = ids[min(max(start + step, 0), ids.count - 1)]
    return .handled
  }
}

/// One picker row: the name, and a 13 pt second line for an unavailable reason or a limited
/// note. Unavailable rows are dimmed (`ink2`) but still selectable.
struct PickerRow: View {
  var title: String
  var subtitle: String?
  var dimmed: Bool
  var isMarked: Bool
  var enabled: Bool
  var action: () -> Void

  init(item: PickerCatalog.Item, isMarked: Bool, enabled: Bool, action: @escaping () -> Void) {
    self.init(
      title: item.title, subtitle: item.subtitle, dimmed: item.isDimmed || !enabled, isMarked: isMarked,
      enabled: enabled, action: action)
  }

  init(
    title: String, subtitle: String?, dimmed: Bool, isMarked: Bool, enabled: Bool, action: @escaping () -> Void
  ) {
    self.title = title
    self.subtitle = subtitle
    self.dimmed = dimmed
    self.isMarked = isMarked
    self.enabled = enabled
    self.action = action
  }

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 1) {
        Text(title).foregroundStyle(dimmed ? Tokens.ink2 : Tokens.ink)
        if let subtitle {
          Text(subtitle).foregroundStyle(Tokens.ink2).lineLimit(3).fixedSize(horizontal: false, vertical: true)
        }
      }
      .font(Tokens.font(Tokens.typeBody))
      .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
      .padding(.horizontal, 8).padding(.vertical, 2)
      .background(
        RoundedRectangle(cornerRadius: Tokens.radiusControl).fill(isMarked ? Tokens.bar.opacity(0.4) : .clear)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .allowsHitTesting(enabled)  // not `.disabled`: that fades `ink2` below 4.5:1
  }
}
