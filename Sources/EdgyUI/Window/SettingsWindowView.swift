import Actions
import EdgyCore
import EdgyRuntime
import SwiftUI

/// The settings window content: profile tabs, mirror, inspector, footer (§ Surfaces, § App profiles, § System states, § Issue states).
///
/// No sidebar. Profile tabs sit top centre in the title bar (Default, app tabs alphabetically, "+");
/// the top-right switch follows the tab; the mirror (`PadMirrorView`) is on the left, the inspector
/// (`InspectorView`) on the right; the footer holds Haptics, Launch at login, HUD and Advanced….
///
/// Host it in an `NSWindow` with a transparent, full-size-content title bar and
/// `minimumSize` as the content min size. Accessibility and a broken config file arrive through
/// `\.windowConditions`; the strip buttons call `\.windowCommands`.
public struct SettingsWindowView: View {
  @Bindable var model: SettingsModel
  @Environment(\.windowConditions) private var conditions
  @Environment(\.windowCommands) private var commands

  @State private var apps: [InstalledApp] = []
  @State private var addingApp = false
  @State private var showingAdvanced = false
  @State private var removing: String?
  @State private var confirmingReplace = false

  public init(model: SettingsModel) {
    self.model = model
  }

  /// With the installed apps already known (snapshots, previews): tab marks draw on first frame.
  init(model: SettingsModel, apps: [InstalledApp]) {
    self.model = model
    _apps = State(initialValue: apps)
  }

  /// Fits the larger (external) pad to scale beside the inspector, with room for a strip.
  public static var minimumSize: CGSize {
    let mirror = WindowMetrics.mirrorRegion(for: WindowMetrics.largestPadMM)
    return CGSize(
      width: (mirror.width + 1 + WindowMetrics.inspectorWidth).rounded(.up),
      height: (WindowMetrics.tabBarHeight + WindowMetrics.stripHeight + mirror.height + WindowMetrics.footerHeight)
        .rounded(.up))
  }

