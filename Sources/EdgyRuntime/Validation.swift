import EdgyCore
import Foundation

/// Addresses one profile in an `EdgyConfig`.
public enum ProfileRef: Hashable, Sendable, CustomStringConvertible {
  /// `EdgyConfig.defaultProfile`.
  case `default`
  /// `EdgyConfig.appProfiles[bundleID]`.
  case app(String)

  public var description: String {
    switch self {
    case .default: return "default"
    case .app(let bundleID): return bundleID
    }
  }
}

/// A binding's slot in a profile. A profile holds at most one binding per key.
public struct BindingKey: Hashable, Sendable {
  public var zone: Zone
  public var gesture: GestureKind

  public init(zone: Zone, gesture: GestureKind) {
    self.zone = zone
    self.gesture = gesture
  }
}

extension Binding {
  public var key: BindingKey { BindingKey(zone: zone, gesture: gesture) }
}

/// One problem found in a binding or config. Equality ignores nothing: two issues are the same
/// when they have the same code at the same place, which is how the editor tells a pre-existing
/// problem from one an edit would introduce.
public struct ValidationIssue: Hashable, Sendable, CustomStringConvertible {
  public enum Severity: String, Sendable {
    /// Blocks an edit that would introduce it.
    case error
    /// Shown to the user; never blocks.
    case warning
  }

  /// Stable codes the settings UI maps to copy. Raw values are part of the contract: never rename.
  public enum Code: String, CaseIterable, Sendable {
    /// The action id is not in the catalog.
    case unknownAction
    /// A continuous action on a non-slide gesture, or a trigger action on a slide.
    case shapeMismatch
    /// `Zone.supports(gesture)` is false (e.g. a slide in a corner).
    case gestureNotSupported
    /// Edge `segments` outside 1…4, or `segment` outside `0..<segments`.
    case segmentOutOfRange
    /// A required action parameter is absent or empty.
    case missingParameter
    /// A `keyCombo` parameter that `KeyCombo` can't parse.
    case invalidKeyCombo
    /// A `url` parameter without a scheme.
    case invalidURL
    /// A `number` parameter that isn't a number.
    case notANumber
    /// A `number` parameter outside its range.
    case numberOutOfRange
    /// A `choice` parameter that isn't one of the choices.
    case invalidChoice
    /// An `appBundleID` parameter that is empty or has no dot.
    case invalidBundleID
    /// A `filePath` parameter that is neither absolute nor `~`-prefixed.
    case invalidFilePath
    /// A parameter key the action doesn't read (warning).
    case unknownParameter
    /// Two bindings with the same zone and gesture in one profile.
    case duplicateBinding
    /// Two different zones on the same edge overlap and are bound to the same gesture, e.g. the
    /// whole edge and one of its segments (warning: only one of them can win).
    case overlappingZones
    /// An app profile keyed by something that isn't a bundle identifier.
    case invalidProfileID
    /// A gesture setting outside `GestureSettingsLimits` (warning: the editor clamps on edit).
    case settingOutOfRange
  }

  public var severity: Severity
  public var code: Code
  public var profile: ProfileRef?
  public var binding: BindingKey?
  public var action: ActionID?
  /// Parameter key, or gesture-setting name for `settingOutOfRange`.
  public var parameter: String?

  public init(
    _ severity: Severity, _ code: Code, profile: ProfileRef? = nil, binding: BindingKey? = nil,
    action: ActionID? = nil, parameter: String? = nil
  ) {
    self.severity = severity
    self.code = code
    self.profile = profile
    self.binding = binding
    self.action = action
    self.parameter = parameter
  }

  public var isError: Bool { severity == .error }

  /// For logs only; the UI writes its own copy from `code`.
  public var description: String {
    var parts = ["\(severity.rawValue): \(code.rawValue)"]
    if let profile { parts.append("profile \(profile)") }
    if let binding { parts.append("\(binding.gesture) at \(binding.zone)") }
    if let action { parts.append("action \(action.rawValue)") }
    if let parameter { parts.append("'\(parameter)'") }
    return parts.joined(separator: ", ")
  }
}

