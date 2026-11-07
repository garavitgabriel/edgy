import AppKit
import SwiftUI
import Testing

/// Renders a SwiftUI view through a real `NSHostingView` (so system controls draw; an
/// `ImageRenderer` replaces them with placeholders) into a 2× PNG, light and dark, and writes it
/// to `docs/design/build-shots/<folder>/<name>-<light|dark>.png` for review against
/// `docs/design/final/*.png`. Glass material renders flat here; judge material on the device.
@MainActor
enum Snapshot {
  static let repoRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent()

  @discardableResult
  static func write<V: View>(_ view: V, folder: String, name: String, size: CGSize? = nil) throws -> [URL] {
    var urls: [URL] = []
    for (suffix, appearanceName) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
      let host = NSHostingView(rootView: view)
      host.appearance = NSAppearance(named: appearanceName)
      let fitting = size ?? host.fittingSize
      host.frame = NSRect(origin: .zero, size: fitting)
      let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
      window.appearance = host.appearance
      window.contentView = host
      host.layoutSubtreeIfNeeded()
      let rep = try #require(
        NSBitmapImageRep(
          bitmapDataPlanes: nil, pixelsWide: Int(fitting.width * 2), pixelsHigh: Int(fitting.height * 2),
          bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
          bytesPerRow: 0, bitsPerPixel: 0))
      rep.size = fitting
      host.cacheDisplay(in: host.bounds, to: rep)
      let png = try #require(rep.representation(using: .png, properties: [:]))
      let dir = repoRoot.appendingPathComponent("docs/design/build-shots/\(folder)")
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
      let url = dir.appendingPathComponent("\(name)-\(suffix).png")
      try png.write(to: url)
      urls.append(url)
    }
    return urls
  }
}
