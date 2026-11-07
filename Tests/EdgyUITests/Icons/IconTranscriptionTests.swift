import Actions
import CoreGraphics
import EdgyCore
import Foundation
import Testing

@testable import EdgyUI

/// The icons in `Sources/EdgyUI/Icons/IconData.swift` are transcribed, never drawn: these tests
/// re-read every exported SVG in `docs/design/assets/icons/` and hold the Swift table to it.
@MainActor @Suite struct IconTranscriptionTests {
  static let iconsDir = Snapshot.repoRoot.appendingPathComponent("docs/design/assets/icons")

  /// One SVG file, parsed independently of the Swift transcription.
  struct ParsedSVG {
    var viewBox: [CGFloat]
    var elements: [IconDrawing.Element]
  }

  final class SVGReader: NSObject, XMLParserDelegate {
    var viewBox: [CGFloat] = []
    var elements: [IconDrawing.Element] = []
    func parser(
      _ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?,
      attributes a: [String: String]
    ) {
      func n(_ key: String, _ fallback: CGFloat = 0) -> CGFloat {
        a[key].flatMap { Double($0) }.map { CGFloat($0) } ?? fallback
      }
      let fill = a["fill"] == "currentColor"
      let stroke = a["stroke"] == "currentColor" ? n("stroke-width") : 0
      switch name {
      case "svg": viewBox = (a["viewBox"] ?? "").split(separator: " ").compactMap { Double($0) }.map { CGFloat($0) }
      case "path":
        elements.append(.path(a["d", default: ""].trimmingCharacters(in: .whitespaces), fill: fill, stroke: stroke))
      case "rect":
        elements.append(
          .rect(
            x: n("x"), y: n("y"), width: n("width"), height: n("height"), rx: n("rx"), fill: fill, stroke: stroke))
      case "circle": elements.append(.circle(cx: n("cx"), cy: n("cy"), r: n("r"), fill: fill, stroke: stroke))
      default: Issue.record("unexpected SVG element <\(name)>")
      }
    }
  }

  static func parse(_ stem: String) throws -> ParsedSVG {
    let data = try Data(contentsOf: iconsDir.appendingPathComponent("\(stem).svg"))
    let reader = SVGReader()
    let parser = XMLParser(data: data)
    parser.delegate = reader
    #expect(parser.parse())
    return ParsedSVG(viewBox: reader.viewBox, elements: reader.elements)
  }

  static func svgStems() throws -> [String] {
    try FileManager.default.contentsOfDirectory(atPath: iconsDir.path)
      .filter { $0.hasSuffix(".svg") }.map { String($0.dropLast(4)) }.sorted()
  }

  @Test func everyCatalogActionHasAnIcon() {
    let catalog = makeLiveActionRegistry(settings: .defaults).available
    #expect(catalog.count >= 33)
    for descriptor in catalog {
      #expect(ActionIcons.has(descriptor.id), "no icon for \(descriptor.id.rawValue)")
    }
    #expect(ActionIcons.has(.doNothing))
    #expect(!ActionIcons.has("not.an.action"))
  }

  @Test func everyExportedSVGIsTranscribedAndNothingElse() throws {
    #expect(Set(try Self.svgStems()) == Set(IconDrawing.all.keys))
  }

  @Test func transcribedElementsMatchTheirSVGExactly() throws {
    for stem in try Self.svgStems() {
      let svg = try Self.parse(stem)
      let drawing = try #require(IconDrawing.all[stem])
      #expect(svg.viewBox == [0, 0, drawing.width, drawing.height], "\(stem) viewBox")
      #expect(svg.elements == drawing.elements, "\(stem) elements differ from the SVG")
    }
  }

