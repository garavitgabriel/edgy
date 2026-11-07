import EdgyCore
import EdgyRuntime
import Foundation

/// What a mirror says about the system, highest precedence first (§ System states: No trackpad >
/// Paused > Disabled; § App profiles: "Edgy is off in this app"). No Accessibility is a strip
/// under the tabs (window batch), not a pad state.
enum MirrorState: Equatable {
  case noTrackpad
  case paused(String)
  case appOff(String)
  case disabled
  case normal

  var faded: Bool {
    switch self {
    case .paused, .appOff, .disabled: return true
    case .noTrackpad, .normal: return false
    }
  }
}

enum MirrorCopy {
  static let noTrackpadWindow = "Connect a trackpad to see it here."
  static let noTrackpadMini = "No trackpad connected"

  /// "Paused, 47 min left"; whole minutes, rounded up; under a minute "less than a minute left".
  static func paused(until: Date?, now: Date) -> String {
    guard let until else { return "Paused" }
    let seconds = until.timeIntervalSince(now)
    if seconds < 60 { return "Paused, less than a minute left" }
    return "Paused, \(Int((seconds / 60).rounded(.up))) min left"
  }

  /// An app's name for pad copy. Until a name source reaches the model, the bundle ID's last
  /// component, capitalised ("com.example.huddle" becomes "Huddle").
  static func appName(_ bundleID: String) -> String {
    let last = bundleID.split(separator: ".").last.map(String.init) ?? bundleID
    return last.prefix(1).uppercased() + last.dropFirst()
  }
}

extension SettingsModel {
  /// The bundle ID behind a profile tab, `nil` for Default (one code path for both).
  static func app(of profile: ProfileRef) -> String? {
    if case .app(let bundleID) = profile { return bundleID }
    return nil
  }

  /// The catalog by id, for label names and parameter checks.
  var mirrorCatalog: [ActionID: ActionDescriptor] {
    Dictionary(editor.catalogByCategory.flatMap(\.actions).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
  }

  /// The zones a mirror draws for `app` (`nil` = Default): its effective bindings.
  /// `unavailableAsUnmapped`: the popover's mini mirror draws a zone whose action is unavailable
  /// on this Mac as unmapped (§ Issue states); the settings mirror marks its tab instead.
  func mirrorZones(forApp app: String?, unavailableAsUnmapped: Bool = false) -> [MirrorZone] {
    _ = revision
    let off = app.flatMap { editor.config.appProfiles[$0]?.disabled } ?? false
    return MirrorContent.zones(
      rows: editor.effectiveBindings(forApp: app), catalog: mirrorCatalog, allHairline: off,
      availability: { self.editor.availability(of: $0) }, unavailableAsUnmapped: unavailableAsUnmapped)
  }

  /// The pad state for `app` (`nil` = Default). `includesPaused: false` for the settings window,
  /// whose shell fades the mirror and writes the paused line itself.
  func mirrorState(forApp app: String?, includesPaused: Bool = true, now: Date = Date()) -> MirrorState {
    _ = revision
    if mirroredDevice == nil { return .noTrackpad }
    if includesPaused, engineStatus.paused {
      return .paused(MirrorCopy.paused(until: engineStatus.pausedUntil, now: now))
    }
    if let app, editor.config.appProfiles[app]?.disabled == true { return .appOff(MirrorCopy.appName(app)) }
    if !editor.config.app.enabled { return .disabled }
    return .normal
  }

  /// Clicking a zone on the mirror selects it (bone 5). The picker opens from the inspector or a
  /// second click, which batch 15 owns; selecting never touches `picking`.
  func selectZone(_ zone: Zone) {
    selectedZone = zone
  }
}
