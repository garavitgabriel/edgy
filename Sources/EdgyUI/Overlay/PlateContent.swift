import Actions
import EdgyCore
import EdgyRuntime
import Foundation

/// One plate's content: what `PlateView` draws, plus where it docks and how long it stays.
/// Built from feed decisions by `PlateContent.from(_:catalog:context:)` (pure).
public struct PlateContent: Hashable, Sendable {
  public enum Kind: Hashable, Sendable {
    /// Test Mode: the action ran ("Volume 64%", "Play/Pause").
    case ran
    /// Dry run: it would have run ("Would set Volume").
    case wouldRun
    /// Test Mode: a touch was turned down ("Ignored: palm, 21 mm wide, limit 18 mm").
    case rejected
    /// A hold is down ("Holding fn", or "Would hold fn" in dry run).
    case holding
    /// The hold came up ("Released fn", "Would release fn", "Released fn, finger left the zone").
    case released
    /// Edgy's own level plate for a change the system draws no indicator for (external
    /// brightness, the keyboard backlight). Shows with or without Test Mode.
    case level
    /// The action threw or can't work here (Test Mode).
    case failed
    /// "Did this screen change brightness?" about the display with this `DisplayInfo.key`.
    case displayCheck(key: String)
  }

  public var kind: Kind
  public var mark: PlateView.Mark
  public var title: String
  public var detail: String?
  /// The touched zone; plates dock at its screen edge or corner and replace each other per zone.
  public var zone: Zone?
  /// The display a level plate (or display check) is about, by name, when it names one.
  public var displayName: String?

  public init(
    kind: Kind, mark: PlateView.Mark, title: String, detail: String? = nil, zone: Zone? = nil,
    displayName: String? = nil
  ) {
    self.kind = kind
    self.mark = mark
    self.title = title
    self.detail = detail
    self.zone = zone
    self.displayName = displayName
  }

  /// Whether this plate is Test Mode's (hidden unless Test Mode is on). Level plates and the
  /// display check replace a system indicator, so they show either way.
  public var isTestModeOnly: Bool {
    switch kind {
    case .level, .displayCheck: return false
    default: return true
    }
  }

  public var isDisplayCheck: Bool {
    if case .displayCheck = kind { return true }
    return false
  }
}

extension PlateContent {
  /// The copy for one feed decision, or `nil` when the decision has no plate of its own
  /// (gesture phases, which the overlay's timeline uses for fades and releases; touches that
  /// started outside a zone; a level change the system already drew).
  ///
  /// - Parameters:
  ///   - catalog: action descriptors by id (names and shapes).
  ///   - context: the bindings in effect and the settings rejections are measured against.
  ///   - dryRun: "Don't run actions" is on (`SettingsModel.isDryRun`); never a level plate then.
  public static func from(
    _ decision: LiveDecision, catalog: [ActionID: ActionDescriptor], context: PlateContext = PlateContext(),
    dryRun: Bool = false
  ) -> PlateContent? {
    switch decision {
    case .recognized:
      return nil

    case .rejected(_, let zone, let reason, _, let measure):
      guard let text = RejectionCopy.text(reason: reason, measure: measure, zone: zone, context: context) else {
        return nil
      }
      return PlateContent(kind: .rejected, mark: .rejected, title: text, zone: zone)

    case .actionRan(let id, let zone, let kind, let outcome):
      return ran(id, zone: zone, kind: kind, outcome: outcome, catalog: catalog, context: context, dryRun: dryRun)

    case .actionUpdated(let id, let zone, let kind, let outcome):
      return ran(id, zone: zone, kind: kind, outcome: outcome, catalog: catalog, context: context, dryRun: dryRun)

    case .wouldRun(let id, let zone, let kind):
      return wouldRun(id, zone: zone, kind: kind, catalog: catalog, context: context)

    case .displayCheckDue(let key, let name):
      if dryRun { return nil }
      return PlateContent(
        kind: .displayCheck(key: key), mark: .none, title: displayCheckQuestion, displayName: name)

    case .actionFailed(let id, let zone, let kind, _):
      return PlateContent(
        kind: .failed, mark: .none, title: "\(PlateNaming.name(id, catalog: catalog)) didn't run",
        detail: PlateNaming.place(zone: zone, kind: kind), zone: zone)

    case .actionUnavailable(let id, let zone, _, let reason):
      return PlateContent(
        kind: .failed, mark: .none, title: "\(PlateNaming.name(id, catalog: catalog)) can't run here",
        detail: reason, zone: zone)

    default:
      return nil
    }
  }

  // MARK: Copy constants (BRIEF § Level plate and display check, § Hold actions in Test Mode)

