import AppKit

/// The menu-bar glyph ("Lit edge", § Menu glyph and app icon, § System states for its variants).
///
/// Skeleton (chief). The popover batch draws it; the state enum is the contract.
public enum MenuGlyph {
  public enum State: Hashable, Sendable {
    case normal
    case testMode
    case paused
    case disabled
    case noTrackpad
    case needsAccessibility
    case brokenConfig
  }

  /// A template image, about 16 × 11 pt.
  @MainActor
  public static func image(for state: State) -> NSImage {
    let image = NSImage(size: NSSize(width: 16, height: 11))
    image.isTemplate = true
    return image
  }
}
