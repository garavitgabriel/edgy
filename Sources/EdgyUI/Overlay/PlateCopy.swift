import Actions
import EdgyCore
import EdgyRuntime
import Foundation

/// What the copy mapper needs beyond the decision itself: the bindings in effect (for parameter
/// values the feed doesn't carry, like "Would open Quillpad" or "Would hold fn"), app names, and
/// the settings a rejection's measure is compared against.
public struct PlateContext: Sendable {
  /// The bindings of the profile in effect for the frontmost app (`EdgyConfig.profile(for:)`).
  public var bindings: [Binding]
  /// Display names by bundle ID; a missing one falls back to the bundle ID's last part.
  public var appNames: [String: String]
  /// The frontmost app's name when its profile turns Edgy off (`Profile.disabled`): the runtime
  /// then reports every edge touch as `disabledZone`, and the plate says "Edgy is off in Huddle".
  public var offInApp: String?
  /// `GestureSettings.palmMajorAxisMM`: tells a major-axis palm ("wide") from a round one
  /// ("across"), whose limit is the recognizer's fixed minor-axis limit.
  public var palmMajorAxisMM: Double

  public init(
    bindings: [Binding] = [], appNames: [String: String] = [:], offInApp: String? = nil,
    palmMajorAxisMM: Double = GestureSettings.defaults.palmMajorAxisMM
  ) {
    self.bindings = bindings
    self.appNames = appNames
    self.offInApp = offInApp
    self.palmMajorAxisMM = palmMajorAxisMM
  }

  /// The parameters of the binding on this slot, empty when none.
  func parameters(zone: Zone, kind: GestureKind) -> [String: String] {
    bindings.first { $0.zone == zone && $0.gesture == kind }?.parameters ?? [:]
  }

  func appName(_ bundleID: String) -> String {
    if let name = appNames[bundleID] { return name }
    let last = bundleID.split(separator: ".").last.map(String.init) ?? bundleID
    return last.prefix(1).uppercased() + last.dropFirst()
  }
}

extension PlateContext {
  /// The context for the app in front now, from the model's settings.
  @MainActor
  static func current(model: SettingsModel, appNames: [String: String] = [:]) -> PlateContext {
    let config = model.editor.config
    let front = model.frontmostBundleID
    let profile = config.profile(for: front)
    var context = PlateContext(
      bindings: profile.bindings, appNames: appNames, palmMajorAxisMM: config.gestures.palmMajorAxisMM)
    if let front, profile.disabled { context.offInApp = context.appName(front) }
    return context
  }
}

/// Number and unit formatting for plate copy (BRIEF bone 4): one decimal place only when the
/// value is under 10 and not whole ("3.4 mm"), otherwise whole ("21 mm", "410 ms").
enum PlateNumber {
  static func text(_ value: Double) -> String {
    if abs(value) < 10 {
      let tenths = (value * 10).rounded() / 10
      if tenths == tenths.rounded() { return String(Int(tenths)) }
      return String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), tenths)
    }
    return String(Int(value.rounded()))
  }

  static func text(_ value: Double, _ unit: RejectionMeasure.Unit) -> String {
    switch unit {
    case .mm: return "\(text(value)) mm"
    case .ms: return "\(text(value)) ms"
    case .mmPerSecond: return "\(text(value)) mm/s"
    case .fingers:
      let count = Int(value.rounded())
      return count == 1 ? "1 finger" : "\(count) fingers"
    }
  }

  /// "64%": whole percent, no space before %.
  static func percent(_ level: Double) -> String { "\(Int((min(max(level, 0), 1) * 100).rounded()))%" }
}

/// The rejection plate's one line (BRIEF bone 4's table): "Ignored: <reason>, <measured>, limit
/// <limit>", from the runtime's `RejectionMeasure` in its own unit.
enum RejectionCopy {
  /// The recognizer's fixed limits (`Gestures.Tuning`, internal to that module). A
  /// `RejectionMeasure` doesn't say which check produced it, so the limit tells the variants of
  /// one reason apart. Mirror of: `palmMinorAxisMM` 14, `perpendicularDecideMM` 2.5 (edge,
  /// toward the edge), `diagonalDecideMM` 3 (edge, no clear direction). A swipe that veered uses
  /// its own along-travel as the limit.
  static let edgeOutwardLimitMM = 2.5
  static let edgeDiagonalLimitMM = 3.0

