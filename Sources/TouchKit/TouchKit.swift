import EdgyCore
import Foundation

/// Batch EDGY-TOUCH owns this module.
public enum TouchKitInfo {
  public static let module = "TouchKit"
}

// FROZEN FACTORY SIGNATURES — the app calls these. Replace the bodies, never the signatures.

/// Live multitouch source (private MultitouchSupport bridge + hot-plug + sleep/wake).
public func makeLiveTouchSource() -> TouchSource { NoopTouchSource() }

/// Live pointer guard (keeps the cursor still while a gesture owns a finger).
public func makeLivePointerGuard() -> PointerGuarding { NoopPointerGuard() }

/// Live typing-activity source (used to suppress edge gestures while typing).
public func makeLiveTypingActivitySource() -> TypingActivitySource { NoopTypingActivitySource() }

final class NoopTouchSource: TouchSource, @unchecked Sendable {
  var devices: [TouchDeviceInfo] { [] }
  func start(
    onFrame: @escaping @Sendable (TouchFrame) -> Void,
    onDevicesChanged: @escaping @Sendable ([TouchDeviceInfo]) -> Void
  ) throws {}
  func stop() {}
}

final class NoopPointerGuard: PointerGuarding, @unchecked Sendable {
  func engage() {}
  func release() {}
}

final class NoopTypingActivitySource: TypingActivitySource, @unchecked Sendable {
  var secondsSinceLastKeyPress: TimeInterval? { nil }
}
