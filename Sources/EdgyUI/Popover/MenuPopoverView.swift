import EdgyCore
import EdgyRuntime
import SwiftUI

/// The menu-bar popover: mini mirror, profile chips, Enabled + Test Mode, plain list (bone 10,
/// § System states, § Issue states, § Test Mode: what it does).
///
/// Facts the model doesn't carry (the Test Mode switch, Accessibility, the frontmost app, the
/// clock) come from a `MenuBarState` in the environment (`.environment(state)`); the list's
/// commands come from `\.menuBarActions`. Without them it shows a fresh state and does nothing,
/// which is what previews want.
public struct MenuPopoverView: View {
  @Bindable var model: SettingsModel
  @Environment(MenuBarState.self) private var injected: MenuBarState?
  @Environment(\.menuBarActions) private var actions
  @State private var fallback = MenuBarState()

  public init(model: SettingsModel) {
    self.model = model
  }

  private var state: MenuBarState { injected ?? fallback }

  public var body: some View {
    let _ = model.revision  // chips, switches and the mirror follow edits made in Settings
    VStack(alignment: .leading, spacing: 0) {
      top
        .padding(.horizontal, PopoverMetrics.inset)
        .padding(.top, PopoverMetrics.inset)
      PopoverSeparator()
      MenuListView(
        model: model, rows: MenuRow.visible(paused: model.engineStatus.paused), actions: actions, now: state.now
      )
      .padding(.horizontal, PopoverMetrics.listInset)
      .padding(.bottom, PopoverMetrics.listInset)
    }
    .frame(width: PopoverMetrics.width)
    .font(Tokens.font(Tokens.typeBody))
    .foregroundStyle(Tokens.ink)
    .background(Tokens.windowTint.opacity(Tokens.windowTintOpacity))
  }

  // MARK: Top half

  @ViewBuilder private var top: some View {
    switch PopoverTop.resolve(state: state, model: model) {
    // The block replaces the mini mirror and chips only; Enabled and Test Mode stay under it, so
    // "Touches still show in Test Mode." points at a real switch (batch-17 design answer 2).
    case .brokenConfig(let problem):
      VStack(alignment: .leading, spacing: 0) {
        IssueBlock(symbol: "exclamationmark.circle", text: problem.sentence, detail: nil) {
          // Recovery only; the file watcher reloads on save, so there's no Reload (bone 10).
          Button("Open config file") { actions.openConfigFile() }
        }
        switches
      }
    case .needsAccessibility:
      VStack(alignment: .leading, spacing: 0) {
        IssueBlock(
          symbol: "info.circle", text: PopoverCopy.noAccessibility, detail: PopoverCopy.noAccessibilityDetail
        ) {
          Button("Open Settings") { actions.openAccessibilitySettings() }
        }
        switches
      }
    case .normal(let mirror):
      VStack(alignment: .leading, spacing: PopoverMetrics.rowGap) {
        miniMirror(mirror)
        if mirror.paused, !mirror.noTrackpad {
          pausedLine(until: mirror.pausedUntil)
        }
        chips
        switches
      }
    }
  }

  @ViewBuilder private func miniMirror(_ mirror: PopoverMirror) -> some View {
    if mirror.noTrackpad {
      NoTrackpadPad()
    } else {
      let size = PopoverMetrics.padSize(model.mirroredDevice)
      // The chips and the mirror share one source for the app in front; the popover owns the one
      // 40% fade (Disabled, Paused, off in the app in front).
      MiniMirrorView(model: model, frontmostApp: state.frontmost(model: model))
        .fadedByHost()
        .frame(width: size.width, height: size.height)
        .opacity(mirror.faded ? PopoverMetrics.fadedOpacity : 1)
        .frame(maxWidth: .infinity)
    }
  }

  private func pausedLine(until: Date?) -> some View {
    TimelineView(.periodic(from: .now, by: 15)) { _ in
      HStack {
        Text(PopoverCopy.paused(until: until, now: state.now()))
        Spacer(minLength: 12)
        Button("Resume") { model.resume() }.buttonStyle(TextButtonStyle())
      }
    }
  }

  private var chips: some View {
    ChipFlow(spacing: PopoverMetrics.chipGap) {
      ForEach(ProfileChip.chips(model: model, frontmost: state.frontmost(model: model), apps: state.installedApps)) {
        chip in
        ChipView(chip: chip) {
          model.selectProfile(chip.ref)
          actions.openSettings()
        }
      }
    }
  }

  private var switches: some View {
    VStack(alignment: .leading, spacing: PopoverMetrics.rowGap) {
      SwitchRow(
        title: "Enabled",
        isOn: SwiftUI.Binding(
          get: {
            _ = model.revision
            return model.editor.config.app.enabled
          }, set: model.setEnabled))
      SwitchRow(
        title: "Test Mode", isOn: SwiftUI.Binding(get: { state.testMode }, set: { state.setTestMode($0, model: model) })
      )
      if state.showsDontRunActions {
        Toggle(
          PopoverCopy.dontRunActions,
          isOn: SwiftUI.Binding(get: { state.dontRunActions }, set: { state.setDontRunActions($0, model: model) })
        )
        .toggleStyle(.checkbox)
        .tint(Tokens.ink)
        .padding(.leading, PopoverMetrics.indent)
      }
    }
    .padding(.bottom, PopoverMetrics.rowGap)
  }
}

extension SettingsModel {
  static let popoverLog = SystemLogger(category: "popover")

