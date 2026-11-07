import AppKit
import EdgyRuntime
import SwiftUI

/// The window's warm glass: the system material behind the window, tinted with
/// `Tokens.windowTint`. Headless snapshots render it flat; judge it on the device.
public struct WindowMaterial: View {
  public init() {}

  public var body: some View {
    ZStack {
      VisualEffect()
      Tokens.windowTint.opacity(Tokens.windowTintOpacity)
    }
    .ignoresSafeArea()
  }

  private struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
      let view = NSVisualEffectView()
      view.material = .underWindowBackground
      view.blendingMode = .behindWindow
      view.state = .followsWindowActiveState
      return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
  }
}

/// Window layout constants (sizes, not colours, type or radii; those live in `Tokens`).
enum WindowMetrics {
  /// The largest pad the mirror must show to scale (an external trackpad's sensor).
  static let largestPadMM = CGSize(width: 160, height: 115)
  static let mirrorMargin: CGFloat = 40
  /// Wide enough for the longest parameter label ("Keep open between strokes") on one line beside
  /// its slider and value, at the inspector's 22 pt inset.
  static let inspectorWidth: CGFloat = 360
  static let tabBarHeight: CGFloat = 52
  static let footerHeight: CGFloat = 56
  static let stripHeight: CGFloat = 36
  /// Where the window's last traffic light ends (the unified title bar's standard buttons).
  static let trafficLightsTrailing: CGFloat = 72
  /// The title bar's leading content (the app icon) starts 12 pt after the last traffic light.
  static let titleBarLeading: CGFloat = trafficLightsTrailing + Tokens.titleIconLeading
  static let gutter: CGFloat = 24
  static let tabInset: CGFloat = 3
  static let markSize: CGFloat = 16

  static func mirrorRegion(for padMM: CGSize) -> CGSize {
    let pad = CGSize(
      width: max(padMM.width, largestPadMM.width) * Tokens.mirrorPointsPerMM,
      height: max(padMM.height, largestPadMM.height) * Tokens.mirrorPointsPerMM)
    return CGSize(width: pad.width + 2 * mirrorMargin, height: pad.height + 2 * mirrorMargin)
  }
}

/// A plain text button: semibold `ink`, no chrome ("Resume", "Turn on", "Show", "Follow Default").
struct TextButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(Tokens.font(Tokens.typeBody, semibold: true))
      .foregroundStyle(Tokens.ink)
      .opacity(configuration.isPressed ? 0.6 : 1)
      .contentShape(Rectangle())
  }
}

/// The default button in a popover or sheet ("Add", "Done"): an `ink` fill. Not the accent, which
/// means "live" only.
struct InkButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(Tokens.font(Tokens.typeBody, semibold: true))
      .foregroundStyle(Tokens.windowTint)
      .padding(.horizontal, 14)
      .padding(.vertical, 5)
      .background(Tokens.ink, in: RoundedRectangle(cornerRadius: Tokens.radiusControl))
      .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
  }
}

/// A one-line strip under the tabs, full width (No Accessibility, broken config).
struct WindowStripView<Buttons: View>: View {
  let symbol: String
  let text: String
  @ViewBuilder let buttons: Buttons

  var body: some View {
    // Top-aligned: when the sentence wraps, the buttons stay on its first line (critique 21 S4).
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Image(systemName: symbol).foregroundStyle(Tokens.ink)
      Text(text).foregroundStyle(Tokens.ink).lineLimit(2).fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 12)
      buttons
    }
    .font(Tokens.font(Tokens.typeBody))
    .padding(.horizontal, WindowMetrics.gutter)
    .frame(minHeight: WindowMetrics.stripHeight)
    .background(Tokens.bar.opacity(0.35))
    .overlay(alignment: .bottom) { Tokens.line.opacity(0.3).frame(height: 1) }
  }
}

/// One line centred on the pad with its text button ("Paused, 47 min left · Resume"). No
/// container: the faded pad behind it gives the contrast (batch-16 should-fix 5).
struct PadLineView: View {
  let text: String
  let button: String
  let action: () -> Void

  var body: some View {
    HStack(spacing: 14) {
      Text(text).font(Tokens.font(Tokens.typeBody)).foregroundStyle(Tokens.ink)
      Button(button, action: action).buttonStyle(TextButtonStyle())
    }
  }
}

/// Info note at the top of the inspector column on a legacy (full-replace) profile.
struct LegacyNoteView: View {
  let follow: () -> Void

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Image(systemName: "info.circle").foregroundStyle(Tokens.ink2)
      VStack(alignment: .leading, spacing: 6) {
        Text(WindowCopy.legacyNote).foregroundStyle(Tokens.ink2)
        Button("Follow Default", action: follow).buttonStyle(TextButtonStyle())
        Text(WindowCopy.legacyDetail).foregroundStyle(Tokens.ink2)
      }
    }
    .font(Tokens.font(Tokens.typeBody))
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// The `overlappingZones` warning: a warning icon plus `ink2`, with **Show**.
struct OverlapNoteView: View {
  let note: OverlapNote
  let show: () -> Void

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Image(systemName: "exclamationmark.triangle").foregroundStyle(Tokens.ink2)
      Text(note.text).foregroundStyle(Tokens.ink2).fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 8)
      Button("Show", action: show).buttonStyle(TextButtonStyle())
    }
    .font(Tokens.font(Tokens.typeBody))
  }
}

