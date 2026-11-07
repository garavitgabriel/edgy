import Actions
import AppKit
import EdgyCore
import EdgyRuntime
import Foundation
import SwiftUI
import Testing

@testable import EdgyUI

/// The batch-18 shots (light + dark) in `docs/design/build-shots/batch-18/`.
///
/// Overlay plates are shown as the overlay's panel draws them (always dark, renders D and S8),
/// over a white and a black document strip: bone 9's worst case. `plate-component-*` shows the
/// component itself following the appearance (onboarding draws it on light glass).
@MainActor
@Suite struct OverlaySnapshotTests {
  static let folder = "batch-18"

  /// A plate as the overlay draws it, over a light and a dark document.
  private func shot(_ name: String, _ content: PlateContent) throws {
    let plate = PlateView(content, onAnswer: { _ in })
    let view = HStack(spacing: 0) {
      plate.padding(24).background(Color.white)
      plate.padding(24).background(Color.black)
    }
    .environment(\.colorScheme, .dark)
    #expect(try Snapshot.write(view, folder: Self.folder, name: name).count == 2)
  }

  private func content(_ decision: LiveDecision, context: PlateContext = PlateContext(), dryRun: Bool = false) throws
    -> PlateContent
  {
    try #require(PlateContent.from(decision, catalog: overlayCatalog, context: context, dryRun: dryRun))
  }

  private let context = PlateContext(
    bindings: [
      Binding(
        zone: .corner(.bottomRight), gesture: .doubleTap, action: BuiltInAction.openApp,
        parameters: ["bundleID": "com.example.quillpad"]),
      Binding(
        zone: .edge(.bottom), gesture: .longPress, action: BuiltInAction.keyboardHold, parameters: ["keys": "fn"]),
    ], appNames: ["com.example.quillpad": "Quillpad"])

  // MARK: The component

  @Test func component() throws {
    let view = VStack(alignment: .leading, spacing: 16) {
      PlateView(mark: .recognized, title: "Volume 64%", detail: "Right edge, slide")
      PlateView(mark: .level(0.4), title: "Brightness 40%", detail: "Desk 34")
      PlateView(mark: .rejected, title: "Ignored: palm, 21 mm wide, limit 18 mm")
    }
    .padding(24)
    #expect(try Snapshot.write(view, folder: Self.folder, name: "plate-component").count == 2)
  }

  // MARK: Runs

  @Test func runVolume() throws {
    try shot(
      "plate-run-volume",
      content(
        .actionRan(
          BuiltInAction.volume, zone: .edge(.right), kind: .slide,
          outcome: ActionOutcome(level: 0.64, systemHUDShown: true)
        )))
  }

  @Test func runTrigger() throws {
    try shot("plate-run-trigger", content(.actionRan(BuiltInAction.playPause, zone: .edge(.bottom), kind: .doubleTap)))
  }

  // MARK: Dry run

  @Test func wouldSet() throws {
    try shot("plate-would-set", content(.wouldRun(BuiltInAction.volume, zone: .edge(.right), kind: .slide)))
  }

  @Test func wouldRun() throws {
    try shot("plate-would-run", content(.wouldRun(BuiltInAction.playPause, zone: .edge(.bottom), kind: .doubleTap)))
  }

  @Test func wouldOpen() throws {
    try shot(
      "plate-would-open",
      content(.wouldRun(BuiltInAction.openApp, zone: .corner(.bottomRight), kind: .doubleTap), context: context))
  }

