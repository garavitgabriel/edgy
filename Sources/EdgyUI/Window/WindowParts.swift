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
  static let inspectorWidth: CGFloat = 340
  static let tabBarHeight: CGFloat = 52
  static let footerHeight: CGFloat = 56
  static let stripHeight: CGFloat = 36
  /// Leading room for the window's traffic-light buttons (the tabs share the title bar).
  static let titleBarLeading: CGFloat = 84
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
    HStack(spacing: 10) {
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

/// One line centred on the pad with its text button ("Paused, 47 min left · Resume").
struct PadLineView: View {
  let text: String
  let button: String
  let action: () -> Void

  var body: some View {
    HStack(spacing: 14) {
      Text(text).font(Tokens.font(Tokens.typeBody)).foregroundStyle(Tokens.ink)
      Button(button, action: action).buttonStyle(TextButtonStyle())
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 8)
    .background(
      Tokens.windowTint.opacity(Tokens.windowTintOpacity), in: RoundedRectangle(cornerRadius: Tokens.radiusControl))
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

/// A small monochrome app mark: the app's own icon desaturated when we know where it is, else a
/// plain outline symbol. Never a coloured square.
struct AppMark: View {
  let path: String?

  var body: some View {
    Group {
      if let path, FileManager.default.fileExists(atPath: path) {
        Image(nsImage: NSWorkspace.shared.icon(forFile: path)).resizable().saturation(0)
      } else {
        Image(systemName: "app").resizable().foregroundStyle(Tokens.ink2)
      }
    }
    .aspectRatio(contentMode: .fit)
    .frame(width: WindowMetrics.markSize, height: WindowMetrics.markSize)
  }
}
