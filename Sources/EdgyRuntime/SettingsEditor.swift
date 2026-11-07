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
  /// removed) so `issues` and later validation see it. Changes no config; no observer call.
  public func refreshAvailability() {
    validator = ConfigValidator(
      catalog: validator.catalog,
      availability: Self.snapshot(catalog: validator.catalog, from: availabilitySource))
    issues = validator.validate(config)
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
    for other in profile(ref)?.bindings ?? [] where other.key != binding.key {
      if ConfigValidator.overlaps(other, binding) {
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

  /// Adds a profile for `bundleID`: empty, or a copy of the default profile's bindings.
  public func addAppProfile(bundleID: String, copyingDefault: Bool = false) throws {
    guard ConfigValidator.isBundleID(bundleID) else { throw SettingsEditorError.invalidBundleID(bundleID) }
    guard config.appProfiles[bundleID] == nil else { throw SettingsEditorError.profileExists(bundleID) }
    var next = config
    next.appProfiles[bundleID] = Profile(bindings: copyingDefault ? config.defaultProfile.bindings : [])
    try commit(next)
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

  /// Default profile → the built-in preset. App profile → a copy of the current default profile's
  /// bindings, enabled (the same thing "add profile, copying default" gives).
  public func resetProfile(_ ref: ProfileRef) throws {
    let preset = EdgyConfig.defaults.defaultProfile
    let copy = Profile(bindings: config.defaultProfile.bindings)
    try mutateProfile(ref) { $0 = ref == .default ? preset : copy }
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
  /// saves never come back as external changes. Errors in it are kept and exposed, never dropped.
  /// A drag in progress is closed as its own undo step but not saved: the file now holds the
  /// external edit, and saving the drag's value would overwrite it.
  public func adoptExternal(_ external: EdgyConfig) {
    try? closeContinuousEdit(save: false)
    guard external != config else { return }
    pushUndo(config)
    redoStack.removeAll()
    set(external, cause: .external)
    logIssues()
  }

  /// Re-reads the file and adopts it. Throws the store's load error (the current config stays).
  public func reloadFromDisk() throws {
    adoptExternal(try store.load())
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

  private func commit(_ next: EdgyConfig) throws {
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