  @Test func actionMapMatchesTheREADMETable() throws {
    let readme = try String(contentsOf: Self.iconsDir.appendingPathComponent("README.md"), encoding: .utf8)
    var table: [String: String] = [:]
    for line in readme.split(separator: "\n") {
      let cells = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
      guard cells.count >= 2, cells[0].hasPrefix("`"), cells[0].hasSuffix(".svg`"), cells[1].hasPrefix("`") else {
        continue
      }
      table[cells[1].trimmingCharacters(in: CharacterSet(charactersIn: "`"))] =
        String(cells[0].dropFirst().dropLast(5))
    }
    #expect(table == IconDrawing.fileForAction)
  }

  /// The transcribed geometry (stroke included) sits inside its SVG viewBox and fills its grid:
  /// action icons reach to within the stroke of the 16 pt box; split drawings span it edge to edge.
  @Test func transcribedBoundsSitInsideTheirViewBox() throws {
    for stem in try Self.svgStems() {
      let svg = try Self.parse(stem)
      let drawing = try #require(IconDrawing.all[stem])
      let viewBox = CGRect(x: svg.viewBox[0], y: svg.viewBox[1], width: svg.viewBox[2], height: svg.viewBox[3])
      let painted = drawing.paintedBounds
      #expect(!painted.isNull && painted.width > 0 && painted.height > 0, "\(stem) is empty")
      #expect(viewBox.insetBy(dx: -0.01, dy: -0.01).contains(painted), "\(stem) paints outside \(viewBox): \(painted)")
      if stem.hasPrefix("split-") {
        #expect(abs(painted.width - viewBox.width) < 0.01 && abs(painted.height - viewBox.height) < 0.01, "\(stem)")
      } else {
        #expect(viewBox.width == 16 && viewBox.height == 16)
        #expect(max(painted.width, painted.height) >= 11, "\(stem) is too small for the 16 pt grid: \(painted)")
      }
    }
  }

  @Test func pathInterpreterHandlesTheExportedCommands() {
    // Line commands: H and V continue from the current point.
    let box = SVGPathData.path("M2 4 H8.2 V10 L2 10 Z").boundingRect
    #expect(abs(box.minX - 2) < 0.001 && abs(box.maxX - 8.2) < 0.001)
    #expect(abs(box.minY - 4) < 0.001 && abs(box.maxY - 10) < 0.001)
    // A half-circle arc of radius 2 from (11, 6) to (11, 10), sweeping right.
    let arc = SVGPathData.path("M11 6 A2 2 0 0 1 11 10").boundingRect
    #expect(abs(arc.minX - 11) < 0.01 && abs(arc.maxX - 13) < 0.01)
    #expect(abs(arc.minY - 6) < 0.01 && abs(arc.maxY - 10) < 0.01)
    // Relative commands and numbers without a leading zero.
    let relative = SVGPathData.path("m1 1 l.5 .5 h1").boundingRect
    #expect(abs(relative.maxX - 2.5) < 0.001 && abs(relative.maxY - 1.5) < 0.001)
  }

  @Test func splitGlyphPicksTheEdgesOrientation() {
    #expect(EdgySplitGlyph.file(edge: .left, parts: 3, selected: false) == "split-vertical-3")
    #expect(EdgySplitGlyph.file(edge: .right, parts: 1, selected: true) == "split-vertical-1-selected")
    #expect(EdgySplitGlyph.file(edge: .top, parts: 2, selected: true) == "split-horizontal-2-selected")
    #expect(EdgySplitGlyph.file(edge: .bottom, parts: 4, selected: false) == "split-horizontal-4")
    let vertical = EdgySplitGlyph(edge: .left, parts: 2, selected: false).drawing
    #expect(vertical.width == 12 && vertical.height == 40)
    let horizontal = EdgySplitGlyph(edge: .bottom, parts: 4, selected: true).drawing
    #expect(horizontal.width == 40 && horizontal.height == 12)
    #expect(horizontal.elements.count == 4 && horizontal.elements.allSatisfy(\.fills))
    #expect(vertical.elements.allSatisfy { !$0.fills && $0.strokeWidth == 1 })
  }
}
