import EdgyCore

/// Batch EDGY-GESTURE owns this module.
public enum GesturesInfo {
  public static let module = "Gestures"
}

// FROZEN FACTORY SIGNATURE — the app calls this. Replace the body, never the signature.

/// The gesture pipeline (zone classifier + misfire defense + recognizers).
public func makeGestureRecognizer() -> GestureRecognizing { GesturePipeline() }

/// A recognizer that never recognizes anything. Kept as an explicit "gestures off" fallback.
final class NoopGestureRecognizer: GestureRecognizing {
  func process(_ frame: TouchFrame, device: TouchDeviceInfo, context: GestureContext) -> GestureOutput {
    GestureOutput()
  }
  func reset() {}
}
