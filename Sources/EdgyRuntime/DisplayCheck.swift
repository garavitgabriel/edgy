import EdgyCore

/// The runtime's half of the display-check hand-off (Actions' `DisplayCheckRequest` is the other).
///
/// `ActionOutcome` is frozen and EdgyRuntime can't import Actions, so an external-brightness
/// outcome's `detail` carries "<display name>" + `marker` + "<display key>" when a check is due.
/// The router splits it: the feed gets the plain name in the outcome, and the request separately
/// as `LiveDecision.displayCheckDue(key:name:)`.
enum DisplayCheckDetail {
  /// Must equal Actions' `DisplayCheckRequest.marker` (pinned by a test on each side).
  static let marker = "\u{1E}displayCheck:"

  struct Request: Hashable {
    var key: String
    var name: String
  }

  /// The outcome with any request removed from its detail, and the request.
  static func split(_ outcome: ActionOutcome?) -> (ActionOutcome?, Request?) {
    guard var outcome, let detail = outcome.detail, let range = detail.range(of: marker) else {
      return (outcome, nil)
    }
    let name = String(detail[..<range.lowerBound])
    outcome.detail = name
    return (outcome, Request(key: String(detail[range.upperBound...]), name: name))
  }

  /// Whether two outcomes draw the same level plate: the same whole percent and detail.
  static func samePlate(_ a: ActionOutcome, _ b: ActionOutcome?) -> Bool {
    guard let b else { return false }
    return percent(a.level) == percent(b.level) && a.detail == b.detail && a.systemHUDShown == b.systemHUDShown
  }

  static func percent(_ level: Double?) -> Int? {
    level.map { Int(($0 * 100).rounded()) }
  }
}
