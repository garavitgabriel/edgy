import EdgyCore
import Foundation

/// Where the editor reads and writes the config. `ConfigStore` in the app; tests use it with a
/// temp-dir URL, or a failing double.
public protocol SettingsPersisting: AnyObject {
  func load() throws -> EdgyConfig
  func save(_ config: EdgyConfig) throws
}

extension ConfigStore: SettingsPersisting {}

public enum SettingsEditorError: Error, Equatable {
  /// The edit would introduce these errors. Nothing was changed.
  case invalid([ValidationIssue])
  case profileExists(String)
  case profileNotFound(ProfileRef)
  case invalidBundleID(String)
  /// The config file on disk is broken (`SettingsEditor.configProblem`): edits are refused so
  /// nothing silently overwrites the user's hand edit. Fix the file, or
  /// `replaceFileWithCurrentSettings()`.
  case readOnly(ConfigProblem)
  /// `setNameAndIcon`: nothing is bound at that slot (in the profile, or inherited from Default).
  case bindingNotFound(BindingKey)
  /// `setNameAndIcon`: the icon isn't one the icon library draws. Nothing was changed.
  case unknownIcon(ActionID)
}

/// The config file stopped decoding or validating when it was reloaded. Edgy keeps running the
/// last working settings (`SettingsEditor.config`) until the file is fixed or replaced.
public struct ConfigProblem: Hashable, Sendable {
  /// What's wrong: the parser's message ("Unexpected character 'x' around line 14, column 3."),
  /// or the first validation error.
  public var message: String
  /// The line in the file, when the parser reported one (1-based).
  public var line: Int?

  public init(message: String, line: Int? = nil) {
    self.message = message
    self.line = line
  }

  /// From a load error: `ConfigStoreError.malformed` / `.unsupportedSchemaVersion`, or anything else.
  public init(error: Error) {
    switch error {
    case ConfigStoreError.malformed(let reason, _):
      self.init(message: reason, line: Self.line(in: reason))
    case ConfigStoreError.unsupportedSchemaVersion(let found, let supported, _):
      self.init(message: "schemaVersion \(found) isn't supported (this version of Edgy reads \(supported))")
    case SettingsEditorError.invalid(let issues):
      self.init(message: issues.first.map(String.init(describing:)) ?? "invalid settings")
    default:
      self.init(message: String(describing: error), line: Self.line(in: String(describing: error)))
    }
  }

  /// "… line 14 …" → 14.
  static func line(in message: String) -> Int? {
    guard let range = message.range(of: #"line \d+"#, options: .regularExpression) else { return nil }
    return Int(message[range].dropFirst(5))
  }
}

/// What one editor update did. Observers get one per committed change.
public struct SettingsChange: Sendable {
  public enum Cause: Sendable, Equatable {
    /// A single edit (one undo step).
    case edit
    /// A live update inside `beginContinuousEdit` … `endContinuousEdit` (not yet an undo step).
    case continuousEdit
    /// The continuous edit was closed into one undo step; `config` is unchanged by this update.
    case continuousEditEnded
    case undo
    case redo
    /// Adopted from outside the editor (hand-edited file, Reload Config).
    case external
    /// `refreshAvailability()` found an action whose availability changed (a display or keyboard
    /// came or went). `config == previous`; `issues` (and what `availability(of:)` answers) may
    /// differ, so a window redraws its greyed-out actions and warnings. Not an undo step.
    case availability
    /// `configProblem` appeared, changed or cleared. `config == previous` unless a fixed file
    /// was adopted at the same time (then the cause is `.external`).
    case configProblem
  }

  public var cause: Cause
  public var config: EdgyConfig
  public var previous: EdgyConfig

