import Actions
import EdgyCore
import EdgyRuntime
import Foundation

/// How a new app profile starts (BRIEF § App profiles, the add-app flow's step 2).
public enum AppProfileStart: CaseIterable, Sendable {
  case defaultWithChanges, copyOfDefault, empty

  public var title: String {
    switch self {
    case .defaultWithChanges: return "Default, with changes"
    case .copyOfDefault: return "A copy of Default"
    case .empty: return "Empty"
    }
  }

  public var detail: String {
    switch self {
    case .defaultWithChanges: return "Follows Default; change only what's different."
    case .copyOfDefault: return "Starts the same, then goes its own way."
    case .empty: return "Nothing mapped until you add it."
    }
  }

  var editorValue: SettingsEditor.NewAppProfile {
    switch self {
    case .defaultWithChanges: return .inheriting
    case .copyOfDefault: return .copyOfDefault
    case .empty: return .empty
    }
  }
}

/// The top-right switch: it follows the tab (BRIEF § App profiles).
public struct TopSwitch: Equatable, Sendable {
  public var label: String
  public var isOn: Bool
}

/// One gesture-tuning field in the Advanced… sheet, with its unit and the runtime's range.
public enum GestureField: String, CaseIterable, Sendable {
  case edgeWidthMM, cornerSizeMM, dwellMS, palmMajorAxisMM, typingSuppressionMS, doubleTapWindowMS, longPressMS

  public var label: String {
    switch self {
    case .edgeWidthMM: return "Edge width"
    case .cornerSizeMM: return "Corner size"
    case .dwellMS: return "Wait before a slide"
    case .palmMajorAxisMM: return "Palm size"
    case .typingSuppressionMS: return "Ignore after typing"
    case .doubleTapWindowMS: return "Double-tap window"
    case .longPressMS: return "Long-press"
    }
  }

  public var unit: String { rawValue.hasSuffix("MM") ? "mm" : "ms" }

  public var range: ClosedRange<Double> {
    switch self {
    case .edgeWidthMM: return GestureSettingsLimits.edgeWidthMM
    case .cornerSizeMM: return GestureSettingsLimits.cornerSizeMM
    case .dwellMS: return GestureSettingsLimits.dwellMS
    case .palmMajorAxisMM: return GestureSettingsLimits.palmMajorAxisMM
    case .typingSuppressionMS: return GestureSettingsLimits.typingSuppressionMS
    case .doubleTapWindowMS: return GestureSettingsLimits.doubleTapWindowMS
    case .longPressMS: return GestureSettingsLimits.longPressMS
    }
  }

  /// Slider step in the field's own unit.
  public var step: Double {
    switch self {
    case .edgeWidthMM, .cornerSizeMM, .palmMajorAxisMM: return 1
    case .typingSuppressionMS: return 50
    case .dwellMS, .doubleTapWindowMS, .longPressMS: return 10
    }
  }

  public var keyPath: WritableKeyPath<GestureSettings, Double> {
    switch self {
    case .edgeWidthMM: return \.edgeWidthMM
    case .cornerSizeMM: return \.cornerSizeMM
    case .dwellMS: return \.dwellMS
    case .palmMajorAxisMM: return \.palmMajorAxisMM
    case .typingSuppressionMS: return \.typingSuppressionMS
    case .doubleTapWindowMS: return \.doubleTapWindowMS
    case .longPressMS: return \.longPressMS
    }
  }

  /// `value` rounded to the nearest `step` (the slider draws no tick marks; there would be hundreds).
  public func snap(_ value: Double) -> Double { (value / step).rounded() * step }

  /// "8 mm", "300 ms" (proportional figures, a space before the unit).
  public func format(_ value: Double) -> String { "\(Int(value.rounded())) \(unit)" }
}

extension HapticEvent {
  /// The Advanced… sheet's checkbox label.
  public var label: String {
    switch self {
    case .slideSteps: return "Each step of a slide"
    case .slideLimits: return "A level reaches its end"
    case .gestureCaught: return "A slide is caught"
    case .actionFired: return "An action runs"
    }
  }
}

/// The window's behaviour on top of `SettingsModel`. Every change goes through `editor`.
extension SettingsModel {
  static let windowLog = SystemLogger(category: "window")

  /// Runs an edit; a refused edit changes nothing and is logged (the editor already validated it).
  func attempt(_ what: String, _ body: () throws -> Void) {
    do { try body() } catch { Self.windowLog.log(.error, "\(what) refused: \(error)") }
  }

  // MARK: Tabs

  /// Default, then app tabs alphabetically by name.
  public func profileTabs(apps: [InstalledApp] = []) -> [ProfileRef] {
    _ = revision
    let ids = editor.config.appProfiles.keys.sorted {
      let a = WindowCopy.appName(for: $0, in: apps)
      let b = WindowCopy.appName(for: $1, in: apps)
      return a.localizedStandardCompare(b) == .orderedAscending
    }
    return [.default] + ids.map(ProfileRef.app)
  }

  public func tabName(_ ref: ProfileRef, apps: [InstalledApp] = []) -> String {
    switch ref {
    case .default: return "Default"
    case .app(let id): return WindowCopy.appName(for: id, in: apps)
    }
  }

