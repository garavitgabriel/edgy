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

  /// The catalog by id, for label names and parameter checks. Cached per revision (batch 28).
  var mirrorCatalog: [ActionID: ActionDescriptor] { mirrorData.catalog }

  /// `editor.catalogByCategory` (a sort over the whole catalog), cached per revision.
  var mirrorGroups: [ActionGroup] { mirrorData.groups }

  /// `editor.availability(of:)`, cached per revision and engine status: the live answer reads
  /// the displays, which a view body must not do on every evaluation.
  func mirrorAvailability(of id: ActionID) -> ActionAvailability {
    let data = mirrorData
    if let known = data.availability[id] { return known }
    let answer = editor.availability(of: id)
    data.availability[id] = answer
    return answer
  }

  /// The cache for the current revision and engine status. Reading it registers both with
  /// Observation, so views still re-render on every real change.
  var mirrorData: MirrorDataCache {
    let key = MirrorDataCache.Key(revision: revision, status: engineStatus)
    let id = ObjectIdentifier(self)
    if let entry = MirrorDataCache.entries[id], entry.owner === self {
      if entry.cache.key == key { return entry.cache }
      entry.cache.reset(key: key, editor: editor)
      return entry.cache
    }
    MirrorDataCache.entries = MirrorDataCache.entries.filter { $0.value.owner != nil }
    let cache = MirrorDataCache(key: key, editor: editor)
    MirrorDataCache.entries[id] = MirrorDataCache.Entry(owner: self, cache: cache)
    return cache
  }

  /// The zones a mirror draws for `app` (`nil` = Default): its effective bindings.
  /// `unavailableAsUnmapped`: the popover's mini mirror draws a zone whose action is unavailable
  /// on this Mac as unmapped (§ Issue states); the settings mirror marks its tab instead.
  /// Computed once per revision, engine status and arguments (batch 28), not per body evaluation.
  func mirrorZones(forApp app: String?, unavailableAsUnmapped: Bool = false) -> [MirrorZone] {
    let data = mirrorData
    let pending = PendingSplit(selection: selectedZone)
    let key = MirrorDataCache.ZonesKey(app: app, unavailableAsUnmapped: unavailableAsUnmapped, pendingSplit: pending)
    if let zones = data.zones[key] { return zones }
    let off = app.flatMap { editor.config.appProfiles[$0]?.disabled } ?? false
    let zones = MirrorContent.zones(
      rows: editor.effectiveBindings(forApp: app), catalog: data.catalog, allHairline: off,
      availability: { self.mirrorAvailability(of: $0) }, unavailableAsUnmapped: unavailableAsUnmapped,
      pendingSplit: pending)
    data.zones[key] = zones
    data.zoneComputations += 1
    return zones
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

/// Mirror data for one revision and engine status (batch 28): the catalog, its groups, the
/// availability answers and the zones each mirror draws. Rebuilt when either changes. Lives beside
/// the model (the model's stored state is frozen), one per model, dropped with it.
@MainActor
final class MirrorDataCache {
  struct Key: Equatable {
    var revision: Int
    var status: EngineStatus
  }

  struct ZonesKey: Hashable {
    var app: String?
    var unavailableAsUnmapped: Bool
    var pendingSplit: PendingSplit? = nil
  }

  struct Entry {
    weak var owner: SettingsModel?
    var cache: MirrorDataCache
  }

  static var entries: [ObjectIdentifier: Entry] = [:]

  private(set) var key: Key
  private(set) var catalog: [ActionID: ActionDescriptor] = [:]
  private(set) var groups: [ActionGroup] = []
  var availability: [ActionID: ActionAvailability] = [:]
  var zones: [ZonesKey: [MirrorZone]] = [:]
  /// For tests: how many times the catalog was rebuilt and zones were computed.
  private(set) var catalogComputations = 0
  var zoneComputations = 0

  init(key: Key, editor: SettingsEditor) {
    self.key = key
    reset(key: key, editor: editor)
  }

  func reset(key: Key, editor: SettingsEditor) {
    self.key = key
    groups = editor.catalogByCategory
    catalog = Dictionary(groups.flatMap(\.actions).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    availability = [:]
    zones = [:]
    catalogComputations += 1
  }
}
