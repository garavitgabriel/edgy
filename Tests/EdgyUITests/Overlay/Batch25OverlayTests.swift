import Actions
import EdgyCore
import Foundation
import SwiftUI
import Testing

@testable import EdgyUI

/// Batch 25 item 5 (critique 23 should-fix): parameterised run plates say what they did, in the
/// past tense with the object; plain triggers stay bare. Shots in `batch-25/`, each plate over a
/// white and a black document (bone 9's worst case).
@MainActor
@Suite struct Batch25OverlayTests {
  static let folder = "batch-25"

  private let context = PlateContext(
    bindings: [
      Binding(
        zone: .corner(.bottomRight), gesture: .doubleTap, action: BuiltInAction.openApp,
        parameters: ["bundleID": "com.example.quillpad"]),
      Binding(
        zone: .edge(.top), gesture: .tap, action: BuiltInAction.keyboardShortcut, parameters: ["keys": "cmd+shift+4"]),
      Binding(
        zone: .corner(.topLeft), gesture: .doubleTap, action: BuiltInAction.runShortcut,
        parameters: [ActionParameterKey.shortcutName: "Morning lights"]),
      Binding(zone: .edge(.bottom), gesture: .tap, action: BuiltInAction.playPause),
    ], appNames: ["com.example.quillpad": "Quillpad"])

  private func title(_ id: ActionID, _ zone: Zone, _ kind: GestureKind) -> String? {
    PlateContent.from(.actionRan(id, zone: zone, kind: kind), catalog: overlayCatalog, context: context, dryRun: false)?
      .title
  }

  @Test func parameterRunsArePastTenseWithTheirObject() {
    #expect(title(BuiltInAction.openApp, .corner(.bottomRight), .doubleTap) == "Opened Quillpad")
    #expect(title(BuiltInAction.keyboardShortcut, .edge(.top), .tap) == "Pressed ⇧⌘ 4")
    #expect(title(BuiltInAction.runShortcut, .corner(.topLeft), .doubleTap) == "Ran Morning lights")
    // A plain trigger stays bare: the catalog name, no verb.
    #expect(title(BuiltInAction.playPause, .edge(.bottom), .tap) == "Play/Pause")
  }

  @Test func componentOverLightAndDarkDocuments() throws {
    let plates = VStack(alignment: .leading, spacing: 16) {
      PlateView(mark: .recognized, title: "Volume 64%", detail: "Right edge, slide")
      PlateView(mark: .level(0.4), title: "Brightness 40%", detail: "Desk 34")
      PlateView(mark: .rejected, title: "Ignored: palm, 21 mm wide, limit 18 mm")
      PlateView(mark: .recognized, title: "Opened Quillpad", detail: "Bottom-right corner, double-tap")
      PlateView(mark: .recognized, title: "Pressed ⇧⌘ 4", detail: "Top edge, tap")
      PlateView(mark: .recognized, title: "Ran Morning lights", detail: "Top-left corner, double-tap")
      PlateView(mark: .recognized, title: "Play/Pause", detail: "Bottom edge, tap")
    }
    let view = HStack(spacing: 0) {
      plates.padding(24).background(Color.white)
      plates.padding(24).background(Color.black)
    }
    #expect(try Snapshot.write(view, folder: Self.folder, name: "plate-component").count == 2)
  }
}
