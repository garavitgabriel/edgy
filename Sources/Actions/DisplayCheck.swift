import EdgyCore

/// "Did this screen change brightness?" A monitor driven over DDC can accept a brightness command
/// without applying it, so the first slides on an unconfirmed one ask the user.
///
/// **How the request travels.** `ActionOutcome` (frozen, in EdgyCore) has no field for it, and the
/// runtime can't import this module. So an external-brightness outcome's `detail` is the display's
/// name, then — only when a check is due — `marker` and the display's key:
///
///     "Desk 34"                               no check due
///     "Desk 34" + marker + "4c2d-7154-9"     check due for display key 4c2d-7154-9
///
/// The runtime's router (`DisplayCheckDetail` in EdgyRuntime, which must use the same `marker`)
/// splits it: the feed's `actionRan` outcome carries the plain name, and a separate
/// `displayCheckDue(key:name:)` decision carries the request. Nobody else reads the raw detail.
///
/// Due means (`ActionRegistry.needsDisplayCheck`): a third-party (DDC) display, not in
/// `AppSettings.confirmedDisplays` or `unresponsiveDisplays`, asked fewer than `maxAsks` times
/// (`AppSettings.displayCheckAsks`).
public struct DisplayCheckRequest: Hashable, Sendable {
  /// The display's `DisplayInfo.key`.
  public var key: String

  /// Unanswered, the question is asked at most this many times per display.
  public static let maxAsks = 3

  /// Separates the name from the key in `ActionOutcome.detail`. A control character that never
  /// appears in a display name. Must match EdgyRuntime's `DisplayCheckDetail.marker`.
  public static let marker = "\u{1E}displayCheck:"

  public init(key: String) {
    self.key = key
  }

  /// The outcome detail for a display named `name`, carrying `request` when one is due.
  public static func detail(name: String, request: DisplayCheckRequest?) -> String {
    guard let request else { return name }
    return name + marker + request.key
  }

  /// Splits a detail built by `detail(name:request:)`.
  public static func parse(_ detail: String) -> (name: String, request: DisplayCheckRequest?) {
    guard let range = detail.range(of: marker) else { return (detail, nil) }
    return (String(detail[..<range.lowerBound]), DisplayCheckRequest(key: String(detail[range.upperBound...])))
  }
}
