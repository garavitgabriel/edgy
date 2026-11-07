import EdgyCore

/// Batch EDGY-GESTURE owns this module.
public enum GesturesInfo {
  public static let module = "Gestures"
}

// FROZEN FACTORY SIGNATURE — the app calls this. Replace the body, never the signature.

/// The gesture pipeline (zone classifier + misfire defense + recognizers).
public func makeGestureRecognizer() -> GestureRecognizing { GesturePipeline() }

/// Additive to the frozen `GestureRecognizing`, adopted by the recognizer `makeGestureRecognizer()`
/// returns (reach it with `as? DeferredGestureFlushing`).
///
/// A recognizer may hold a gesture back: a tap in a zone with a double-tap bound waits for the
/// double-tap window (`GestureContext.doubleTapZones`). While fingers are down, frames keep coming
/// and `process` releases it. After the last finger lifts the device stops sending frames, so the
/// owner must wake the recognizer itself:
///
/// 1. After every `process` (and `flush`), read `nextFlushDeadline`.
/// 2. If it's non-nil, schedule a wake-up at that time and call `flush(now:)` then. Route its events
///    and drive the pointer guard from its `claimedContactIDs` exactly like a `process` output.
///
/// All times are in the frame clock (`TouchFrame.timestamp`). A live owner converts with the last
/// frame it handed over: `now = lastFrame.timestamp + (monotonic time now − monotonic time when that
/// frame arrived)`. `reset()` drops anything pending, so pause and reload never release a stale tap.
public protocol DeferredGestureFlushing: AnyObject {
  /// The earliest frame-clock time at which `flush(now:)` will release something, or nil when
  /// nothing is waiting on a device with no fingers down.
  var nextFlushDeadline: Double? { get }
  /// Releases every held gesture that is due at `now`. Touch state is untouched; the output's
  /// `claimedContactIDs` are the claims still live on every device. Releasing early or twice is
  /// harmless: nothing that isn't due is emitted.
  func flush(now: Double) -> GestureOutput
}

/// A recognizer that never recognizes anything. Kept as an explicit "gestures off" fallback.
final class NoopGestureRecognizer: GestureRecognizing {
  func process(_ frame: TouchFrame, device: TouchDeviceInfo, context: GestureContext) -> GestureOutput {
    GestureOutput()
  }
  func reset() {}
}
