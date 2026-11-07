import AppKit
import SwiftUI

/// The design tokens from `docs/BRIEF.md` § Design → Tokens. **The only file in EdgyUI that may
/// contain a colour value, a font size or a radius literal.** Every view reads from here.
public enum Tokens {
  // MARK: Colour (light / dark resolve with the view's appearance)

  /// Primary text, the selection ring, the glyph.
  public static let ink = dynamic(light: 0x3B2219, dark: 0xFBEADB)
  /// Secondary text. Must still reach 4.5:1 on its actual background.
  public static let ink2 = dynamic(light: 0x6B4A3B, dark: 0xD9BFAE)
  /// The one accent. Means "live" only: recognized touch, the live zone, ON switches, the icon dot.
  public static let accent = dynamic(light: 0xB4542B, dark: 0xB4542B)
  /// Mapped zone fill.
  public static let bar = dynamic(light: 0xD9AE8C, dark: 0x7A5646)
  /// Unmapped hairlines and dashed pass-through outlines (≥3:1 on the pad).
  public static let line = dynamic(light: 0x8E6B58, dark: 0xA58676)
  /// Pad slab gradient, top-left lit.
  public static let padTop = dynamic(light: 0xF8E3CE, dark: 0x4A3026)
  public static let padBottom = dynamic(light: 0xEFCCAB, dark: 0x3A251D)
  /// Warm tint laid over the system window material (~0.8 opacity in light; rgba(42,27,21,.82) dark).
  public static let windowTint = dynamic(light: 0xFBE8D8, dark: 0x2A1B15)
  public static let windowTintOpacity = 0.82

  // MARK: Type — one scale, system font only, regular and semibold

  /// Picker group headers only.
  public static let typeSmall: CGFloat = 11
  /// Everything else; the floor.
  public static let typeBody: CGFloat = 13
  /// Plate values, Continue.
  public static let typeValue: CGFloat = 17
  /// The one confident line: the selected zone's name or the onboarding headline.
  public static let typeTitle: CGFloat = 26

  public static func font(_ size: CGFloat, semibold: Bool = false) -> Font {
    .system(size: size, weight: semibold ? .semibold : .regular)
  }

  // MARK: Radii — never one radius for everything, never nested

  public static let radiusControl: CGFloat = 7
  public static let radiusPlate: CGFloat = 13
  /// Zone bars have fully rounded ends: use `Capsule()`.

  // MARK: Pad drawing

  /// Points per millimetre on the settings-window mirror (to scale: the mirror is the pad).
  public static let mirrorPointsPerMM: CGFloat = 3.7
  /// The menu-bar popover's mini mirror.
  public static let miniMirrorPointsPerMM: CGFloat = 1.8

  // MARK: Helpers

  static func dynamic(light: UInt32, dark: UInt32) -> Color {
    Color(
      nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return NSColor(hex: isDark ? dark : light)
      })
  }
}

extension NSColor {
  convenience init(hex: UInt32) {
    self.init(
      srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
      blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
  }
}