  public var appSettingsChanged: Bool { config.app != previous.app }
  public var gestureSettingsChanged: Bool { config.gestures != previous.gestures }
  /// Profiles that were added, removed or edited.
  public var changedProfiles: Set<ProfileRef> {
    var refs: Set<ProfileRef> = config.defaultProfile == previous.defaultProfile ? [] : [.default]
    for id in Set(config.appProfiles.keys).union(previous.appProfiles.keys)
    where config.appProfiles[id] != previous.appProfiles[id] {
      refs.insert(.app(id))
    }
    return refs
  }
}

/// The single source of truth for settings edits; the settings window binds to it.
///
/// Every mutation builds the next config, validates it, saves it through the store and hands it
/// to `apply` (the engine), then notifies observers. A mutation that fails throws and changes
/// nothing, in memory or on disk.
///
/// **Validation gate.** An edit is refused only for errors it *introduces*: errors already present
/// (say, a hand-edited binding to an unknown action) are exposed in `issues` but never block other
/// edits, so the user can always fix or remove them. Warnings never block.
///
/// **Undo.** One user intent = one step, bounded to `undoLimit`. A continuous edit (slider drag)
/// is one step; its saves are debounced by `continuousSaveDelay` and the final value is saved at
/// `endContinuousEdit()`. External changes are adopted as undoable steps without being re-saved.
@MainActor
public final class SettingsEditor {
  public static let undoLimit = 50
  /// Quiet time after the last update of a continuous edit before it is saved mid-drag.
  public static let continuousSaveDelay: TimeInterval = 0.25

  public private(set) var config: EdgyConfig
  /// Set while the config file on disk is broken (it stopped decoding or validating on reload).
  /// `config` keeps the last working settings and keeps running; every edit, undo and redo throws
  /// `SettingsEditorError.readOnly`. Clears when a reload reads a good file again, or after
  /// `replaceFileWithCurrentSettings()`.
  public private(set) var configProblem: ConfigProblem?
  /// Validation issues of `config`, refreshed on every change.
  public private(set) var issues: [ValidationIssue]
  /// Rebuilt by `refreshAvailability()`; otherwise fixed for the editor's life.
  public private(set) var validator: ConfigValidator

  public var canUndo: Bool { !undoStack.isEmpty || isEditingContinuously && config != continuous?.start }
  public var canRedo: Bool { !redoStack.isEmpty }
  public var isEditingContinuously: Bool { continuous != nil }

  private let store: SettingsPersisting
  private let scheduler: Scheduling
  private let logger: EdgyLogging
  private let applyConfig: @MainActor (EdgyConfig) -> Void
  /// Answers `availability(of:)`; `nil` = everything available.
  private let availabilitySource: ActionPerforming?
  private var undoStack: [EdgyConfig] = []
  private var redoStack: [EdgyConfig] = []
  private var continuous: (key: String, start: EdgyConfig)?
  private var pendingSave: ScheduledWork?
  private var observers: [UUID: @MainActor (SettingsChange) -> Void] = [:]

  /// - Parameters:
  ///   - config: the config already loaded and running (it is not re-saved or re-applied).
  ///   - catalog: `ActionPerforming.available`.
  ///   - actions: the registry asked for `availability(of:)` (usually the one `catalog` came
  ///     from); `nil` = everything available.
  ///   - apply: hands a committed config to the engine.
  public init(
    config: EdgyConfig, catalog: [ActionDescriptor], store: SettingsPersisting, scheduler: Scheduling,
    actions: ActionPerforming? = nil,
    logger: EdgyLogging = SystemLogger(category: "settings"), apply: @escaping @MainActor (EdgyConfig) -> Void
  ) {
    self.config = config
    self.availabilitySource = actions
    self.validator = ConfigValidator(catalog: catalog, availability: Self.snapshot(catalog: catalog, from: actions))
    self.store = store
    self.scheduler = scheduler
    self.logger = logger
    self.applyConfig = apply
    self.issues = validator.validate(config)
    logIssues()
  }

  // MARK: Observation

  /// Calls `handler` after every committed change. Keep the token to stop observing.
  @discardableResult
  public func observe(_ handler: @escaping @MainActor (SettingsChange) -> Void) -> UUID {
    let id = UUID()
    observers[id] = handler
    return id
  }

  public func removeObserver(_ id: UUID) {
    observers[id] = nil
  }

  // MARK: Queries

