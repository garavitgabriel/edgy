import EdgyCore

/// First-run defaults that work on this Mac: `EdgyConfig.defaults` with every binding whose action
/// can't work here swapped for a sensible alternative, or dropped when there is none.
///
/// Substitution table (first candidate that is in the catalog, fits the gesture, is usable here
/// and validates wins; `limited` counts as usable):
///
/// | Unavailable | Alternatives, in order | Why |
/// |---|---|---|
/// | `display.brightness` | `apps.switcher`, then `keyboard.slideSteps` zoom (⌘= / ⌘−) | A Mac without a built-in display or a controllable monitor (desktop + third-party display) still has apps to switch between; zoom is the generic fallback for a vertical slide |
/// | `keyboard.backlight` | `display.brightness` | The closest "level" slide |
/// | anything else | — (binding dropped) | Volume, mute, media keys and the mic toggle have no meaningful stand-in; an empty zone beats one that silently does nothing |
///
/// Only bindings whose action is `.unavailable` are touched; the rest of the config is the base.
public enum MachineDefaults {
  /// One candidate for a replacement binding (same zone and gesture, new action + parameters).
  public struct Alternative: Hashable, Sendable {
    public var action: ActionID
    public var parameters: [String: String]

    public init(_ action: ActionID, parameters: [String: String] = [:]) {
      self.action = action
      self.parameters = parameters
    }
  }

  /// What `build` did to one binding.
  public struct Substitution: Hashable, Sendable {
    public var profile: ProfileRef
    public var original: Binding
    /// `nil` when the binding was dropped.
    public var replacement: Binding?
  }

  public static let alternatives: [ActionID: [Alternative]] = [
    "display.brightness": [
      Alternative("apps.switcher"),
      Alternative("keyboard.slideSteps", parameters: ["upKeys": "cmd+equal", "downKeys": "cmd+minus"]),
    ],
    "keyboard.backlight": [Alternative("display.brightness")],
  ]

  /// `base` with unavailable bindings substituted or dropped, in every profile, plus what changed.
  public static func build(
    from base: EdgyConfig = .defaults, catalog: [ActionDescriptor],
    availability: (ActionID) -> ActionAvailability
  ) -> (config: EdgyConfig, substitutions: [Substitution]) {
    let snapshot = Dictionary(
      catalog.map { ($0.id, availability($0.id)) }, uniquingKeysWith: { first, _ in first })
    let validator = ConfigValidator(catalog: catalog, availability: snapshot)
    var config = base
    var substitutions: [Substitution] = []
    func fix(_ profile: Profile, _ ref: ProfileRef) -> Profile {
      var result = profile
      result.bindings = profile.bindings.compactMap { binding in
        guard !validator.availability(of: binding.action).isUsable else { return binding }
        let replacement = replacement(for: binding, in: profile, validator: validator)
        substitutions.append(Substitution(profile: ref, original: binding, replacement: replacement))
        return replacement
      }
      return result
    }
    config.defaultProfile = fix(base.defaultProfile, .default)
    for id in base.appProfiles.keys.sorted() {
      config.appProfiles[id] = fix(base.appProfiles[id]!, .app(id))
    }
    return (config, substitutions)
  }

  /// `build` against a live registry: its catalog and its `availability(of:)`.
  public static func build(from base: EdgyConfig = .defaults, actions: ActionPerforming) -> EdgyConfig {
    build(from: base, catalog: actions.available, availability: actions.availability(of:)).config
  }

  private static func replacement(for binding: Binding, in profile: Profile, validator: ConfigValidator)
    -> Binding?
  {
    let taken = Set(profile.bindings.map(\.action))
    for alternative in alternatives[binding.action] ?? [] where !taken.contains(alternative.action) {
      let candidate = Binding(
        zone: binding.zone, gesture: binding.gesture, action: alternative.action, parameters: alternative.parameters)
      let issues = validator.validate(candidate)
      if !issues.contains(where: { $0.isError || $0.code == .actionUnavailable }) { return candidate }
    }
    return nil
  }
}
