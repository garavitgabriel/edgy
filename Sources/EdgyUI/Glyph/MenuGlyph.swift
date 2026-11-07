import AppKit
import EdgyRuntime

/// The menu-bar glyph ("Lit edge", § Menu glyph and app icon, § System states for its variants).
///
/// The artwork is the design export in `Glyph/Assets/glyph-<state>.pdf` (`docs/design/assets/README.md`):
/// a 16 × 11 pt vector page, pure black, so it works as a template image that macOS tints for
/// light, dark and highlighted menu bars. Disabled and No trackpad are the normal artwork drawn at
/// 40% here; the PDFs carry no opacity.
public enum MenuGlyph {
  public enum State: Hashable, Sendable, CaseIterable {
    case normal
    case testMode
    case paused
    case disabled
    case noTrackpad
    case needsAccessibility
    case brokenConfig

    /// The exported artwork this state draws (`glyph-<name>.pdf`).
    var artwork: String {
      switch self {
      case .normal, .disabled, .noTrackpad: return "normal"
      case .testMode: return "testMode"
      case .paused: return "paused"
      case .needsAccessibility: return "needsAccessibility"
      case .brokenConfig: return "brokenConfig"
      }
    }

    /// Disabled and No trackpad read as the template "off" look: the whole glyph at 40%.
    public var isDimmed: Bool { self == .disabled || self == .noTrackpad }
  }

  /// The glyph's point size: the exported page, 16 × 11 pt.
  public static let size = NSSize(width: 16, height: 11)
  /// Disabled / No trackpad opacity (§ System states).
  public static let dimmedOpacity: CGFloat = 0.4

  @MainActor private static var cache: [State: NSImage] = [:]

  /// A template image, 16 × 11 pt, for `state`. Falls back to an empty template image of the same
  /// size if the artwork is missing from the bundle (it ships with the module; a test checks).
  @MainActor
  public static func image(for state: State) -> NSImage {
    if let cached = cache[state] { return cached }
    let image: NSImage
    if let url = EdgyUIResources.glyphPDF(state.artwork), let art = NSImage(contentsOf: url) {
      art.size = size
      if state.isDimmed {
        image = NSImage(size: size, flipped: false) { rect in
          art.draw(in: rect, from: .zero, operation: .sourceOver, fraction: dimmedOpacity)
          return true
        }
      } else {
        image = art
      }
    } else {
      image = NSImage(size: size)
    }
    image.isTemplate = true
    image.accessibilityDescription = accessibilityLabel(for: state)
    cache[state] = image
    return image
  }

  /// What VoiceOver says for the status item.
  public static func accessibilityLabel(for state: State) -> String {
    switch state {
    case .normal: return "Edgy"
    case .testMode: return "Edgy, Test Mode"
    case .paused: return "Edgy, paused"
    case .disabled: return "Edgy, off"
    case .noTrackpad: return "Edgy, no trackpad connected"
    case .needsAccessibility: return "Edgy needs Accessibility access"
    case .brokenConfig: return "Edgy, config file has an error"
    }
  }

  // MARK: Precedence

  /// The one state the glyph shows when several apply (BRIEF § System states + § Issue states):
  /// **Broken config > No Accessibility > No trackpad > Paused > Disabled > Test Mode**, else Normal.
  public static func state(
    brokenConfig: Bool, needsAccessibility: Bool, hasTrackpad: Bool, paused: Bool, enabled: Bool,
    testMode: Bool
  ) -> State {
    if brokenConfig { return .brokenConfig }
    if needsAccessibility { return .needsAccessibility }
    if !hasTrackpad { return .noTrackpad }
    if paused { return .paused }
    if !enabled { return .disabled }
    if testMode { return .testMode }
    return .normal
  }

  /// The glyph state from the app's live facts.
  ///
  /// - `engine`: `hasTrackpad` (a built-in or external trackpad is attached) and `paused`.
  /// - `editor`: `config.app.enabled` (the global Enabled switch; the same source the settings
  ///   window reads, so both say the same thing).
  /// - `testMode`: the popover's **Test Mode switch** (the overlay is showing), *not*
  ///   `EngineStatus.testMode` / `SettingsModel.isTestMode`, which are only true in a dry run
  ///   ("Don't run actions"). The dot means Test Mode is on either way (§ Test Mode: glyph unchanged).
  /// - `accessibility`: only `.denied` counts; `.unknown` (before the first check) shows nothing,
  ///   like the window's strip, so the glyph never flashes the exclamation at launch.
  /// - `configProblem`: the broken config file on reload, as the app maps it for the window
  ///   (with the real file name). When nil, `editor.configProblem` still counts.
  @MainActor
  public static func state(
    engine: EngineStatus, editor: SettingsEditor, testMode: Bool, accessibility: PermissionState,
    configProblem: ConfigProblem? = nil
  ) -> State {
    state(
      brokenConfig: configProblem != nil || editor.configProblem != nil, needsAccessibility: accessibility == .denied,
      hasTrackpad: engine.hasTrackpad, paused: engine.paused, enabled: editor.config.app.enabled,
      testMode: testMode)
  }
}
