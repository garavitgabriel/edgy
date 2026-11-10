import EdgyCore
import Foundation

/// An app that came to the front, as the activation tracker reports it.
struct AppActivation: Equatable, Sendable {
  var pid: Int32
  var bundleID: String?
  /// A regular app (Dock icon, menu bar). Menu-bar extras, agents and background apps aren't.
  var isRegular: Bool
}

/// Which apps come to the front, and bringing one back (`app.last`).
///
/// Event-driven: the live tracker listens for the workspace's did-activate notification and never
/// polls, so it costs nothing while nobody switches apps (batch 28's idle budget).
protocol AppActivationOutput: AnyObject {
  /// This process. Edgy's own windows never count as an app to go back to.
  var ownPID: Int32 { get }
  /// Starts calling `handler` for every app that comes to the front (on any thread), seeded with
  /// the app in front now. Calling it again does nothing.
  func startObserving(_ handler: @escaping @Sendable (AppActivation) -> Void)
  /// The app in front now, if any.
  func frontmost() -> AppActivation?
  /// Still running (and still the same app: a reused pid with another bundle ID is not).
  func isRunning(_ app: AppActivation) -> Bool
  /// Unhides a running app and brings it to the front. Never launches anything. False when the
  /// system refuses the activation.
  func activate(_ app: AppActivation) -> Bool
}

/// No tracking: `app.last` always finds no previous app.
final class NoAppActivations: AppActivationOutput {
  let ownPID = ProcessInfo.processInfo.processIdentifier
  func startObserving(_ handler: @escaping @Sendable (AppActivation) -> Void) {}
  func frontmost() -> AppActivation? { nil }
  func isRunning(_ app: AppActivation) -> Bool { false }
  func activate(_ app: AppActivation) -> Bool { false }
}

/// Apps in the order they were last in front, most recent first. Pure: the registry feeds it
/// activations and asks it for the app to go back to.
struct AppHistory: Equatable {
  /// Apps remembered; older ones are forgotten.
  static let limit = 16

  private(set) var recent: [AppActivation] = []

  /// An app came to the front. Edgy itself (`ownPID`) and apps that aren't regular never count.
  mutating func record(_ app: AppActivation, ownPID: Int32) {
    guard app.isRegular, app.pid != ownPID else { return }
    recent.removeAll { $0.pid == app.pid }
    recent.insert(app, at: 0)
    if recent.count > Self.limit { recent.removeLast(recent.count - Self.limit) }
  }

  /// The app to bring back: the most recent one that is still running and isn't in front now.
  /// Apps that quit are dropped. `nil` when there is none.
  mutating func previous(frontmostPID: Int32?, isRunning: (AppActivation) -> Bool) -> AppActivation? {
    recent.removeAll { !isRunning($0) }
    return recent.first { $0.pid != frontmostPID }
  }
}