  @Test func wouldHoldAndRelease() throws {
    let held = try content(
      .wouldRun(BuiltInAction.keyboardHold, zone: .edge(.bottom), kind: .longPress), context: context)
    try shot("plate-would-hold", held)
    try shot("plate-would-release", #require(held.released(cancelled: false)))
  }

  // MARK: Rejections: every row of bone 4's table

  static let rejections: [(String, RejectionReason, RejectionMeasure?, Zone)] = [
    ("palm-wide", .palm, .init(measured: 21, limit: 18, unit: .mm), .edge(.right)),
    ("palm-across", .palm, .init(measured: 15, limit: 14, unit: .mm), .edge(.right)),
    ("palm-size", .palm, nil, .edge(.right)),
    ("typing", .typing, .init(measured: 200, limit: 500, unit: .ms), .edge(.bottom)),
    ("fingers", .tooManyContacts, .init(measured: 2, limit: 1, unit: .fingers), .edge(.bottom)),
    ("offaxis-corner", .offAxisMotion, .init(measured: 3.4, limit: 3, unit: .mm), .corner(.topLeft)),
    ("offaxis-outward", .offAxisMotion, .init(measured: 2.8, limit: 2.5, unit: .mm), .edge(.left)),
    ("offaxis-diagonal", .offAxisMotion, .init(measured: 3.4, limit: 3, unit: .mm), .edge(.left)),
    ("offaxis-veered", .offAxisMotion, .init(measured: 9, limit: 5, unit: .mm), .edge(.bottom)),
    ("swipe-slow", .tooFast, .init(measured: 410, limit: 350, unit: .ms), .edge(.bottom)),
    ("swipe-short", .tooFast, .init(measured: 4, limit: 6, unit: .mm), .edge(.bottom)),
    ("swipe-noaxis", .tooFast, nil, .edge(.bottom)),
    ("system-gesture", .systemGestureHandoff, nil, .edge(.bottom)),
    ("click", .physicalClick, nil, .edge(.bottom)),
    ("nothing-mapped", .disabledZone, nil, .edge(.top)),
  ]

  @Test func everyRejection() throws {
    for (name, reason, measure, zone) in Self.rejections {
      try shot(
        "plate-rejected-\(name)",
        content(.rejected(contactID: 1, zone: zone, reason: reason, deviceID: 1, measure: measure)))
    }
    try shot(
      "plate-rejected-off-in-app",
      content(
        .rejected(contactID: 1, zone: .edge(.top), reason: .disabledZone, deviceID: 1),
        context: PlateContext(offInApp: "Huddle")))
  }

  // MARK: Holds

  @Test func holds() throws {
    let held = try content(
      .actionRan(
        BuiltInAction.keyboardHold, zone: .edge(.bottom), kind: .longPress, outcome: ActionOutcome(detail: "fn")))
    try shot("plate-hold-held", held)
    try shot("plate-hold-released", #require(held.released(cancelled: false)))
    try shot("plate-hold-cancelled", #require(held.released(cancelled: true)))
  }

  // MARK: Level plate and display check

  @Test func levelPlates() throws {
    try shot(
      "plate-level-brightness",
      content(
        .actionUpdated(
          BuiltInAction.brightness, zone: .edge(.left), kind: .slide,
          outcome: ActionOutcome(level: 0.4, detail: "Desk 34"))
      ))
    try shot(
      "plate-level-keyboard",
      content(
        .actionRan(
          BuiltInAction.keyboardBacklight, zone: .edge(.left), kind: .slide, outcome: ActionOutcome(level: 0.6))))
  }

  @Test func displayCheck() throws {
    try shot("plate-display-check", content(.displayCheckDue(key: "4c2d-7154-9", name: "Desk 34")))
  }

  // MARK: Docked on a mock screen

  /// Render D: Test Mode on, a volume slide on the right edge and a palm on the bottom-left corner.
  @Test func dockedTestMode() throws {
    try docked(
      "overlay-docked-test-mode", testMode: true,
      decisions: [
        .actionRan(
          BuiltInAction.volume, zone: .edge(.right), kind: .slide,
          outcome: ActionOutcome(level: 0.64, systemHUDShown: true)
        ),
        .rejected(
          contactID: 2, zone: .corner(.bottomLeft), reason: .palm, deviceID: 1,
          measure: .init(measured: 21, limit: 18, unit: .mm)),
      ])
  }

  /// Render S8: the level plate and display check on the left, a hold on the bottom edge.
  @Test func dockedLevelAndCheck() throws {
    try docked(
      "overlay-docked-level-check", testMode: true,
      decisions: [
        .actionRan(
          BuiltInAction.brightness, zone: .edge(.left), kind: .slide,
          outcome: ActionOutcome(level: 0.4, detail: "Desk 34")),
        .displayCheckDue(key: "4c2d-7154-9", name: "Desk 34"),
        .actionRan(
          BuiltInAction.keyboardHold, zone: .edge(.bottom), kind: .longPress, outcome: ActionOutcome(detail: "fn")),
      ])
  }

  private func docked(_ name: String, testMode: Bool, decisions: [LiveDecision]) throws {
    let screen = OverlayScreen(
      id: "1", name: "Desk 34", frame: CGRect(x: 0, y: 0, width: 1000, height: 650),
      visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 626))
    let measurer = PanelPresenter()
    let presenter = SizingPresenter(measure: measurer.size(of:))
    let model = PreviewFixtures.model()
    let controller = OverlayController(
      model: model, screens: FakeOverlayScreens([screen]), presenter: presenter, clock: ManualClock())
    controller.start()
    controller.showsTestModePlates = testMode
    model.simulate(LiveFeedUpdate(touches: nil, decisions: decisions))
    controller.pump()
    let placements = presenter.shown
    let view = ZStack(alignment: .topLeading) {
      MockDesktop()
      OverlayCanvasSnapshot(placements: placements, screenFrame: screen.frame)
        .environment(\.colorScheme, .dark)
    }
    .frame(width: screen.frame.width, height: screen.frame.height)
    #expect(try Snapshot.write(view, folder: Self.folder, name: name).count == 2)
  }
}

/// Records placements, measuring plates with the live presenter's sizing (draws nothing).
@MainActor
final class SizingPresenter: OverlayPresenting {
  let measure: (PlateContent) -> CGSize
  private(set) var shown: [PlatePlacement] = []
  init(measure: @escaping (PlateContent) -> CGSize) { self.measure = measure }
  func size(of content: PlateContent) -> CGSize { measure(content) }
  func present(_ placements: [PlatePlacement], screens: [OverlayScreen], answer: @escaping @MainActor (Bool) -> Void) {
    shown = placements
  }
  func tearDown() { shown = [] }
}

/// The overlay canvas for a snapshot: the display check drawn in place with its buttons.
struct OverlayCanvasSnapshot: View {
  var placements: [PlatePlacement]
  var screenFrame: CGRect

  var body: some View {
    ZStack(alignment: .topLeading) {
      Color.clear
      ForEach(placements, id: \.id) { placement in
        PlateView(placement.content, onAnswer: { _ in })
          .frame(width: placement.frame.width, height: placement.frame.height, alignment: .topLeading)
          .offset(x: placement.frame.minX - screenFrame.minX, y: screenFrame.maxY - placement.frame.maxY)
      }
    }
    .frame(width: screenFrame.width, height: screenFrame.height, alignment: .topLeading)
  }
}

/// A warm desktop with a document window, standing in for render D's screen.
struct MockDesktop: View {
  var body: some View {
    ZStack {
      LinearGradient(colors: [Tokens.padTop, Tokens.bar], startPoint: .top, endPoint: .bottom)
      VStack(alignment: .leading, spacing: 14) {
        Text("Three days in Porto").font(Tokens.font(Tokens.typeTitle, semibold: true))
        ForEach(0..<9, id: \.self) { line in
          Capsule().fill(Color.black.opacity(0.12)).frame(width: line % 3 == 2 ? 300 : 520, height: 8)
        }
      }
      .foregroundStyle(Color.black.opacity(0.85))
      .padding(48)
      .frame(width: 640, height: 470, alignment: .topLeading)
      .background(Color.white)
      .clipShape(RoundedRectangle(cornerRadius: Tokens.radiusPlate))
    }
  }
}
