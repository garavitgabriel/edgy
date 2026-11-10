import Actions
import AppKit
import EdgyCore
import SwiftUI

/// A zone's icon on the full mirror's corners and the mini mirror (BRIEF § Bindings that name
/// their target, § Your own name and icon): an action icon in `ink`, or for Open App the app's own
/// icon in the app-mark treatment (desaturated, 70% opacity in dark), the same as profile tabs and
/// chips. An app with no icon of its own draws the Open App tile in `ink2`.
///
/// Icons come through `AppIconCache` (batch 28): read once per path, off the main thread when
/// `appIconsLoadOffMain` is set. The bundle's path is looked up once per bundle ID.
struct ZoneMark: View {
  let icon: BindingNaming.Icon
  let size: CGFloat
  @Environment(\.colorScheme) private var scheme
  @Environment(\.appIconsLoadOffMain) private var offMain
  @Environment(\.mirrorAppPaths) private var knownPaths
  @State private var loaded: AppIconCache.Icon?

  var body: some View {
    switch icon {
    case .action(let id):
      ActionIcon(id: id, size: size).foregroundStyle(Tokens.ink)
    case .app(let bundleID):
      appMark(path: knownPaths[bundleID] ?? MirrorAppPaths.shared.path(for: bundleID))
    }
  }

  @ViewBuilder private func appMark(path: String?) -> some View {
    let mark: AppIconCache.Icon? =
      path.map { loaded ?? (offMain ? AppIconCache.shared.cached($0) : AppIconCache.shared.icon($0)) } ?? .none
    Group {
      switch mark {
      case .image(let image)?:
        Image(nsImage: image).resizable().saturation(0)
          .aspectRatio(contentMode: .fit)
          .frame(width: size, height: size)
          .opacity(scheme == .dark ? AppMark.darkOpacity : 1)
      case .none?:
        ActionIcon(id: BuiltInAction.openApp, size: size).foregroundStyle(Tokens.ink2)
      case nil:
        Color.clear.frame(width: size, height: size)
      }
    }
    .accessibilityHidden(true)
    .task(id: path) {
      guard offMain, let path, AppIconCache.shared.cached(path) == nil else { return }
      loaded = await AppIconCache.shared.load(path)
    }
  }
}

/// Bundle paths by bundle ID for zone app marks, asked of the system once per ID and kept.
@MainActor
final class MirrorAppPaths {
  static let shared = MirrorAppPaths()
  private var paths: [String: String?] = [:]

  func path(for bundleID: String) -> String? {
    if let known = paths[bundleID] { return known }
    let path = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)?.path
    paths[bundleID] = path
    return path
  }
}

extension EnvironmentValues {
  /// Bundle paths the host already knows (the popover's installed apps; snapshot fixtures), by
  /// bundle ID. A missing ID is looked up once through `MirrorAppPaths`.
  @Entry var mirrorAppPaths: [String: String] = [:]
}

extension BindingNaming.Icon: Hashable {
  func hash(into hasher: inout Hasher) {
    switch self {
    case .action(let id):
      hasher.combine(0)
      hasher.combine(id)
    case .app(let bundleID):
      hasher.combine(1)
      hasher.combine(bundleID)
    }
  }
}