  public func profile(_ ref: ProfileRef) -> Profile? {
    switch ref {
    case .default: return config.defaultProfile
    case .app(let id): return config.appProfiles[id]
    }
  }

  /// The profile that applies while `bundleID` is frontmost.
  public func effectiveProfile(for bundleID: String?) -> ProfileRef {
    if let bundleID, config.appProfiles[bundleID] != nil { return .app(bundleID) }
    return .default
  }

  public func bindingsByZone(in ref: ProfileRef) -> [ZoneBindings] {
    profile(ref).map(ConfigValidator.bindingsByZone) ?? []
  }

  public var catalogByCategory: [ActionGroup] { validator.catalogByCategory }

  public func compatibleActions(zone: Zone, gesture: GestureKind) -> [ActionDescriptor] {
    validator.compatibleActions(zone: zone, gesture: gesture)
  }

  public func supportedGestures(for zone: Zone) -> [GestureKind] {
    ConfigValidator.supportedGestures(for: zone)
  }

  /// Whether `id` can work on this Mac right now: asks the registry (live, not the snapshot the
  /// validator uses). `.available` when the editor was made without an availability source.
  public func availability(of id: ActionID) -> ActionAvailability {
    availabilitySource?.availability(of: id) ?? .available
  }

  /// Re-reads availability for the whole catalog (after a display or keyboard is attached or
  /// removed) so `issues` and later validation see it. Changes no config. When any action's
  /// availability changed, observers get a `.availability` change and this returns `true`.
  @discardableResult
  public func refreshAvailability() -> Bool {
    let snapshot = Self.snapshot(catalog: validator.catalog, from: availabilitySource)
    guard snapshot != validator.availability else { return false }
    validator = ConfigValidator(catalog: validator.catalog, availability: snapshot)
    issues = validator.validate(config)
    notify(.availability, previous: config)
    return true
  }

  /// `base` (the built-in preset by default) adjusted to this Mac: bindings whose action is
  /// unavailable here get the `MachineDefaults` substitute or are dropped. Pure; nothing is saved.
  public func machineDefaults(from base: EdgyConfig = .defaults) -> EdgyConfig {
    MachineDefaults.build(from: base, catalog: validator.catalog, availability: availability(of:)).config
  }

  private static func snapshot(catalog: [ActionDescriptor], from actions: ActionPerforming?)
    -> [ActionID: ActionAvailability]
  {
    guard let actions else { return [:] }
    return Dictionary(
      catalog.map { ($0.id, actions.availability(of: $0.id)) }, uniquingKeysWith: { first, _ in first })
  }

  /// Issues `binding` would have if set in `ref` now, including overlap warnings against the
  /// profile's other bindings (the binding in its own slot is replaced, so it is not a duplicate).
  public func validate(_ binding: Binding, in ref: ProfileRef) -> [ValidationIssue] {
    var issues = validator.validate(binding, in: ref)
    var others = profile(ref)?.bindings ?? []
    if case .app = ref, profile(ref)?.inheritsDefault == true {
      let own = Set(others.map(\.key))
      others += config.defaultProfile.bindings.filter { !own.contains($0.key) }
    }
    for other in others where other.key != binding.key && other.action != .doNothing {
      if binding.action != .doNothing, ConfigValidator.overlaps(other, binding) {
        issues.append(
          ValidationIssue(.warning, .overlappingZones, profile: ref, binding: binding.key, action: binding.action))
      }
    }
    return issues
  }

  public func validate(_ config: EdgyConfig) -> [ValidationIssue] {
    validator.validate(config)
  }

  // MARK: Mutations

  /// Puts `binding` in its zone + gesture slot, replacing what was there (and the binding at
  /// `replacing`, when the UI moved a binding to another slot). Keeps the replaced binding's position.
  public func setBinding(_ binding: Binding, in ref: ProfileRef, replacing previous: BindingKey? = nil) throws {
    try mutateProfile(ref) { profile in
      let slots: Set<BindingKey> = [binding.key, previous ?? binding.key]
      let position = profile.bindings.firstIndex { slots.contains($0.key) } ?? profile.bindings.endIndex
      let kept = profile.bindings.enumerated().filter { !slots.contains($0.element.key) }
      let before = kept.filter { $0.offset < position }.map(\.element)
      let after = kept.filter { $0.offset > position }.map(\.element)
      profile.bindings = before + [binding] + after
    }
  }

