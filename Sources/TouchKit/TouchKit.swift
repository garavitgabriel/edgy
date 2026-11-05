import EdgyCore
import Foundation

/// Batch EDGY-TOUCH owns this module.
public enum TouchKitInfo {
  public static let module = "TouchKit"
}

// FROZEN FACTORY SIGNATURES — the app calls these. Replace the bodies, never the signatures.

/// Live multitouch source (private MultitouchSupport bridge + hot-plug + sleep/wake).
public func makeLiveTouchSource() -> TouchSource { LiveTouchSource() }

/// Live pointer guard (keeps the cursor still while a gesture owns a finger).
public func makeLivePointerGuard() -> PointerGuarding {
  PointerGuardCore(tap: LiveEventTap(), cursor: LiveCursor(), scheduler: DispatchGuardScheduler())
}

/// Live typing-activity source (used to suppress edge gestures while typing).
public func makeLiveTypingActivitySource() -> TypingActivitySource {
  TypingActivityCore(monitor: LiveKeyMonitor(), isPermitted: { LivePermissions.isAccessibilityTrusted() })
}

/// Whether this process is trusted for Accessibility (event tap + key monitor). Never prompts.
public func isAccessibilityTrusted() -> Bool { LivePermissions.isAccessibilityTrusted() }

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