  public func isProfileOff(_ ref: ProfileRef) -> Bool {
    _ = revision
    guard case .app(let id) = ref else { return false }
    return editor.config.appProfiles[id]?.disabled == true
  }

  /// A pre-v0.4 full-replace profile (shows the "doesn't follow Default" note).
  public func isLegacyProfile(_ ref: ProfileRef) -> Bool {
    _ = revision
    guard case .app(let id) = ref, let profile = editor.config.appProfiles[id] else { return false }
    return !profile.inheritsDefault
  }

  public func selectProfile(_ ref: ProfileRef) {
    guard ref != selectedProfile else { return }
    selectedProfile = ref
    picking = nil
  }

  // MARK: The top-right switch

  public func topSwitch(apps: [InstalledApp] = []) -> TopSwitch {
    _ = revision
    switch selectedProfile {
    case .default:
      return TopSwitch(label: "Enabled", isOn: editor.config.app.enabled)
    case .app(let id):
      return TopSwitch(label: "On in \(tabName(selectedProfile, apps: apps))", isOn: !isProfileOff(.app(id)))
    }
  }

  public func setTopSwitch(_ on: Bool) {
    switch selectedProfile {
    case .default: attempt("enabled") { try editor.updateAppSettings { $0.enabled = on } }
    case .app: attempt("profile on") { try editor.setProfileDisabled(!on, for: selectedProfile) }
    }
  }

  // MARK: App profiles

  /// Adds the profile and opens its tab selected.
  public func addAppProfile(bundleID: String, startingFrom start: AppProfileStart) throws {
    try editor.addAppProfile(bundleID: bundleID, startingAs: start.editorValue)
    selectedProfile = .app(bundleID)
    picking = nil
  }

  public func resetAppProfile(bundleID: String) {
    attempt("reset profile") { try editor.resetProfile(.app(bundleID)) }
  }

  /// Removes the profile (the window confirms first) and goes back to Default if it was open.
  public func removeAppProfile(bundleID: String) {
    attempt("remove profile") { try editor.removeAppProfile(bundleID: bundleID) }
    if selectedProfile == .app(bundleID), editor.config.appProfiles[bundleID] == nil {
      selectedProfile = .default
      picking = nil
    }
  }

  /// "Follow Default": converts a legacy full-replace profile without changing what it does.
  public func followDefault(bundleID: String) {
    attempt("follow default") { try editor.convertToInheriting(bundleID: bundleID) }
  }

  // MARK: Issues

  /// The overlap line for the selected zone in the open tab's resolved profile.
  public var selectedZoneOverlap: OverlapNote? {
    _ = revision
    guard let zone = selectedZone else { return nil }
    let profile: Profile
    switch selectedProfile {
    case .default: profile = editor.config.defaultProfile
    case .app(let id): profile = editor.config.profile(for: id)
    }
    return OverlapNote.find(for: zone, in: profile)
  }

  // MARK: Footer

  public func setHaptics(_ on: Bool) { attempt("haptics") { try editor.updateAppSettings { $0.haptics = on } } }

  public func setLaunchAtLogin(_ on: Bool) {
    attempt("launch at login") { try editor.updateAppSettings { $0.launchAtLogin = on } }
  }

  public func setHUD(_ mode: HUDMode) { attempt("hud") { try editor.updateAppSettings { $0.hud = mode } } }

  // MARK: Advanced…

  public func gestureValue(_ field: GestureField) -> Double {
    _ = revision
    return editor.config.gestures[keyPath: field.keyPath]
  }

  /// Writes one tuning value; the editor clamps it into the runtime's range.
  public func setGesture(_ field: GestureField, to value: Double) {
    attempt(field.rawValue) { try editor.updateGestureSettings { $0[keyPath: field.keyPath] = value } }
  }

  public func setFingers(_ fingers: Int) {
    attempt("fingers") { try editor.updateGestureSettings { $0.fingers = fingers } }
  }

  public func setHapticEvent(_ event: HapticEvent, on: Bool) {
    attempt("haptic event") {
      try editor.updateAppSettings { if on { $0.hapticEvents.insert(event) } else { $0.hapticEvents.remove(event) } }
    }
  }

  public func setTickStrength(_ value: Int) {
    attempt("tick strength") { try editor.updateAppSettings { $0.hapticTickStrength = value } }
  }

  public func setClickStrength(_ value: Int) {
    attempt("click strength") { try editor.updateAppSettings { $0.hapticClickStrength = value } }
  }

  /// "The config file said 90 mm; using 30 mm." when the file's value is outside the range.
  public func outOfRangeNote(_ field: GestureField) -> String? {
    _ = revision
    let raw = editor.config.gestures[keyPath: field.keyPath]
    guard !field.range.contains(raw) else { return nil }
    let used = GestureSettingsLimits.clamped(editor.config.gestures)[keyPath: field.keyPath]
    let said = raw.isFinite ? field.format(raw) : "an invalid value"
    return "The config file said \(said); using \(field.format(used))."
  }

  /// A slider drag is one undo step (`beginContinuousEdit` … `endContinuousEdit`).
  public func continuousEdit(_ key: String, began: Bool) {
    if began {
      editor.beginContinuousEdit(key)
    } else {
      attempt("end drag") { try editor.endContinuousEdit() }
    }
  }
}
