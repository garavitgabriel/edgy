import Foundation

/// EdgyUI's bundled resources (chief). The design exports live in `Glyph/Assets/`.
public enum EdgyUIResources {
  /// The exported glyph PDF for a state name (`glyph-<state>.pdf`), or nil if missing.
  public static func glyphPDF(_ state: String) -> URL? {
    Bundle.module.url(forResource: "glyph-\(state)", withExtension: "pdf", subdirectory: "Assets")
  }
}