  public func removeBinding(_ key: BindingKey, from ref: ProfileRef) throws {
    try mutateProfile(ref) { $0.bindings.removeAll { $0.key == key } }
  }

  /// What a new app profile starts as.
  public enum NewAppProfile: Sendable {
    /// No bindings of its own, inheriting the default: the app behaves exactly like the default
    /// until a gesture is overridden or turned off. The v0.4 default.
    case inheriting
    /// The pre-v0.4 full-replace profile holding a copy of the default's bindings; later default
    /// edits don't reach the app.
    case copyOfDefault
    /// A full-replace profile with no bindings: every gesture is off while the app is frontmost.
    case empty
  }

  /// Adds a profile for `bundleID`; by default one that inherits the default profile.
  public func addAppProfile(bundleID: String, startingAs start: NewAppProfile = .inheriting) throws {
    guard ConfigValidator.isBundleID(bundleID) else { throw SettingsEditorError.invalidBundleID(bundleID) }
    guard config.appProfiles[bundleID] == nil else { throw SettingsEditorError.profileExists(bundleID) }
    var next = config
    switch start {
    case .inheriting: next.appProfiles[bundleID] = Profile(bindings: [], inheritsDefault: true)
    case .copyOfDefault: next.appProfiles[bundleID] = Profile(bindings: config.defaultProfile.bindings)
    case .empty: next.appProfiles[bundleID] = Profile(bindings: [])
    }
    try commit(next)
  }

  /// The pre-v0.4 call: a full-replace profile, empty or a copy of the default's bindings. Kept so
  /// old call sites behave as before; `addAppProfile(bundleID:startingAs:)` is the v0.4 API.
  public func addAppProfile(bundleID: String, copyingDefault: Bool) throws {
    try addAppProfile(bundleID: bundleID, startingAs: copyingDefault ? .copyOfDefault : .empty)
  }

  // MARK: Per-app overrides

  /// Puts `binding` in the app's profile, overriding the default's binding on the same zone +
  /// gesture for that app only. Creates an inheriting profile when the app has none (one undo step).
  public func overrideBinding(_ binding: Binding, forApp bundleID: String) throws {
    try mutateAppProfile(bundleID, creating: true) { profile in
      if let index = profile.bindings.firstIndex(where: { $0.key == binding.key }) {
        profile.bindings[index] = binding
      } else {
        profile.bindings.append(binding)
      }
    }
  }

  // MARK: Your own name and icon (batch 29)

  /// Longest custom name, in characters, after trimming (BRIEF § Your own name and icon).
  public static let customNameLimit = 24

  /// What `name` saves as for a binding to `action`: trimmed, cut to `customNameLimit` characters,
  /// and `nil` when empty or equal to the action's own name (`actionName`).
  public static func customName(_ name: String?, actionName: String?) -> String? {
    guard let name else { return nil }
    let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(customNameLimit))
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed != actionName else { return nil }
    return trimmed
  }

  /// The icon library: every catalog action but "Do nothing". The UI passes the IDs it draws.
  public var iconLibrary: Set<ActionID> { Set(validator.catalog.map(\.id)).subtracting([.doNothing]) }