  public var body: some View {
    let _ = model.revision
    let status = WindowStatus.resolve(
      conditions: conditions, engine: model.engineStatus, config: model.editor.config, tab: model.selectedProfile)
    VStack(spacing: 0) {
      tabBar(readOnly: status.isReadOnly)
      if let strip = status.strip { stripView(strip) }
      HStack(spacing: 0) {
        mirrorColumn(status)
        Tokens.line.opacity(0.3).frame(width: 1)
        inspectorColumn(status)
      }
      .disabled(status.isReadOnly)
      .actionPickerHost(model: model)
      footer(readOnly: status.isReadOnly)
    }
    .font(Tokens.font(Tokens.typeBody))
    .foregroundStyle(Tokens.ink)
    .frame(minWidth: Self.minimumSize.width, minHeight: Self.minimumSize.height)
    .background(WindowMaterial())
    .task {
      guard apps.isEmpty, let source = model.installedApps else { return }
      apps = await source.installedApps()
    }
    .sheet(isPresented: $showingAdvanced) {
      AdvancedSettingsView(model: model) { showingAdvanced = false }
    }
    .alert(removeTitle, isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } })) {
      Button("Remove") {
        if let removing { model.removeAppProfile(bundleID: removing) }
        removing = nil
      }
      Button("Cancel", role: .cancel) { removing = nil }
    } message: {
      Text("Its gestures go back to what Default does.")
    }
    .alert("Replace the config file with the current settings?", isPresented: $confirmingReplace) {
      Button("Replace") { commands.replaceWithCurrentSettings() }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Edgy writes the settings it is running now. The text in the file is lost.")
    }
  }

  // MARK: Tabs and the top-right switch

  private func tabBar(readOnly: Bool) -> some View {
    let toggle = model.topSwitch(apps: apps)
    return ZStack {
      HStack(spacing: 0) {
        WindowIdentity()
        Spacer(minLength: 0)
      }
      HStack(spacing: 0) {
        ForEach(model.profileTabs(apps: apps), id: \.self) { ref in tab(ref, readOnly: readOnly) }
        Button {
          addingApp = true
        } label: {
          Image(systemName: "plus").frame(width: 28, height: 24).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add an app")
        .disabled(readOnly)
        .popover(isPresented: $addingApp, arrowEdge: .bottom) {
          AddAppView(model: model) { addingApp = false }
        }
      }
      .padding(WindowMetrics.tabInset)
      .background(
        Tokens.bar.opacity(0.3),
        in: RoundedRectangle(cornerRadius: Tokens.radiusControl + WindowMetrics.tabInset))

      HStack {
        Spacer()
        Text(toggle.label)
        Toggle(toggle.label, isOn: Binding(get: { toggle.isOn }, set: model.setTopSwitch))
          .toggleStyle(.switch).labelsHidden().tint(Tokens.accent)
          .disabled(readOnly)
      }
    }
    .padding(.leading, WindowMetrics.titleBarLeading)
    .padding(.trailing, WindowMetrics.gutter)
    .frame(height: WindowMetrics.tabBarHeight)
  }

  private func tab(_ ref: ProfileRef, readOnly: Bool) -> some View {
    let selected = ref == model.selectedProfile
    let off = model.isProfileOff(ref)
    let name = model.tabName(ref, apps: apps)
    return Button {
      model.selectProfile(ref)
    } label: {
      HStack(spacing: 6) {
        if case .app(let id) = ref { AppMark(path: apps.first { $0.bundleID == id }?.path) }
        Text(name).font(Tokens.font(Tokens.typeBody, semibold: selected))
        if off { Image(systemName: "nosign").accessibilityLabel("Off") }
      }
      .foregroundStyle(off || readOnly ? Tokens.ink2 : Tokens.ink)
      .padding(.horizontal, 12)
      .padding(.vertical, 4)
      .background(
        selected ? Tokens.padTop : .clear, in: RoundedRectangle(cornerRadius: Tokens.radiusControl)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(selected ? .isSelected : [])
    .contextMenu {
      if case .app(let id) = ref {
        Button("Reset \(name) to Default") { model.resetAppProfile(bundleID: id) }.disabled(readOnly)
        Button("Remove \(name) profile…") { removing = id }.disabled(readOnly)
      }
    }
  }

  private var removeTitle: String {
    guard let removing else { return "" }
    return "Remove the \(WindowCopy.appName(for: removing, in: apps)) profile?"
  }

  // MARK: Strips

  @ViewBuilder
  private func stripView(_ strip: WindowStatus.Strip) -> some View {
    switch strip {
    case .noAccessibility:
      WindowStripView(symbol: "info.circle", text: WindowCopy.noAccessibility) {
        Button("Open Settings") { commands.openAccessibilitySettings() }
      }
    case .brokenConfig(let problem):
      WindowStripView(symbol: "exclamationmark.circle", text: problem.sentence) {
        // Reload is the popover's alone (§ Issue states); the window offers these two.
        Button("Open config file") { commands.openConfigFile() }
        Button("Replace with current settings…") { confirmingReplace = true }
      }
    }
  }

  // MARK: Mirror and inspector

  private func mirrorColumn(_ status: WindowStatus) -> some View {
    let device = model.mirroredDevice?.sensorSizeMM
    let region = WindowMetrics.mirrorRegion(
      for: device.map { CGSize(width: $0.width, height: $0.height) } ?? WindowMetrics.largestPadMM)
    return ZStack {
      PadMirrorView(model: model)
        .padding(WindowMetrics.mirrorMargin)
        .opacity(status.fadesMirror ? 0.4 : 1)
      if let line = status.padLine { padLine(line) }
    }
    .frame(minWidth: region.width, maxWidth: .infinity, minHeight: region.height, maxHeight: .infinity)
  }

  @ViewBuilder
  private func padLine(_ line: WindowStatus.PadLine) -> some View {
    switch line {
    case .paused(let until):
      TimelineView(.periodic(from: .now, by: 15)) { context in
        PadLineView(text: WindowCopy.paused(until: until, now: context.date), button: "Resume") { model.resume() }
      }
    case .offInApp(let id):
      PadLineView(text: WindowCopy.offIn(WindowCopy.appName(for: id, in: apps)), button: "Turn on") {
        model.attempt("turn on") { try model.editor.setProfileDisabled(false, for: .app(id)) }
      }
    }
  }

  private func inspectorColumn(_ status: WindowStatus) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      if !status.hidesInspector {
        if case .app(let id) = model.selectedProfile, model.isLegacyProfile(model.selectedProfile) {
          LegacyNoteView { model.followDefault(bundleID: id) }
            .padding(.horizontal, InspectorView.inset)
        }
        InspectorView(model: model)
      }
      Spacer(minLength: 0)
    }
    // The inspector keeps its own leading inset (≈22 pt, render A); the column adds none.
    .padding(.vertical, WindowMetrics.gutter)
    .frame(width: WindowMetrics.inspectorWidth, alignment: .topLeading)
    .frame(maxHeight: .infinity, alignment: .top)
    .background(Tokens.padTop.opacity(0.35))
  }

  // MARK: Footer

  private func footer(readOnly: Bool) -> some View {
    let app = model.editor.config.app
    return HStack(spacing: 20) {
      Toggle("Haptics", isOn: Binding(get: { app.haptics }, set: { model.setHaptics($0) }))
      Toggle("Launch at login", isOn: Binding(get: { app.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
      HStack(spacing: 8) {
        Text("HUD")
        Picker("HUD", selection: Binding(get: { app.hud }, set: { model.setHUD($0) })) {
          Text("Native").tag(HUDMode.native)
          Text("None").tag(HUDMode.none)
        }
        .labelsHidden()
        .fixedSize()
      }
      Spacer()
      AdvancedButton { showingAdvanced = true }
    }
    // Read-only (broken config): every footer label dims with its control (critique 16 S1).
    .disabled(readOnly)
    .foregroundStyle(readOnly ? Tokens.ink2 : Tokens.ink)
    .toggleStyle(.switch)
    .tint(Tokens.accent)
    .padding(.horizontal, WindowMetrics.gutter)
    .frame(height: WindowMetrics.footerHeight)
    .overlay(alignment: .top) { Tokens.line.opacity(0.3).frame(height: 1) }
  }
}