  /// The popover's global **Enabled** switch (always global, whatever tab the window has open).
  public func setEnabled(_ on: Bool) {
    do {
      try editor.updateAppSettings { $0.enabled = on }
    } catch {
      Self.popoverLog.log(.error, "enabled refused: \(error)")
    }
  }
}

// MARK: Parts

/// Popover layout (sizes only; colour, type and radii live in `Tokens`).
enum PopoverMetrics {
  static let inset: CGFloat = 16
  static let listInset: CGFloat = 6
  static let rowGap: CGFloat = 12
  static let chipGap: CGFloat = 8
  /// "Don't run actions" sits indented under Test Mode (§ Test Mode).
  static let indent: CGFloat = 24
  static let fadedOpacity: Double = 0.4
  /// The default pad proportion for "No trackpad" (an external trackpad's sensor).
  static let defaultPadMM = CGSize(width: 160, height: 115)
  static let width = defaultPadMM.width * Tokens.miniMirrorPointsPerMM + 2 * inset

  /// The mini mirror's frame: the pad to scale (bone 1), at the popover's points per mm.
  static func padSize(_ device: TouchDeviceInfo?) -> CGSize {
    let mm = device.map { CGSize(width: $0.sensorSizeMM.width, height: $0.sensorSizeMM.height) } ?? defaultPadMM
    return CGSize(width: mm.width * Tokens.miniMirrorPointsPerMM, height: mm.height * Tokens.miniMirrorPointsPerMM)
  }
}

struct PopoverSeparator: View {
  var body: some View {
    Tokens.line.opacity(0.35).frame(height: 1).padding(.horizontal, PopoverMetrics.inset)
  }
}

/// No trackpad: a dashed pad outline at the default proportion with one line inside.
struct NoTrackpadPad: View {
  var body: some View {
    let size = PopoverMetrics.padSize(nil)
    RoundedRectangle(cornerRadius: Tokens.radiusPlate)
      .strokeBorder(Tokens.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
      .overlay { Text(PopoverCopy.noTrackpad).foregroundStyle(Tokens.ink) }
      .frame(width: size.width, height: size.height)
      .frame(maxWidth: .infinity)
  }
}

/// The block that replaces the top half (No Accessibility, broken config): icon, sentence,
/// buttons, an optional `ink2` line under them.
struct IssueBlock<Buttons: View>: View {
  let symbol: String
  let text: String
  let detail: String?
  @ViewBuilder let buttons: Buttons

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Image(systemName: symbol).foregroundStyle(Tokens.ink)
      VStack(alignment: .leading, spacing: 10) {
        Text(text).fixedSize(horizontal: false, vertical: true)
        HStack(spacing: 8) { buttons }.buttonStyle(.bordered)
        if let detail { Text(detail).foregroundStyle(Tokens.ink2) }
      }
      Spacer(minLength: 0)
    }
    .padding(.bottom, PopoverMetrics.inset)
  }
}

struct SwitchRow: View {
  let title: String
  @SwiftUI.Binding var isOn: Bool

  var body: some View {
    HStack {
      Text(title).font(Tokens.font(Tokens.typeBody))
      Spacer(minLength: 12)
      Toggle(title, isOn: $isOn).toggleStyle(.switch).labelsHidden().tint(Tokens.accent)
    }
  }
}

/// A profile chip: filled `ink` when it's the profile in effect, outlined otherwise.
struct ChipView: View {
  let chip: ProfileChip
  let open: () -> Void

  var body: some View {
    Button(action: open) {
      HStack(spacing: 5) {
        if chip.isOff {
          Image(systemName: "circle.slash").foregroundStyle(Tokens.ink2)
        } else {
          AppMark(path: chip.appPath)
        }
        Text(chip.name)
          .font(Tokens.font(Tokens.typeBody, semibold: chip.isLive))
          .foregroundStyle(chip.isLive ? Tokens.windowTint : (chip.isOff ? Tokens.ink2 : Tokens.ink))
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 5)
      .background(Capsule().fill(chip.isLive ? Tokens.ink : Color.clear))
      .overlay(Capsule().strokeBorder(chip.isLive ? Color.clear : Tokens.line.opacity(0.6), lineWidth: 1))
      .clipShape(Capsule())
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .help("Open \(chip.name) in Settings")
  }
}

/// Lays chips out left to right, wrapping to a new line when the row is full.
struct ChipFlow: Layout {
  var spacing: CGFloat

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
    let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
    let width = rows.map(\.width).max() ?? 0
    return CGSize(width: proposal.width ?? width, height: height)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    var y = bounds.minY
    for row in arrange(width: bounds.width, subviews: subviews) {
      var x = bounds.minX
      for index in row.indices {
        let size = subviews[index].sizeThatFits(.unspecified)
        subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
        x += size.width + spacing
      }
      y += row.height + spacing
    }
  }

  private struct Row {
    var indices: [Int] = []
    var width: CGFloat = 0
    var height: CGFloat = 0
  }

  private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
    var rows: [Row] = [Row()]
    for (index, subview) in subviews.enumerated() {
      let size = subview.sizeThatFits(.unspecified)
      let extra = rows[rows.count - 1].indices.isEmpty ? size.width : size.width + spacing
      if rows[rows.count - 1].width + extra > width, !rows[rows.count - 1].indices.isEmpty {
        rows.append(Row())
      }
      let last = rows.count - 1
      rows[last].width += rows[last].indices.isEmpty ? size.width : size.width + spacing
      rows[last].height = max(rows[last].height, size.height)
      rows[last].indices.append(index)
    }
    return rows.filter { !$0.indices.isEmpty }
  }
}