  /// Sets the name and icon of the binding at `key` in `ref` as **one undo step**. The name is
  /// normalized by `customName(_:actionName:)`; an icon equal to the bound action's own saves as
  /// `nil`, and any other icon must be in `library` (default `iconLibrary`) or the edit is refused
  /// with `unknownIcon`. On an inheriting app tab, a binding that shows through from Default becomes
  /// an override (the same action and parameters with the new name and icon), so it gets the override
  /// dot and Revert. The engine never reads either field.
  public func setNameAndIcon(
    _ key: BindingKey, in ref: ProfileRef, name: String?, icon: ActionID?, library: Set<ActionID>? = nil
  ) throws {
    try refuseWhileBroken()
    let own = profile(ref)?.bindings.first { $0.key == key }
    var binding: Binding
    switch ref {
    case .default:
      guard let own else { throw SettingsEditorError.bindingNotFound(key) }
      binding = own
    case .app(let bundleID):
      guard let app = config.appProfiles[bundleID] else { throw SettingsEditorError.profileNotFound(ref) }
      if let own {
        binding = own
      } else if app.inheritsDefault,
        let inherited = config.defaultProfile.bindings.first(where: { $0.key == key && $0.action != .doNothing })
      {
        binding = inherited
      } else {
        throw SettingsEditorError.bindingNotFound(key)
      }
    }
    let ownIcon = icon == binding.action ? nil : icon
    if let ownIcon, !(library ?? iconLibrary).contains(ownIcon) {
      throw SettingsEditorError.unknownIcon(ownIcon)
    }
    binding.customName = Self.customName(name, actionName: validator.descriptor(for: binding.action)?.displayName)
    binding.customIcon = ownIcon
    switch ref {
    case .default: try setBinding(binding, in: .default)
    case .app(let bundleID): try overrideBinding(binding, forApp: bundleID)
    }
  }

  /// Turns the gesture at `key` off while the app is frontmost (a `doNothing` binding), whatever
  /// the default binds there. Creates an inheriting profile when the app has none.
  public func turnOff(_ key: BindingKey, forApp bundleID: String) throws {
    try overrideBinding(Binding(zone: key.zone, gesture: key.gesture, action: .doNothing), forApp: bundleID)
  }

  /// Drops the app's own binding at `key` so the default's shows through again (an override or a
  /// turned-off gesture goes back to inherited). In a full-replace profile this just removes the
  /// binding. Nothing to revert is a no-op.
  public func revertToDefault(_ key: BindingKey, forApp bundleID: String) throws {
    try mutateAppProfile(bundleID, creating: false) { $0.bindings.removeAll { $0.key == key } }
  }

