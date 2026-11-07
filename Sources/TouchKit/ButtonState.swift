import EdgyCore
import Foundation

/// Whether the trackpad's physical button (a click or a force click) is down, read when each frame
/// is handed out, so `TouchFrame.buttonDown` is stamped on the frame that follows the press.
///
/// The multitouch frame callback carries no button state, so the state comes from elsewhere. The
/// live source (`HIDButtonState`) reads the HID system's button state at frame time. Fakes stand in
/// for it in tests.
public protocol ButtonStateSource: AnyObject, Sendable {
  /// Begin answering. Returns false (after logging the one reason why) if the source can't work;
  /// the button then reads as up for every frame. Called by `DeviceManager.start`, never at
  /// construction.
  func start() -> Bool
  /// Stop answering; called by `DeviceManager.stop`.
  func stop()
  /// The primary or secondary button is down right now.
  var isDown: Bool { get }
}

/// No button source: every frame reads as button up (the pre-v0.4 behaviour).
public final class NoButtonState: ButtonStateSource, @unchecked Sendable {
  public init() {}
  public func start() -> Bool { true }
  public func stop() {}
  public var isDown: Bool { false }
}
