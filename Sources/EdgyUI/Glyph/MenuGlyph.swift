import AppKit

/// The menu-bar glyph ("Lit edge", § Menu glyph and app icon, § System states for its variants).
///
/// Skeleton (chief). The popover batch implements it; the state enum is the contract. The artwork
/// is the design export in `Glyph/Assets/glyph-<state>.pdf` (`Bundle.module`, see
/// `docs/design/assets/README.md`); disabled and noTrackpad are the normal artwork at 40% in code.
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