  static func text(
    reason: RejectionReason, measure: RejectionMeasure?, zone: Zone?, context: PlateContext
  ) -> String? {
    let body: String
    switch reason {
    case .startedOutsideZone:
      // Ordinary pointer use; the overlay never surfaces it (bone 4).
      return nil
    case .palm:
      guard let measure, measure.unit == .mm else {
        body = "palm"
        break
      }
      let shape = measure.limit == context.palmMajorAxisMM ? "wide" : "across"
      body = "palm, \(PlateNumber.text(measure.measured, .mm)) \(shape), limit \(PlateNumber.text(measure.limit, .mm))"
    case .typing:
      guard let measure, measure.unit == .ms else {
        body = "typing"
        break
      }
      body =
        "typing, last key \(PlateNumber.text(measure.measured, .ms)) ago, limit \(PlateNumber.text(measure.limit, .ms))"
    case .tooManyContacts:
      guard let measure, measure.unit == .fingers else {
        body = "too many fingers"
        break
      }
      body = "\(PlateNumber.text(measure.measured, .fingers)), set to \(Int(measure.limit.rounded()))"
    case .offAxisMotion:
      body = offAxis(measure, zone: zone)
    case .tooFast:
      body = tooFast(measure)
    case .systemGestureHandoff:
      body = "system gesture"
    case .physicalClick:
      body = "click"
    case .disabledZone:
      body = context.offInApp.map { "Edgy is off in \($0)" } ?? "nothing mapped here"
    }
    return "Ignored: \(body)"
  }

  private static func offAxis(_ measure: RejectionMeasure?, zone: Zone?) -> String {
    guard let measure, measure.unit == .mm else { return "no clear direction" }
    let moved = PlateNumber.text(measure.measured, .mm)
    let limit = PlateNumber.text(measure.limit, .mm)
    if case .corner = zone { return "moved \(moved) before the long-press, limit \(limit)" }
    switch measure.limit {
    case edgeOutwardLimitMM: return "moved \(moved) toward the edge, limit \(limit)"
    case edgeDiagonalLimitMM: return "no clear direction, moved \(moved), limit \(limit)"
    default: return "swipe veered, \(moved) across, \(limit) along"
    }
  }

  private static func tooFast(_ measure: RejectionMeasure?) -> String {
    guard let measure else { return "swipe had no clear direction" }
    switch measure.unit {
    case .ms:
      return "swipe too slow, \(PlateNumber.text(measure.measured, .ms)), limit \(PlateNumber.text(measure.limit, .ms))"
    case .mm:
      return
        "swipe too short, \(PlateNumber.text(measure.measured, .mm)), needs \(PlateNumber.text(measure.limit, .mm))"
    case .fingers, .mmPerSecond:
      return
        "swipe, \(PlateNumber.text(measure.measured, measure.unit)), limit \(PlateNumber.text(measure.limit, measure.unit))"
    }
  }
}

/// Names and verbs for run plates.
enum PlateNaming {
  /// "Right edge, slide" (the plate's second line).
  static func place(zone: Zone, kind: GestureKind) -> String {
    "\(ZoneNaming.title(zone)), \(GestureNaming.lower(kind))"
  }

  /// The catalog's name as the pad spells it ("Play/Pause" becomes "Play/Pause").
  static func name(_ id: ActionID, catalog: [ActionID: ActionDescriptor]) -> String {
    catalog[id]?.displayName.replacingOccurrences(of: " / ", with: "/") ?? id.rawValue
  }

  /// What a level plate calls the thing it changed: "Volume", "Brightness", "Keyboard".
  static func levelName(_ id: ActionID, catalog: [ActionID: ActionDescriptor]) -> String {
    id == BuiltInAction.keyboardBacklight ? "Keyboard" : name(id, catalog: catalog)
  }

  /// The held keys as the user reads them ("fn", "⌃⌥ Space"), from the binding's `keys`.
  static func keys(_ parameters: [String: String]) -> String? {
    parameters[ActionParameterKey.keys].flatMap(KeyCombo.init).map(\.displayText)
  }

  /// The object of "open": the app's name, the URL's host, the file's name.
  static func openTarget(_ id: ActionID, parameters: [String: String], context: PlateContext) -> String? {
    switch id.rawValue {
    case BuiltInAction.openApp.rawValue: return parameters[ActionParameterKey.bundleID].map(context.appName)
    case BuiltInAction.openURL.rawValue:
      return parameters[ActionParameterKey.url].map { URL(string: $0)?.host ?? $0 }
    case BuiltInAction.openFile.rawValue:
      return parameters[ActionParameterKey.path].map { ($0 as NSString).lastPathComponent }
    default: return nil
    }
  }
}
