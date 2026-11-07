import Actions
import EdgyCore
import EdgyRuntime
import Foundation

/// The popover's plain list (bone 10, bottom half), in order. Two groups split by a separator:
/// the working rows, then About and Quit.
public enum MenuRow: CaseIterable, Hashable, Sendable {
  case pause, settings, openConfigFile, reloadConfig, about, quit

  public var title: String {
    switch self {
    case .pause: return "Pause for 1 hour"
    case .settings: return "Settings…"
    case .openConfigFile: return "Open config file"
    case .reloadConfig: return "Reload config"
    case .about: return "About Edgy"
    case .quit: return "Quit Edgy"
    }
  }

  /// The shortcut shown on the right, in system key symbols.
  public var shortcut: String? {
    switch self {
    case .settings: return "⌘,"
    case .reloadConfig: return "⌘R"
    case .quit: return "⌘Q"
    default: return nil
    }
  }

  /// The key for `.keyboardShortcut` (⌘ + this).
  var key: Character? {
    switch self {
    case .settings: return ","
    case .reloadConfig: return "r"
    case .quit: return "q"
    default: return nil
    }
  }

  /// About and Quit sit after the separator.
  public var startsSecondGroup: Bool { self == .about }

  /// How long **Pause for 1 hour** pauses.
  public static let pauseDuration: TimeInterval = 3600

  /// The rows to show. "Pause for 1 hour" is hidden while paused (§ System states).
  public static func visible(paused: Bool) -> [MenuRow] {
    allCases.filter { !(paused && $0 == .pause) }
  }

  @MainActor
  public func perform(actions: MenuBarActions, model: SettingsModel, now: Date) {
    switch self {
    case .pause: model.pause(until: now.addingTimeInterval(Self.pauseDuration))
    case .settings: actions.openSettings()
    case .openConfigFile: actions.openConfigFile()
    case .reloadConfig: actions.reloadConfig()
    case .about: actions.about()
    case .quit: actions.quit()
    }
  }
}

/// One profile chip (bone 10). Chips don't select anything; the profile in effect is filled.
public struct ProfileChip: Hashable, Sendable, Identifiable {
  public var ref: ProfileRef
  public var name: String
  /// The profile in effect right now (follows the frontmost app): drawn filled.
  public var isLive: Bool
  /// Edgy is off in this app: name in `ink2` with a slashed-circle mark (as on the window's tabs).
  public var isOff: Bool
  /// The app's bundle path, for its monochrome mark.
  public var appPath: String?

  public var id: ProfileRef { ref }

  /// The frontmost app's own profile first (if it has one), then Default, then the other app
  /// profiles alphabetically by name.
  @MainActor
  public static func chips(model: SettingsModel, frontmost: String?, apps: [InstalledApp]) -> [ProfileChip] {
    let editor = model.editor
    let live = editor.effectiveProfile(for: frontmost)
    var refs = model.profileTabs(apps: apps)
    if case .app = live, let index = refs.firstIndex(of: live) {
      refs.remove(at: index)
      refs.insert(live, at: 0)
    }
    return refs.map { ref in
      var path: String?
      if case .app(let id) = ref { path = apps.first { $0.bundleID == id }?.path }
      return ProfileChip(
        ref: ref, name: model.tabName(ref, apps: apps), isLive: ref == live, isOff: model.isProfileOff(ref),
        appPath: path)
    }
  }
}

/// What the popover's top half shows. Broken config and No Accessibility each replace it with one
/// block (§ Issue states, § System states); the list below is unchanged.
public enum PopoverTop: Equatable, Sendable {
  case brokenConfig(ConfigProblem)
  case needsAccessibility
  case normal(PopoverMirror)

  @MainActor
  public static func resolve(state: MenuBarState, model: SettingsModel) -> PopoverTop {
    if let problem = state.configProblem(model: model) { return .brokenConfig(problem) }
    if state.accessibility == .denied { return .needsAccessibility }
    return .normal(PopoverMirror.resolve(state: state, model: model))
  }
}

/// The mini mirror's state in the normal top half.
public struct PopoverMirror: Equatable, Sendable {
  /// No trackpad: a dashed pad outline at the default proportion with "No trackpad connected".
  public var noTrackpad: Bool
  /// Faded to 40%: Enabled is off, Paused (batch-17 design answer 3: one value everywhere), or Edgy
  /// is off in the frontmost app (§ App profiles). The popover applies it once; the mini mirror
  /// doesn't fade again.
  public var faded: Bool
  /// The paused line under the mini mirror, with **Resume**.
  public var pausedUntil: Date?
  public var paused: Bool

  @MainActor
  public static func resolve(state: MenuBarState, model: SettingsModel) -> PopoverMirror {
    _ = model.revision
    let engine = model.engineStatus
    let config = model.editor.config
    let offInFront = state.frontmostBundleID.map { config.appProfiles[$0]?.disabled == true } ?? false
    return PopoverMirror(
      noTrackpad: !engine.hasTrackpad, faded: !config.app.enabled || offInFront || engine.paused,
      pausedUntil: engine.pausedUntil,
      paused: engine.paused)
  }
}

/// The popover's copy (BRIEF § System states, § Issue states; word for word).
public enum PopoverCopy {
  public static let noAccessibility = WindowCopy.noAccessibility
  public static let noAccessibilityDetail = "Touches still show in Test Mode."
  public static let noTrackpad = "No trackpad connected"
  public static let dontRunActions = "Don’t run actions"

  /// "Paused, 47 min left"; whole minutes; "less than a minute left" under one. The same rule as
  /// the window (`WindowCopy.paused`), so both say the same thing.
  public static func paused(until: Date?, now: Date) -> String { WindowCopy.paused(until: until, now: now) }
}