/// Sane ranges for every `GestureSettings` value. The editor clamps edits into them; values
/// outside them in a hand-edited file produce a `settingOutOfRange` warning.
///
/// | Setting | Range | Why |
/// |---|---|---|
/// | `edgeWidthMM` | 3…20 mm | narrower is hard to hit; wider eats the trackpad |
/// | `cornerSizeMM` | 5…30 mm | same, for corner squares |
/// | `dwellMS` | 0…1000 ms | 0 = claim at once; past 1 s a slide feels broken |
/// | `palmMajorAxisMM` | 10…40 mm | below 10 rejects fingertips |
/// | `typingSuppressionMS` | 0…3000 ms | 0 = off |
/// | `doubleTapWindowMS` | 150…800 ms | the usual double-click range |
/// | `longPressMS` | 250…2000 ms | shorter collides with taps |
/// | `fingers` | 1…2 | what the recognizer supports |
public enum GestureSettingsLimits {
  public static let edgeWidthMM: ClosedRange<Double> = 3...20
  public static let cornerSizeMM: ClosedRange<Double> = 5...30
  public static let dwellMS: ClosedRange<Double> = 0...1000
  public static let palmMajorAxisMM: ClosedRange<Double> = 10...40
  public static let typingSuppressionMS: ClosedRange<Double> = 0...3000
  public static let doubleTapWindowMS: ClosedRange<Double> = 150...800
  public static let longPressMS: ClosedRange<Double> = 250...2000
  public static let fingers: ClosedRange<Int> = 1...2

  /// `settings` with every value clamped; non-finite values fall back to the default.
  public static func clamped(_ settings: GestureSettings) -> GestureSettings {
    let d = GestureSettings.defaults
    var s = settings
    s.edgeWidthMM = clamp(s.edgeWidthMM, edgeWidthMM, fallback: d.edgeWidthMM)
    s.cornerSizeMM = clamp(s.cornerSizeMM, cornerSizeMM, fallback: d.cornerSizeMM)
    s.dwellMS = clamp(s.dwellMS, dwellMS, fallback: d.dwellMS)
    s.palmMajorAxisMM = clamp(s.palmMajorAxisMM, palmMajorAxisMM, fallback: d.palmMajorAxisMM)
    s.typingSuppressionMS = clamp(s.typingSuppressionMS, typingSuppressionMS, fallback: d.typingSuppressionMS)
    s.doubleTapWindowMS = clamp(s.doubleTapWindowMS, doubleTapWindowMS, fallback: d.doubleTapWindowMS)
    s.longPressMS = clamp(s.longPressMS, longPressMS, fallback: d.longPressMS)
    s.fingers = min(max(s.fingers, fingers.lowerBound), fingers.upperBound)
    return s
  }

  /// Names of the settings that are outside their range (or not finite).
  public static func outOfRange(_ s: GestureSettings) -> [String] {
    let checks: [(String, Double, ClosedRange<Double>)] = [
      ("edgeWidthMM", s.edgeWidthMM, edgeWidthMM), ("cornerSizeMM", s.cornerSizeMM, cornerSizeMM),
      ("dwellMS", s.dwellMS, dwellMS), ("palmMajorAxisMM", s.palmMajorAxisMM, palmMajorAxisMM),
      ("typingSuppressionMS", s.typingSuppressionMS, typingSuppressionMS),
      ("doubleTapWindowMS", s.doubleTapWindowMS, doubleTapWindowMS), ("longPressMS", s.longPressMS, longPressMS),
    ]
    var names = checks.filter { !$0.1.isFinite || !$0.2.contains($0.1) }.map(\.0)
    if !fingers.contains(s.fingers) { names.append("fingers") }
    return names
  }

  private static func clamp(_ value: Double, _ range: ClosedRange<Double>, fallback: Double) -> Double {
    guard value.isFinite else { return fallback }
    return min(max(value, range.lowerBound), range.upperBound)
  }
}

/// Checks bindings and whole configs against an action catalog. Pure: no I/O, no state.
public struct ConfigValidator: Sendable {
  /// Parameters every binding may carry regardless of action.
  public static let crossCuttingParameters: Set<String> = [AppSettings.hapticsParameter, "sensitivity"]
  /// Valid `segments` counts for a split edge.
  public static let segmentCounts = 1...4

  public let catalog: [ActionDescriptor]
  private let byID: [ActionID: ActionDescriptor]

