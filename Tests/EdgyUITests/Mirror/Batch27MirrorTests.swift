import AppKit
import EdgyCore
import EdgyRuntime
import Foundation
import SwiftUI
import Testing

@testable import EdgyUI

/// Batch 27, critique 25 regression 1: a split preview on a side edge fades only the label text.
/// The bar, its selection ring and the tab's silhouette stay drawn under the dividers.
@MainActor
struct Batch27MirrorTests {
  /// Renders `view` at 2× in `appearance` through a real `NSHostingView`, without writing a file.
  private func render<V: View>(_ view: V, size: CGSize, appearance: NSAppearance.Name) throws -> NSBitmapImageRep {
    let host = NSHostingView(rootView: view)
    host.appearance = NSAppearance(named: appearance)
    host.frame = NSRect(origin: .zero, size: size)
    let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    window.appearance = host.appearance
    window.contentView = host
    host.layoutSubtreeIfNeeded()
    let rep = try #require(
      NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size.width * 2), pixelsHigh: Int(size.height * 2),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0))
    rep.size = size
    host.cacheDisplay(in: host.bounds, to: rep)
    return rep
  }

  private func rgb(_ rep: NSBitmapImageRep, at point: CGPoint) throws -> SIMD3<Double> {
    let colour = try #require(rep.colorAt(x: Int(point.x * 2), y: Int(point.y * 2))?.usingColorSpace(.deviceRGB))
    return SIMD3(Double(colour.redComponent), Double(colour.greenComponent), Double(colour.blueComponent))
  }

  private func token(_ colour: Color, _ appearance: NSAppearance.Name) -> SIMD3<Double> {
    var out = SIMD3<Double>(0, 0, 0)
    NSAppearance(named: appearance)?.performAsCurrentDrawingAppearance {
      if let c = NSColor(colour).usingColorSpace(.deviceRGB) {
        out = SIMD3(Double(c.redComponent), Double(c.greenComponent), Double(c.blueComponent))
      }
    }
    return out
  }

  private func distance(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
    let d = a - b
    return (d * d).sum().squareRoot()
  }

  /// Fails if the previewed side edge loses its bar or its selection ring (the batch-25 bug:
  /// opacity 0 on the whole label, whose side tab carries the bar's shape).
  @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
  func splitPreviewKeepsTheSideBarAndRing(appearance: NSAppearance.Name) throws {
    let model = PreviewFixtures.model()
    let geometry = MirrorGeometry(
      sensorSizeMM: PreviewFixtures.externalPad.sensorSizeMM, settings: model.editor.config.gestures,
      pointsPerMM: Tokens.mirrorPointsPerMM)
    let zones = model.mirrorZones(forApp: nil)
    #expect(zones.first { $0.zone == .edge(.right) }?.style == .mapped)
    let pad = MirrorPad(
      geometry: geometry, zones: zones, selected: .edge(.right),
      splitPreview: SplitPreview.Hover(edge: .right, parts: 3))
    #expect(pad.splitPreviewHides(.edge(.right)))
    let size = geometry.size
    let rep = try render(pad.frame(width: size.width, height: size.height), size: size, appearance: appearance)

    let bar = geometry.shapeFrame(for: .edge(.right))
    let barColour = token(Tokens.bar, appearance)
    let padColour = token(Tokens.padTop, appearance)
    // Mid-height of each third (the dividers sit at 1/3 and 2/3), on the bar's centre line.
    for fraction in [1.0 / 6, 0.5, 5.0 / 6] {
      let sample = try rgb(rep, at: CGPoint(x: bar.midX, y: bar.minY + bar.height * fraction))
      #expect(
        distance(sample, barColour) < 0.08,
        "bar at \(fraction) of the edge: \(sample) vs bar \(barColour), pad \(padColour)")
      #expect(distance(sample, barColour) < distance(sample, padColour))
    }
    // The ink ring outside the bar, on its outer side.
    let ringX = bar.maxX + MirrorPad.ringGap + MirrorPad.ringWidth / 2
    let ring = try rgb(rep, at: CGPoint(x: ringX, y: bar.minY + bar.height / 6))
    #expect(distance(ring, token(Tokens.ink, appearance)) < 0.15, "ring: \(ring)")
  }
}