  public static let displayCheckQuestion = "Did this screen change brightness?"
  public static let displayCheckYes = "Yes"
  public static let displayCheckNo = "No, turn off for this display"
  /// The second line of the keyboard backlight's level plate when the outcome names no keyboard
  /// (an external keyboard's name comes in `ActionOutcome.detail`): "Keyboard 60%" / "Built-in
  /// keyboard" (critique 18 ruling 5, the same pattern as the display name).
  public static let keyboardDevice = "Built-in keyboard"

  /// The plate a hold turns into when it comes up: "Released fn" (or "Would release fn" in dry
  /// run), and ", finger left the zone" when the hold was cancelled. `nil` for any other plate.
  public func released(cancelled: Bool) -> PlateContent? {
    guard kind == .holding else { return nil }
    let dry = title.hasPrefix(Self.wouldHoldPrefix)
    let keys = String(title.dropFirst(dry ? Self.wouldHoldPrefix.count : Self.holdingPrefix.count))
    var next = self
    next.kind = .released
    next.title = (dry ? "Would release " : "Released ") + keys + (cancelled ? ", finger left the zone" : "")
    return next
  }

  // MARK: Private

  private static let holdingPrefix = "Holding "
  private static let wouldHoldPrefix = "Would hold "

  private static func ran(
    _ id: ActionID, zone: Zone, kind: GestureKind, outcome: ActionOutcome?, catalog: [ActionID: ActionDescriptor],
    context: PlateContext, dryRun: Bool
  ) -> PlateContent? {
    let place = PlateNaming.place(zone: zone, kind: kind)
    let parameters = context.parameters(zone: zone, kind: kind)
    if catalog[id]?.shape == .hold {
      let keys = outcome?.detail ?? PlateNaming.keys(parameters) ?? PlateNaming.name(id, catalog: catalog)
      return PlateContent(kind: .holding, mark: .recognized, title: holdingPrefix + keys, detail: place, zone: zone)
    }
    if let level = outcome?.level {
      let title = "\(PlateNaming.levelName(id, catalog: catalog)) \(PlateNumber.percent(level))"
      if outcome?.systemHUDShown == true || dryRun {
        // The system drew its own indicator: Test Mode's plate only, never a level plate.
        return PlateContent(kind: .ran, mark: .recognized, title: title, detail: place, zone: zone)
      }
      let device = outcome?.detail ?? (id == BuiltInAction.keyboardBacklight ? keyboardDevice : nil)
      return PlateContent(
        kind: .level, mark: .level(min(max(level, 0), 1)), title: title, detail: device, zone: zone,
        displayName: id == BuiltInAction.brightness ? outcome?.detail : nil)
    }
    return PlateContent(
      kind: .ran, mark: .recognized, title: runTitle(id, parameters: parameters, catalog: catalog, context: context),
      detail: place, zone: zone)
  }

  private static func wouldRun(
    _ id: ActionID, zone: Zone, kind: GestureKind, catalog: [ActionID: ActionDescriptor], context: PlateContext
  ) -> PlateContent {
    let place = PlateNaming.place(zone: zone, kind: kind)
    let parameters = context.parameters(zone: zone, kind: kind)
    let name = PlateNaming.name(id, catalog: catalog)
    switch catalog[id]?.shape {
    case .hold:
      let keys = PlateNaming.keys(parameters) ?? name
      return PlateContent(kind: .holding, mark: .wouldRun, title: wouldHoldPrefix + keys, detail: place, zone: zone)
    case .continuous:
      return PlateContent(kind: .wouldRun, mark: .wouldRun, title: "Would set \(name)", detail: place, zone: zone)
    default:
      let title =
        PlateNaming.openTarget(id, parameters: parameters, context: context).map { "Would open \($0)" }
        ?? "Would run \(name)"
      return PlateContent(kind: .wouldRun, mark: .wouldRun, title: title, detail: place, zone: zone)
    }
  }

  /// A trigger's run line: the catalog name ("Play/Pause"), or what it did with its parameter
  /// ("Opened Quillpad", "Pressed ⇧⌘ 4").
  private static func runTitle(
    _ id: ActionID, parameters: [String: String], catalog: [ActionID: ActionDescriptor], context: PlateContext
  ) -> String {
    if let target = PlateNaming.openTarget(id, parameters: parameters, context: context) { return "Opened \(target)" }
    if id == BuiltInAction.keyboardShortcut, let keys = PlateNaming.keys(parameters) { return "Pressed \(keys)" }
    if id == BuiltInAction.runShortcut, let name = parameters[ActionParameterKey.shortcutName], !name.isEmpty {
      return "Ran \(name)"
    }
    return PlateNaming.name(id, catalog: catalog)
  }
}
