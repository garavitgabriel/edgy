import EdgyCore
import EdgyRuntime
import Foundation

/// The overlay's plates over time: which are up, which are fading, and when each goes. Pure and
/// driven by an injected clock (`now`, seconds), so fades are tested without waiting.
///
/// Timings (BRIEF § Level plate and display check, § Hold actions in Test Mode):
/// - A slide's plate (level or Test Mode) stays while the slide runs and fades 1.2 s after it ends.
/// - A hold's plate stays while held; on release it reads "Released fn" for 0.6 s, then fades.
/// - The display check fades after 15 s unanswered.
/// - Other Test Mode plates (taps, swipes, rejections) stay 1.6 s (BRIEF gives no number;
///   long enough to read "Ignored: palm, 21 mm wide, limit 18 mm" once).
/// - Every fade is 200 ms.
/// Plates replace each other per zone; the display check is separate (one at a time).
struct OverlayTimeline {
  static let slideLinger: TimeInterval = 1.2
  static let releaseLinger: TimeInterval = 0.6
  static let displayCheckLinger: TimeInterval = 15
  static let plateLinger: TimeInterval = 1.6
  static let fade: TimeInterval = 0.2
  /// A slide or hold whose end never arrives (a lost lift) still goes after this long.
  static let openLimit: TimeInterval = 130
  /// At most this many plates at once; the oldest goes first.
  static let maxPlates = 6

  struct Entry: Equatable {
    var id: Int
    var content: PlateContent
    var gesture: GestureKind?
    var shownAt: TimeInterval
    /// When the fade starts; `nil` while the gesture is still going (slide, hold).
    var fadeAt: TimeInterval?
  }

  private(set) var entries: [Entry] = []
  private var nextID = 1

  // MARK: Input

  /// Adds the plate for `content` (from `decision`), replacing the plate on the same zone.
  mutating func show(_ content: PlateContent, gesture: GestureKind?, now: TimeInterval) {
    if content.isDisplayCheck {
      entries.removeAll { $0.content.isDisplayCheck }
      append(content, gesture: nil, now: now, fadeAt: now + Self.displayCheckLinger)
      return
    }
    let open = content.kind == .holding || gesture == .slide
    // A slide's update keeps the plate's place in the order; the copy changes in place.
    if let index = entries.firstIndex(where: { !$0.content.isDisplayCheck && $0.content.zone == content.zone }) {
      let sameSlide = entries[index].gesture == .slide && gesture == .slide && entries[index].fadeAt == nil
      if sameSlide {
        entries[index].content = content
        return
      }
      entries.remove(at: index)
    }
    append(content, gesture: gesture, now: now, fadeAt: open ? nil : now + Self.plateLinger)
  }

  /// A gesture phase from the feed: a slide's end starts its fade; a hold's end turns its plate
  /// into "Released …".
  mutating func gesture(zone: Zone, kind: GestureKind, phase: GestureEvent.Phase, now: TimeInterval) {
    guard phase == .ended || phase == .cancelled,
      let index = entries.firstIndex(where: { !$0.content.isDisplayCheck && $0.content.zone == zone })
    else { return }
    let entry = entries[index]
    if entry.content.kind == .holding, kind == .longPress,
      let released = entry.content.released(cancelled: phase == .cancelled)
    {
      entries[index].content = released
      entries[index].fadeAt = now + Self.releaseLinger
    } else if entry.gesture == .slide, kind == .slide, entry.fadeAt == nil {
      entries[index].fadeAt = now + Self.slideLinger
    }
  }

  /// Drops the display check (answered).
  mutating func dismissDisplayCheck() {
    entries.removeAll { $0.content.isDisplayCheck }
  }

  /// Drops every Test Mode plate (Test Mode turned off); level plates and the check stay.
  mutating func dropTestModePlates() {
    entries.removeAll { $0.content.isTestModeOnly }
  }

  mutating func removeAll() { entries = [] }

  // MARK: Time

  /// Removes plates whose fade has finished.
  mutating func tick(now: TimeInterval) {
    entries.removeAll { entry in
      if let fadeAt = entry.fadeAt { return now - fadeAt >= Self.fade - 1e-6 }
      return now >= entry.shownAt + Self.openLimit
    }
  }

  /// 1 until the fade starts, then down to 0 over 200 ms.
  static func opacity(_ entry: Entry, now: TimeInterval) -> Double {
    guard let fadeAt = entry.fadeAt, now > fadeAt else { return 1 }
    return max(0, 1 - (now - fadeAt) / fade)
  }

  // MARK: Private

  private mutating func append(_ content: PlateContent, gesture: GestureKind?, now: TimeInterval, fadeAt: TimeInterval?)
  {
    entries.append(Entry(id: nextID, content: content, gesture: gesture, shownAt: now, fadeAt: fadeAt))
    nextID += 1
    while entries.count > Self.maxPlates {
      if let index = entries.firstIndex(where: { !$0.content.isDisplayCheck }) {
        entries.remove(at: index)
      } else {
        break
      }
    }
  }
}

extension LiveDecision {
  /// The gesture behind a decision, when it names one.
  var plateGesture: GestureKind? {
    switch self {
    case .recognized(_, let kind, _, _), .actionRan(_, _, let kind, _), .actionUpdated(_, _, let kind, _),
      .wouldRun(_, _, let kind), .actionFailed(_, _, let kind, _), .actionUnavailable(_, _, let kind, _):
      return kind
    case .rejected, .displayCheckDue:
      return nil
    }
  }
}