  public init(catalog: [ActionDescriptor]) {
    self.catalog = catalog
    self.byID = Dictionary(catalog.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
  }

  public func descriptor(for id: ActionID) -> ActionDescriptor? { byID[id] }

  /// Problems with one binding on its own (action, shape, zone, segment, parameters).
  public func validate(_ binding: Binding, in profile: ProfileRef = .default) -> [ValidationIssue] {
    var issues: [ValidationIssue] = []
    func add(_ severity: ValidationIssue.Severity, _ code: ValidationIssue.Code, parameter: String? = nil) {
      issues.append(
        ValidationIssue(
          severity, code, profile: profile, binding: binding.key, action: binding.action, parameter: parameter))
    }

    if case .edge(_, let segment, let segments) = binding.zone,
      !Self.segmentCounts.contains(segments) || !(0..<max(segments, 0)).contains(segment)
    {
      add(.error, .segmentOutOfRange)
    }
    if !binding.zone.supports(binding.gesture) { add(.error, .gestureNotSupported) }

    guard let descriptor = byID[binding.action] else {
      add(.error, .unknownAction)
      return issues
    }
    let isSlide = binding.gesture == .slide
    if (descriptor.shape == .continuous) != isSlide { add(.error, .shapeMismatch) }

    for parameter in descriptor.parameters {
      let value = binding.parameters[parameter.key]
      guard let value, !value.trimmingCharacters(in: .whitespaces).isEmpty else {
        if parameter.required { add(.error, .missingParameter, parameter: parameter.key) }
        continue
      }
      if let code = Self.check(value, against: parameter.kind) { add(.error, code, parameter: parameter.key) }
    }
    let known = Set(descriptor.parameters.map(\.key)).union(Self.crossCuttingParameters)
    for key in binding.parameters.keys.sorted() where !known.contains(key) {
      add(.warning, .unknownParameter, parameter: key)
    }
    return issues
  }

  /// Every problem in a config: each binding, plus profile-level and settings checks.
  public func validate(_ config: EdgyConfig) -> [ValidationIssue] {
    var issues: [ValidationIssue] = []
    for name in GestureSettingsLimits.outOfRange(config.gestures) {
      issues.append(ValidationIssue(.warning, .settingOutOfRange, parameter: name))
    }
    issues += validate(config.defaultProfile, as: .default)
    for bundleID in config.appProfiles.keys.sorted() {
      let ref = ProfileRef.app(bundleID)
      if !Self.isBundleID(bundleID) { issues.append(ValidationIssue(.error, .invalidProfileID, profile: ref)) }
      issues += validate(config.appProfiles[bundleID]!, as: ref)
    }
    return issues
  }

  /// Bindings plus duplicate and overlap checks within one profile.
  public func validate(_ profile: Profile, as ref: ProfileRef) -> [ValidationIssue] {
    var issues: [ValidationIssue] = []
    var seen: Set<BindingKey> = []
    for (index, binding) in profile.bindings.enumerated() {
      issues += validate(binding, in: ref)
      if !seen.insert(binding.key).inserted {
        issues.append(
          ValidationIssue(.error, .duplicateBinding, profile: ref, binding: binding.key, action: binding.action))
      }
      for other in profile.bindings[..<index] where Self.overlaps(other, binding) {
        issues.append(
          ValidationIssue(.warning, .overlappingZones, profile: ref, binding: binding.key, action: binding.action))
      }
    }
    return issues
  }

  /// True when two bindings use the same gesture on different but overlapping parts of one edge.
  public static func overlaps(_ a: Binding, _ b: Binding) -> Bool {
    guard a.gesture == b.gesture, a.zone != b.zone,
      case .edge(let edgeA, let segA, let countA) = a.zone, case .edge(let edgeB, let segB, let countB) = b.zone,
      edgeA == edgeB, countA > 0, countB > 0
    else { return false }
    // Compare [seg/count, (seg+1)/count) intervals with integer cross-multiplication.
    return segA * countB < (segB + 1) * countA && segB * countA < (segA + 1) * countB
  }

  /// The `Code` for a value that fails its kind's check, or `nil` if it passes.
  public static func check(_ value: String, against kind: ActionParameter.Kind) -> ValidationIssue.Code? {
    let trimmed = value.trimmingCharacters(in: .whitespaces)
    switch kind {
    case .text:
      return nil
    case .keyCombo:
      return KeyCombo(trimmed) == nil ? .invalidKeyCombo : nil
    case .url:
      guard let url = URL(string: trimmed), let scheme = url.scheme, !scheme.isEmpty else { return .invalidURL }
      return nil
    case .appBundleID:
      return isBundleID(trimmed) ? nil : .invalidBundleID
    case .filePath:
      return trimmed.hasPrefix("/") || trimmed == "~" || trimmed.hasPrefix("~/") ? nil : .invalidFilePath
    case .number(let range):
      guard let number = Double(trimmed), number.isFinite else { return .notANumber }
      return range.contains(number) ? nil : .numberOutOfRange
    case .choice(let choices):
      return choices.contains(trimmed) ? nil : .invalidChoice
    }
  }

  /// Non-empty, no whitespace, and at least one dot between non-empty parts.
  public static func isBundleID(_ text: String) -> Bool {
    let parts = text.split(separator: ".", omittingEmptySubsequences: false)
    return parts.count >= 2 && !parts.contains(where: \.isEmpty)
      && !text.contains(where: { $0.isWhitespace })
  }
}
