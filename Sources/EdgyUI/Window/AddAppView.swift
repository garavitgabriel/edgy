import Actions
import EdgyCore
import EdgyRuntime
import SwiftUI

/// The "+" popover (BRIEF § App profiles, render S2): step 1 picks the app (search, Running, then
/// All apps; apps that already have a profile are listed but disabled), step 2 picks how it
/// starts. Add opens the new tab selected.
public struct AddAppView: View {
  public enum Step: Equatable {
    case chooseApp
    case startFrom(InstalledApp)
  }

  @Bindable var model: SettingsModel
  @State private var apps: [InstalledApp]
  @State private var step: Step
  @State private var search = ""
  @State private var start: AppProfileStart = .defaultWithChanges
  @State private var loaded: Bool
  private let done: () -> Void

  static let width: CGFloat = 340
  static let maxListHeight: CGFloat = 360

  /// `apps`: a fixed list (previews, tests). `nil` loads `model.installedApps` when shown.
  public init(
    model: SettingsModel, apps: [InstalledApp]? = nil, step: Step = .chooseApp, done: @escaping () -> Void = {}
  ) {
    self.model = model
    _apps = State(initialValue: apps ?? [])
    _loaded = State(initialValue: apps != nil)
    _step = State(initialValue: step)
    self.done = done
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      switch step {
      case .chooseApp: chooseApp
      case .startFrom(let app): startFrom(app)
      }
    }
    .font(Tokens.font(Tokens.typeBody))
    .foregroundStyle(Tokens.ink)
    .frame(width: Self.width)
    .task {
      guard !loaded, let source = model.installedApps else { return }
      apps = await source.installedApps()
      loaded = true
    }
  }

  // MARK: Step 1

  private var chooseApp: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Add an app").font(Tokens.font(Tokens.typeBody, semibold: true))
      TextField("Search", text: $search).textFieldStyle(.roundedBorder)
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 2) {
          let sections = AddAppView.sections(apps, matching: search)
          if !sections.running.isEmpty {
            header("Running")
            ForEach(sections.running.map { ListRow(section: "running", app: $0) }) { row($0.app) }
          }
          if !sections.all.isEmpty {
            header("All apps")
            ForEach(sections.all.map { ListRow(section: "all", app: $0) }) { row($0.app) }
          }
        }
      }
      .frame(maxHeight: Self.maxListHeight)
      .fixedSize(horizontal: false, vertical: true)
    }
    .padding(16)
  }

  private func header(_ title: String) -> some View {
    Text(title).font(Tokens.font(Tokens.typeBody, semibold: true)).foregroundStyle(Tokens.ink2)
      .padding(.top, 8).padding(.bottom, 2)
  }

  private func row(_ app: InstalledApp) -> some View {
    let taken = model.editor.config.appProfiles[app.bundleID] != nil
    return Button {
      step = .startFrom(app)
    } label: {
      HStack(spacing: 8) {
        AppMark(path: app.path)
        Text(app.name).foregroundStyle(taken ? Tokens.ink2 : Tokens.ink)
        Spacer()
        if taken { Text("Has a profile").foregroundStyle(Tokens.ink2) }
      }
      .padding(.vertical, 4)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    // Not `.disabled`: that dims `ink2` again, below 4.5:1. The row just doesn't take clicks.
    .allowsHitTesting(!taken)
    .accessibilityAddTraits(taken ? [] : .isButton)
  }

  /// Running apps, then all apps alphabetically; both filtered by `search` (name or bundle ID).
  static func sections(_ apps: [InstalledApp], matching search: String) -> (
    running: [InstalledApp], all: [InstalledApp]
  ) {
    let query = search.trimmingCharacters(in: .whitespaces)
    let matching = apps.filter {
      query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)
        || $0.bundleID.localizedCaseInsensitiveContains(query)
    }
    .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    return (matching.filter(\.isRunning), matching)
  }

  // MARK: Step 2

  private func startFrom(_ app: InstalledApp) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        AppMark(path: app.path)
        Text(app.name).font(Tokens.font(Tokens.typeBody, semibold: true))
      }
      Text("Start from").foregroundStyle(Tokens.ink2)
      VStack(spacing: 2) {
        ForEach(AppProfileStart.allCases, id: \.self) { option in radio(option) }
      }
      HStack {
        Spacer()
        Button("Back") { step = .chooseApp }.buttonStyle(.bordered)
        Button("Add") { add(app) }.buttonStyle(InkButtonStyle()).keyboardShortcut(.defaultAction)
      }
      .padding(.top, 6)
    }
    .padding(16)
  }

  private func radio(_ option: AppProfileStart) -> some View {
    let selected = option == start
    return Button {
      start = option
    } label: {
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        Circle()
          .strokeBorder(Tokens.ink, lineWidth: 1.5)
          .overlay { if selected { Circle().fill(Tokens.ink).padding(4) } }
          .frame(width: 16, height: 16)
          .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
        VStack(alignment: .leading, spacing: 2) {
          Text(option.title).foregroundStyle(Tokens.ink)
          Text(option.detail).foregroundStyle(Tokens.ink2).fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      .background(
        selected ? Tokens.bar.opacity(0.35) : .clear, in: RoundedRectangle(cornerRadius: Tokens.radiusControl)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  private func add(_ app: InstalledApp) {
    model.attempt("add profile") { try model.addAppProfile(bundleID: app.bundleID, startingFrom: start) }
    done()
  }
}

/// An app appears in both Running and All apps, so each list row is keyed by its section too.
private struct ListRow: Identifiable {
  let section: String
  let app: InstalledApp
  var id: String { "\(section)/\(app.bundleID)" }
}