  /// Turns a full-replace profile into an inheriting one that behaves exactly the same: bindings
  /// equal to the default's are dropped (inherited), default slots the app didn't bind become
  /// `doNothing`, everything else stays as an override. Already inheriting -> no-op.
  public func convertToInheriting(bundleID: String) throws {
    let base = config.defaultProfile.bindings.filter { $0.action != .doNothing }
    try mutateAppProfile(bundleID, creating: false) { profile in
      guard !profile.inheritsDefault else { return }
      let own = Dictionary(profile.bindings.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
      var overrides: [Binding] = []
      for binding in base {
        if let mine = own[binding.key] {
          if mine != binding { overrides.append(mine) }
        } else {
          overrides.append(Binding(zone: binding.zone, gesture: binding.gesture, action: .doNothing))
        }
      }
      let baseKeys = Set(base.map(\.key))
      overrides += profile.bindings.filter { !baseKeys.contains($0.key) }
      profile = Profile(bindings: overrides, disabled: profile.disabled, inheritsDefault: true)
    }
  }

  /// What runs while `bundleID` is frontmost, one row per slot, with where each row comes from.
  /// Order matches `EdgyConfig.profile(for:)`: default order, then the app's own extra slots.
  /// Unlike the resolved profile, turned-off slots are listed (as `.turnedOff`). An app without a
  /// profile (or `nil`) gets the default's bindings, all `.inherited`; a full-replace profile's rows
  /// are all `.appOnly` (or `.turnedOff` for `doNothing`).
  public func effectiveBindings(forApp bundleID: String?) -> [EffectiveBinding] {
    let base = config.defaultProfile.bindings.filter { $0.action != .doNothing }
    guard let bundleID, let app = config.appProfiles[bundleID] else {
      return base.map { EffectiveBinding(binding: $0, source: .inherited, defaultBinding: $0) }
    }
    guard app.inheritsDefault else {
      return app.bindings.map {
        EffectiveBinding(binding: $0, source: $0.action == .doNothing ? .turnedOff : .appOnly, defaultBinding: nil)
      }
    }
    var rows: [EffectiveBinding] = []
    var used = Set<BindingKey>()
    for binding in base {
      guard let mine = app.bindings.first(where: { $0.key == binding.key }) else {
        rows.append(EffectiveBinding(binding: binding, source: .inherited, defaultBinding: binding))
        continue
      }
      used.insert(binding.key)
      let source: EffectiveBinding.Source = mine.action == .doNothing ? .turnedOff : .overridden
      rows.append(EffectiveBinding(binding: mine, source: source, defaultBinding: binding))
    }
    for binding in app.bindings where used.insert(binding.key).inserted {
      let source: EffectiveBinding.Source = binding.action == .doNothing ? .turnedOff : .appOnly
      rows.append(EffectiveBinding(binding: binding, source: source, defaultBinding: nil))
    }
    return rows
  }

  public func removeAppProfile(bundleID: String) throws {
    guard config.appProfiles[bundleID] != nil else { throw SettingsEditorError.profileNotFound(.app(bundleID)) }
    var next = config
    next.appProfiles[bundleID] = nil
    try commit(next)
  }

  public func setProfileDisabled(_ disabled: Bool, for ref: ProfileRef) throws {
    try mutateProfile(ref) { $0.disabled = disabled }
  }

  /// Edits app settings; haptic strengths are clamped to `AppSettings.hapticStrengthRange`.
  public func updateAppSettings(_ body: (inout AppSettings) -> Void) throws {
    var next = config
    body(&next.app)
    next.app.hapticTickStrength = AppSettings.clampStrength(next.app.hapticTickStrength)
    next.app.hapticClickStrength = AppSettings.clampStrength(next.app.hapticClickStrength)
    try commit(next)
  }

  /// Edits gesture settings; every value is clamped by `GestureSettingsLimits`.
  public func updateGestureSettings(_ body: (inout GestureSettings) -> Void) throws {
    var next = config
    body(&next.gestures)
    next.gestures = GestureSettingsLimits.clamped(next.gestures)
    try commit(next)
  }

  // MARK: Display check ("Did this screen change brightness?")

  /// Whether to ask about the external display with this `DisplayInfo.key`: not confirmed, not
  /// turned off, and asked fewer than `displayCheckMaxAsks` times.
  public func displayCheckDue(key: String) -> Bool {
    !config.app.confirmedDisplays.contains(key) && !config.app.unresponsiveDisplays.contains(key)
      && config.app.displayCheckAsks[key, default: 0] < Self.displayCheckMaxAsks
  }

  /// Unanswered, the question is asked at most this many times per display.
  public static let displayCheckMaxAsks = 3

  /// Records that the question was shown for `key` (the UI calls this when the plate appears).
  /// Stops counting at `displayCheckMaxAsks`. One undo step.
  public func countDisplayCheckAsk(key: String) throws {
    try updateAppSettings {
      $0.displayCheckAsks[key] = min($0.displayCheckAsks[key, default: 0] + 1, Self.displayCheckMaxAsks)
    }
  }

  /// The user's answer for the display with this key. `responds` (Yes) → confirmed, never asked
  /// again. Not (No, turn off for this display) → brightness skips it until `turnDisplayBackOn`.
  /// One undo step.
  public func answerDisplayCheck(key: String, responds: Bool) throws {
    try updateAppSettings {
      if responds {
        $0.confirmedDisplays.insert(key)
        $0.unresponsiveDisplays.remove(key)
      } else {
        $0.unresponsiveDisplays.insert(key)
        $0.confirmedDisplays.remove(key)
      }
    }
  }

  /// "Turn back on": brightness drives the display again. It isn't confirmed, so the question may
  /// come back (up to the remaining asks). One undo step.
  public func turnDisplayBackOn(key: String) throws {
    try updateAppSettings { $0.unresponsiveDisplays.remove(key) }
  }

  // MARK: Presets

  /// Replaces the default profile with `preset`'s, adjusted to this Mac (`MachineDefaults`:
  /// unavailable actions substituted or dropped). App settings, gesture tuning and app profiles
  /// stay. One undo step.
  public func applyPreset(_ preset: Presets.Preset) throws {
    var next = config
    next.defaultProfile = machineDefaults(from: preset.config).defaultProfile
    try commit(next)
  }

  /// Default profile → the built-in preset. Inheriting app profile → no overrides, enabled
  /// (everything inherited). Full-replace app profile → a copy of the current default profile's
  /// bindings, enabled (the same thing "add profile, copying default" gives).
  public func resetProfile(_ ref: ProfileRef) throws {
    let preset = EdgyConfig.defaults.defaultProfile
    let copy = Profile(bindings: config.defaultProfile.bindings)
    try mutateProfile(ref) {
      $0 = ref == .default ? preset : $0.inheritsDefault ? Profile(bindings: [], inheritsDefault: true) : copy
    }
  }

  /// Everything back to `EdgyConfig.defaults`, app profiles and app settings included.
  public func resetAll() throws {
    try commit(.defaults)
  }

  // MARK: Continuous edits

  /// Starts coalescing edits (a slider drag) into one undo step. Starting a different key ends the
  /// current one first; starting the same key again is a no-op.
  public func beginContinuousEdit(_ key: String) {
    if let continuous {
      guard continuous.key != key else { return }
      try? endContinuousEdit()
    }
    continuous = (key, config)
  }

  /// Closes the continuous edit: cancels the pending debounced save, saves the final value and
  /// records one undo step if anything changed. If the final save fails the step is still
  /// recorded (memory and engine already hold the value) and the error is rethrown.
  public func endContinuousEdit() throws {
    try closeContinuousEdit(save: true)
  }

  private func closeContinuousEdit(save: Bool) throws {
    guard let (_, start) = continuous else { return }
    continuous = nil
    pendingSave?.cancel()
    pendingSave = nil
    guard config != start else { return }
    pushUndo(start)
    redoStack.removeAll()
    notify(.continuousEditEnded, previous: config)
    guard save else { return }
    do {
      try store.save(config)
    } catch {
      logger.log(.error, "Final save of continuous edit failed: \(error)")
      throw error
    }
  }

  // MARK: Undo / redo

  @discardableResult
  public func undo() throws -> Bool {
    try refuseWhileBroken()
    try? endContinuousEdit()
    guard let target = undoStack.last else { return false }
    try store.save(target)
    undoStack.removeLast()
    redoStack.append(config)
    set(target, cause: .undo)
    return true
  }

  @discardableResult
  public func redo() throws -> Bool {
    try refuseWhileBroken()
    try? endContinuousEdit()
    guard let target = redoStack.last else { return false }
    try store.save(target)
    redoStack.removeLast()
    pushUndo(config)
    set(target, cause: .redo)
    return true
  }

  // MARK: External changes

  /// Adopts a config changed outside the editor (the file watcher, Reload Config) as a new undoable
  /// step. It is not saved back. A config equal to the current one is ignored, so the editor's own
  /// saves never come back as external changes. Errors already in the running config stay exposed;
  /// a file that *introduces* validation errors is not adopted: the last working config keeps
  /// running and `configProblem` is set (the window turns read-only). A good file clears it.
  /// A drag in progress is closed as its own undo step but not saved: the file now holds the
  /// external edit, and saving the drag's value would overwrite it.
  public func adoptExternal(_ external: EdgyConfig) {
    try? closeContinuousEdit(save: false)
    let before = Set(issues.filter(\.isError))
    let introduced = validator.validate(external).filter { $0.isError && !before.contains($0) }
    guard introduced.isEmpty else {
      reportConfigProblem(SettingsEditorError.invalid(introduced))
      return
    }
    let hadProblem = configProblem != nil
    configProblem = nil
    guard external != config else {
      if hadProblem { notify(.configProblem, previous: config) }
      return
    }
    pushUndo(config)
    redoStack.removeAll()
    set(external, cause: .external)
    logIssues()
  }

  /// Re-reads the file and adopts it. A file that doesn't load sets `configProblem` and rethrows
  /// the store's error; one that doesn't validate sets it and throws `.invalid`. Either way the
  /// current config stays and keeps running.
  public func reloadFromDisk() throws {
    let loaded: EdgyConfig
    do {
      loaded = try store.load()
    } catch {
      reportConfigProblem(error)
      throw error
    }
    adoptExternal(loaded)
    if let configProblem { throw SettingsEditorError.readOnly(configProblem) }
  }

  /// The file watcher couldn't load the file (`ConfigStore.startWatching(onChange:onFailure:)`).
  /// Keeps the running config, closes any drag without saving, and turns edits read-only.
  public func reportConfigProblem(_ error: Error) {
    try? closeContinuousEdit(save: false)
    let problem = ConfigProblem(error: error)
    logger.log(.error, "Config file is broken; keeping the last working settings: \(problem.message)")
    guard problem != configProblem else { return }
    configProblem = problem
    notify(.configProblem, previous: config)
  }

  /// Writes the running config over the broken file and clears `configProblem` (the UI confirms
  /// first). Not an undo step: the config itself doesn't change.
  public func replaceFileWithCurrentSettings() throws {
    try store.save(config)
    guard configProblem != nil else { return }
    configProblem = nil
    notify(.configProblem, previous: config)
  }

  // MARK: Private

  private func mutateProfile(_ ref: ProfileRef, _ body: (inout Profile) -> Void) throws {
    var next = config
    switch ref {
    case .default:
      body(&next.defaultProfile)
    case .app(let id):
      guard var profile = next.appProfiles[id] else { throw SettingsEditorError.profileNotFound(ref) }
      body(&profile)
      next.appProfiles[id] = profile
    }
    try commit(next)
  }

  private func mutateAppProfile(_ bundleID: String, creating: Bool, _ body: (inout Profile) -> Void) throws {
    guard config.appProfiles[bundleID] != nil || creating else {
      throw SettingsEditorError.profileNotFound(.app(bundleID))
    }
    guard ConfigValidator.isBundleID(bundleID) else { throw SettingsEditorError.invalidBundleID(bundleID) }
    var next = config
    var profile = next.appProfiles[bundleID] ?? Profile(bindings: [], inheritsDefault: true)
    body(&profile)
    next.appProfiles[bundleID] = profile
    try commit(next)
  }

  private func refuseWhileBroken() throws {
    if let configProblem { throw SettingsEditorError.readOnly(configProblem) }
  }

  private func commit(_ next: EdgyConfig) throws {
    try refuseWhileBroken()
    guard next != config else { return }
    let before = Set(issues.filter(\.isError))
    let introduced = validator.validate(next).filter { $0.isError && !before.contains($0) }
    guard introduced.isEmpty else { throw SettingsEditorError.invalid(introduced) }

    if continuous != nil {
      set(next, cause: .continuousEdit)
      scheduleContinuousSave()
      return
    }
    try store.save(next)
    pushUndo(config)
    redoStack.removeAll()
    set(next, cause: .edit)
  }

  private func set(_ next: EdgyConfig, cause: SettingsChange.Cause) {
    let previous = config
    config = next
    issues = validator.validate(next)
    applyConfig(next)
    notify(cause, previous: previous)
  }

  private func notify(_ cause: SettingsChange.Cause, previous: EdgyConfig) {
    let change = SettingsChange(cause: cause, config: config, previous: previous)
    for handler in observers.values { handler(change) }
  }

  private func pushUndo(_ snapshot: EdgyConfig) {
    undoStack.append(snapshot)
    if undoStack.count > Self.undoLimit { undoStack.removeFirst(undoStack.count - Self.undoLimit) }
  }

  private func scheduleContinuousSave() {
    pendingSave?.cancel()
    pendingSave = scheduler.schedule(after: Self.continuousSaveDelay) { [weak self] in
      guard let self, self.continuous != nil else { return }
      self.pendingSave = nil
      do {
        try self.store.save(self.config)
      } catch {
        self.logger.log(.error, "Debounced settings save failed: \(error)")
      }
    }
  }

  private func logIssues() {
    for issue in issues { logger.log(issue.isError ? .error : .info, "Config issue: \(issue)") }
  }
}
