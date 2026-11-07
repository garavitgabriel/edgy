import EdgyCore
import EdgyRuntime
import Foundation

/// The parts of `Engine` the UI uses, so previews and snapshot tests can run without one.
public protocol LiveEngine: AnyObject {
  var status: EngineStatus { get }
  var isTestMode: Bool { get }
  func onStatusChange(_ handler: @escaping @Sendable (EngineStatus) -> Void)
  @discardableResult
  func observeFeed(on queue: DispatchQueue, _ handler: @escaping @Sendable (LiveFeedUpdate) -> Void) -> UUID
  func removeFeedObserver(_ id: UUID)
  func setTestMode(_ on: Bool)
  func pause(until: Date?)
  func resume()
}

extension Engine: LiveEngine {}
