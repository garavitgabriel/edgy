import AppKit
import SwiftUI

/// The live overlay: one borderless, non-activating, click-through panel per screen for the
/// plates, and one small non-activating panel that accepts clicks for the display check (the
/// only clickable plate). Panels never take focus, join every Space and sit above full-screen
/// apps. Drawn dark (renders D and S8): a dark plate on warm material reads over light and dark
/// documents alike.
///
/// Live only: tests use a recording presenter, so no panel reaches a real screen from a test.
@MainActor
final class PanelPresenter: OverlayPresenting {
  private var panels: [String: OverlayPanel] = [:]
  private var checkPanel: OverlayPanel?
  private var lastPlacements: [PlatePlacement] = []
  private var sizes: [PlateContent: CGSize] = [:]

  func size(of content: PlateContent) -> CGSize {
    if let size = sizes[content] { return size }
    let host = NSHostingView(rootView: PlateView(content, onAnswer: { _ in }))
    host.appearance = OverlayPanel.appearance
    let size = host.fittingSize
    sizes[content] = size
    if sizes.count > 64 { sizes.removeAll() }
    return size
  }

  func present(_ placements: [PlatePlacement], screens: [OverlayScreen], answer: @escaping @MainActor (Bool) -> Void) {
    guard placements != lastPlacements else { return }
    lastPlacements = placements
    let passive = placements.filter { !$0.content.isDisplayCheck }
    for screen in screens {
      let mine = passive.filter { $0.screenID == screen.id }
      if mine.isEmpty {
        panels[screen.id]?.orderOut(nil)
        continue
      }
      let panel = panels[screen.id] ?? OverlayPanel(clickable: false)
      panels[screen.id] = panel
      panel.setFrame(screen.frame, display: false)
      panel.host(OverlayCanvas(placements: mine, screenFrame: screen.frame))
      panel.orderFrontRegardless()
    }
    for (id, panel) in panels where !screens.contains(where: { $0.id == id }) {
      panel.orderOut(nil)
      panels[id] = nil
    }

    if let check = placements.first(where: \.content.isDisplayCheck) {
      let panel = checkPanel ?? OverlayPanel(clickable: true)
      checkPanel = panel
      panel.setFrame(check.frame, display: false)
      panel.host(PlateView(check.content, onAnswer: answer).opacity(check.opacity).background(PlateMaterial()))
      panel.orderFrontRegardless()
    } else {
      checkPanel?.orderOut(nil)
    }
  }

  func tearDown() {
    for panel in panels.values { panel.orderOut(nil) }
    panels = [:]
    checkPanel?.orderOut(nil)
    checkPanel = nil
    lastPlacements = []
  }
}

/// Every passive plate on one screen, at its docked frame.
struct OverlayCanvas: View {
  var placements: [PlatePlacement]
  var screenFrame: CGRect

  var body: some View {
    ZStack(alignment: .topLeading) {
      Color.clear
      ForEach(placements, id: \.id) { placement in
        PlateView(placement.content)
          .background(PlateMaterial())
          .frame(width: placement.frame.width, height: placement.frame.height, alignment: .topLeading)
          .offset(
            x: placement.frame.minX - screenFrame.minX, y: screenFrame.maxY - placement.frame.maxY
          )
          .opacity(placement.opacity)
      }
    }
    .frame(width: screenFrame.width, height: screenFrame.height, alignment: .topLeading)
    .allowsHitTesting(false)
  }
}

/// The system's HUD material under a plate's warm tint, clipped to the plate's radius.
struct PlateMaterial: View {
  var body: some View {
    MaterialView()
      .clipShape(RoundedRectangle(cornerRadius: Tokens.radiusPlate, style: .continuous))
  }

  private struct MaterialView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
      let view = NSVisualEffectView()
      view.material = .hudWindow
      view.blendingMode = .behindWindow
      view.state = .active
      return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
  }
}

/// A borderless, non-activating panel that never becomes key or main.
final class OverlayPanel: NSPanel {
  static let appearance = NSAppearance(named: .darkAqua)

  init(clickable: Bool) {
    super.init(
      contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
    isFloatingPanel = true
    level = .statusBar
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    isOpaque = false
    backgroundColor = .clear
    hasShadow = false
    hidesOnDeactivate = false
    isReleasedWhenClosed = false
    ignoresMouseEvents = !clickable
    becomesKeyOnlyIfNeeded = true
    animationBehavior = .none
    appearance = Self.appearance
  }

  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }

  func host<V: View>(_ view: V) {
    if let host = contentView as? NSHostingView<AnyView> {
      host.rootView = AnyView(view)
    } else {
      let host = NSHostingView(rootView: AnyView(view))
      host.appearance = Self.appearance
      contentView = host
    }
  }
}
