import AppKit
import EdgyCore
import EdgyRuntime
import SwiftUI
import Testing

@testable import EdgyUI

// MARK: Precedence: Broken config > No Accessibility > No trackpad > Paused > Disabled > Test Mode

private struct Facts {
  var broken = false
  var noAccess = false
  var noPad = false
  var paused = false
  var disabled = false
  var testMode = false

  var state: MenuGlyph.State {
    MenuGlyph.state(
      brokenConfig: broken, needsAccessibility: noAccess, hasTrackpad: !noPad, paused: paused, enabled: !disabled,
      testMode: testMode)
  }
}

@Test func glyphShowsNormalWhenNothingApplies() {
  #expect(Facts().state == .normal)
}

@Test func glyphShowsEachStateAlone() {
  #expect(Facts(broken: true).state == .brokenConfig)
  #expect(Facts(noAccess: true).state == .needsAccessibility)
  #expect(Facts(noPad: true).state == .noTrackpad)
  #expect(Facts(paused: true).state == .paused)
  #expect(Facts(disabled: true).state == .disabled)
  #expect(Facts(testMode: true).state == .testMode)
}

@Test func glyphPrecedenceHoldsForEveryPair() {
  // Highest first. For every pair, the higher one wins.
  let order: [(MenuGlyph.State, WritableKeyPath<Facts, Bool>)] = [
    (.brokenConfig, \.broken), (.needsAccessibility, \.noAccess), (.noTrackpad, \.noPad), (.paused, \.paused),
    (.disabled, \.disabled), (.testMode, \.testMode),
  ]
  for (i, high) in order.enumerated() {
    for low in order[(i + 1)...] {
      var facts = Facts()
      facts[keyPath: high.1] = true
      facts[keyPath: low.1] = true
      #expect(facts.state == high.0, "\(high.0) over \(low.0)")
    }
  }
}

@Test func glyphShowsBrokenConfigWhenEverythingApplies() {
  #expect(
    Facts(broken: true, noAccess: true, noPad: true, paused: true, disabled: true, testMode: true).state
      == .brokenConfig)
}

@MainActor @Test func glyphStateReadsTheLiveFacts() {
  let model = PreviewFixtures.model()
  let editor = model.editor
  let pad = PreviewFixtures.externalPad
  let running = EngineStatus(running: true, enabled: true, devices: [pad])
  #expect(MenuGlyph.state(engine: running, editor: editor, testMode: false, accessibility: .granted) == .normal)
  // Unknown permission (before the first check) never shows the exclamation.
  #expect(MenuGlyph.state(engine: running, editor: editor, testMode: false, accessibility: .unknown) == .normal)
  #expect(
    MenuGlyph.state(engine: running, editor: editor, testMode: false, accessibility: .denied) == .needsAccessibility)
  // The dot follows the Test Mode switch, not the engine's dry-run flag.
  #expect(MenuGlyph.state(engine: running, editor: editor, testMode: true, accessibility: .granted) == .testMode)
  let noPad = EngineStatus(running: true, enabled: true, devices: [])
  #expect(MenuGlyph.state(engine: noPad, editor: editor, testMode: false, accessibility: .granted) == .noTrackpad)
  var paused = running
  paused.paused = true
  #expect(MenuGlyph.state(engine: paused, editor: editor, testMode: true, accessibility: .granted) == .paused)
  #expect(
    MenuGlyph.state(
      engine: running, editor: editor, testMode: false, accessibility: .denied,
      configProblem: EdgyUI.ConfigProblem(line: 14, message: "Unexpected character")) == .brokenConfig)
  model.setEnabled(false)
  #expect(MenuGlyph.state(engine: running, editor: editor, testMode: true, accessibility: .granted) == .disabled)
}

// MARK: Artwork

@MainActor @Test func glyphImagesAreSixteenByElevenTemplates() {
  for state in MenuGlyph.State.allCases {
    let image = MenuGlyph.image(for: state)
    #expect(image.size == NSSize(width: 16, height: 11), "\(state)")
    #expect(image.isTemplate, "\(state)")
    #expect(inkAlpha(image) > 0, "\(state) has artwork")
  }
}

@MainActor @Test func disabledAndNoTrackpadAreNormalAtFortyPercent() throws {
  let normal = inkAlpha(MenuGlyph.image(for: .normal))
  for state in [MenuGlyph.State.disabled, .noTrackpad] {
    let dimmed = inkAlpha(MenuGlyph.image(for: state))
    #expect(abs(dimmed / normal - 0.4) < 0.03, "\(state): \(dimmed / normal)")
  }
  // V3 "Lit strip": Test Mode is a hole cut through the solid pad, so it carries less ink.
  #expect(inkAlpha(MenuGlyph.image(for: .testMode)) < normal, "Test Mode cuts the hole")
}

/// Sum of alpha over a 4× render (the ink coverage).
@MainActor private func inkAlpha(_ image: NSImage) -> Double {
  let scale = 4
  let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: 16 * scale, pixelsHigh: 11 * scale, bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  rep.size = image.size
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  image.draw(in: NSRect(origin: .zero, size: image.size))
  NSGraphicsContext.restoreGraphicsState()
  var total = 0.0
  for x in 0..<rep.pixelsWide {
    for y in 0..<rep.pixelsHigh { total += Double(rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) }
  }
  return total
}

// MARK: Snapshot

@MainActor @Test func glyphSheetSnapshot() throws {
  try Snapshot.write(GlyphSheet().padding(24), folder: "batch-17", name: "glyph-sheet")
}

/// Every state at 1× and 2× on a menu-bar-like strip, light and dark.
private struct GlyphSheet: View {
  var body: some View {
    HStack(alignment: .top, spacing: 28) {
      ForEach(MenuGlyph.State.allCases, id: \.self) { state in
        VStack(alignment: .leading, spacing: 10) {
          Text(name(state)).font(Tokens.font(Tokens.typeBody)).foregroundStyle(Tokens.ink2)
          glyph(state, scale: 1)
          glyph(state, scale: 2)
        }
      }
    }
  }

  private func glyph(_ state: MenuGlyph.State, scale: CGFloat) -> some View {
    Image(nsImage: MenuGlyph.image(for: state))
      .renderingMode(.template)
      .resizable()
      .frame(width: 16 * scale, height: 11 * scale)
      .foregroundStyle(Tokens.ink)
      .padding(.horizontal, 8 * scale)
      .padding(.vertical, 6 * scale)
      .background(Tokens.windowTint, in: RoundedRectangle(cornerRadius: Tokens.radiusControl))
  }

  private func name(_ state: MenuGlyph.State) -> String {
    switch state {
    case .normal: "Normal"
    case .testMode: "Test Mode"
    case .paused: "Paused"
    case .disabled: "Disabled"
    case .noTrackpad: "No trackpad"
    case .needsAccessibility: "No Accessibility"
    case .brokenConfig: "Broken config"
    }
  }
}