/// An app mark on tabs, add-app rows and popover chips (critique 21, design answer 3): the real
/// app icon at 14 pt, desaturated, at 70% opacity in dark so a white icon doesn't glare. An app
/// with no icon gets Edgy's own "Open App" tile icon in `ink2` (never a plain square: kill list).
struct AppMark: View {
  let path: String?
  /// On a filled `ink` chip the fallback draws in the window tint, not `ink2`.
  var onInk = false
  @Environment(\.colorScheme) private var scheme

  static let size: CGFloat = 14
  static let darkOpacity = 0.7

  /// Critique 22 must-fix: only a bundle that ships its own icon counts. A missing path, a bundle
  /// with no `CFBundleIconFile`/`CFBundleIconName`, or one whose named icon isn't in its resources
  /// (the system would draw its generic application icon, a pale square) has no icon.
  static func hasIcon(_ path: String?) -> Bool {
    guard let path, FileManager.default.fileExists(atPath: path) else { return false }
    let url = URL(fileURLWithPath: path)
    let contents = url.appendingPathComponent("Contents")
    guard
      let data = try? Data(contentsOf: contents.appendingPathComponent("Info.plist")),
      let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    else { return false }
    let resources = contents.appendingPathComponent("Resources")
    let exists = { (name: String) in FileManager.default.fileExists(atPath: resources.appendingPathComponent(name).path)
    }
    if let name = info["CFBundleIconName"] as? String, !name.isEmpty, exists("Assets.car") { return true }
    if let file = info["CFBundleIconFile"] as? String, !file.isEmpty {
      return exists(file) || exists(file + ".icns")
    }
    return false
  }

  /// The mark for `path`: its own icon desaturated, or `nil` when `hasIcon` says it has none.
  static func icon(_ path: String?) -> NSImage? {
    guard let path, hasIcon(path) else { return nil }
    return NSWorkspace.shared.icon(forFile: path)
  }

  var body: some View {
    Group {
      if let icon = Self.icon(path) {
        Image(nsImage: icon).resizable().saturation(0)
          .aspectRatio(contentMode: .fit)
          .frame(width: Self.size, height: Self.size)
          .opacity(scheme == .dark ? Self.darkOpacity : 1)
      } else {
        ActionIcon(id: "app.open", size: Self.size).foregroundStyle(onInk ? Tokens.windowTint : Tokens.ink2)
      }
    }
    .accessibilityHidden(true)
  }
}

/// § Window identity and Advanced (a), the owner's ruling on device (2026-11-07, supersedes the
/// 26 pt app icon): the Edgy mark alone, the V3 pad plus its lit strip with no tile, filled in
/// `ink` (the strip too, never accent: bone 8). `titleMarkWidth` × `titleMarkHeight` (26 × 18),
/// `titleIconLeading` (12) after the last traffic light, centred on the tab pill's centre (the
/// shared title-bar row centres both). The exported `mark-edgy.pdf` is a non-template image used
/// only as the shape's mask, so the system never tints it. No outline, no shadow, no states.
/// Tooltip and accessibility label "Edgy"; not clickable, no hover wash.
struct WindowIdentity: View {
  static let width = Tokens.titleMarkWidth
  static let height = Tokens.titleMarkHeight
  static let label = "Edgy"

  /// The exported mark (`Glyph/Assets/mark-edgy.pdf`), `nil` (logged) if the resource is missing.
  @MainActor static let mark: NSImage? = {
    guard let url = Bundle.module.url(forResource: "mark-edgy", withExtension: "pdf", subdirectory: "Assets"),
      let image = NSImage(contentsOf: url)
    else {
      SettingsModel.windowLog.log(.error, "Edgy mark missing: mark-edgy.pdf is not in the EdgyUI bundle")
      return nil
    }
    image.isTemplate = false
    return image
  }()

  var body: some View {
    Tokens.ink
      .mask {
        if let mark = Self.mark { Image(nsImage: mark).resizable().interpolation(.high) }
      }
      .frame(width: Self.width, height: Self.height)
      .help(Self.label)
      .accessibilityElement()
      .accessibilityLabel(Self.label)
      .accessibilityAddTraits(.isImage)
  }
}

/// § Window identity and Advanced: "Advanced…" as a quiet footer text button: the 16 pt sliders
/// icon, then the label (13 regular `ink2`), no bezel. On hover both go to `ink` over the 10%
/// `ink` wash (the popover rows' hover).
struct AdvancedButton: View {
  var action: () -> Void
  var forceHover = false
  @State private var hovering = false

  var body: some View {
    let hot = hovering || forceHover
    Button(action: action) {
      HStack(spacing: 6) {
        AdvancedIcon()
        Text("Advanced…").font(Tokens.font(Tokens.typeBody))
      }
      .foregroundStyle(hot ? Tokens.ink : Tokens.ink2)
      .padding(.horizontal, 8).padding(.vertical, 4)
      .background(RoundedRectangle(cornerRadius: Tokens.radiusControl).fill(Tokens.ink.opacity(hot ? 0.1 : 0)))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
  }
}
