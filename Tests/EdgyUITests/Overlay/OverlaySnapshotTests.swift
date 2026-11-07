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
/// Plates are drawn with no appearance override: the one plate component is always dark (bone 9
/// ruling), so every `-light` / `-dark` pair is identical by construction (critique 18 must-fix 2).
/// Each plate sits over a white and a black document strip: bone 9's worst case.
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

  // MARK: Docked on a mock screen (re-made for batch 23: menu bar, work area, along-edge check)

  /// Render D: Test Mode on, a volume slide on the right edge and a palm on the bottom-left corner.
  @Test func dockedTestMode() throws {
    try MockScreen.docked(
      "overlay-docked-test-mode", folder: Self.folder, testMode: true, decisions: MockScreen.renderD)
  }

  /// Render S8: the level plate and display check on the left, a hold on the bottom edge.
  @Test func dockedLevelAndCheck() throws {
    try MockScreen.docked(
      "overlay-docked-level-check", folder: Self.folder, testMode: true, decisions: MockScreen.renderS8)
  }
}

/// The batch-23 compositions (critique 18): light and dark documents, the level plate and the
/// display check stacked along the edge with Test Mode off, and dry run with no level plate.
@MainActor
@Suite struct OverlayCompositionTests {
  static let folder = "batch-23"

  @Test func lightDocument() throws {
    try MockScreen.docked(
      "overlay-light-document", folder: Self.folder, testMode: true,
      decisions: MockScreen.renderD + MockScreen.hold)
  }

  /// Critique 18 should-fix 3: one overlay over a dark document (the plates' light edge shows).
  @Test func darkDocument() throws {
    try MockScreen.docked(
      "overlay-dark-document", folder: Self.folder, testMode: true, darkDocument: true,
      decisions: MockScreen.renderD + MockScreen.hold)
  }

  /// Level plate + display check stacked along the left edge, Test Mode **off** (BRIEF: the level
  /// plate "shows whether or not Test Mode is on"); the glyph has no Test Mode dot.
  @Test func levelAndCheckStacked() throws {
    try MockScreen.docked(
      "overlay-level-check-stacked", folder: Self.folder, testMode: false, decisions: MockScreen.levelAndCheck)
  }

  /// The keyboard backlight's level plate with Test Mode off, over a dark document.
  @Test func levelWithTestModeOff() throws {
    try MockScreen.docked(
      "overlay-level-test-mode-off", folder: Self.folder, testMode: false, darkDocument: true,
      decisions: [
        .actionRan(
          BuiltInAction.keyboardBacklight, zone: .edge(.right), kind: .slide, outcome: ActionOutcome(level: 0.6))
      ])
  }

  /// Critique 18 must-fix 3: dry run on a brightness slide shows only "Would set Brightness", no
  /// level plate and no display check, even though the feed offers both.
  @Test func dryRunBrightness() throws {
    let engine = OverlayFakeEngine()
    engine.isTestMode = true
    let model = SettingsModel(editor: PreviewFixtures.model().editor, engine: engine)
    let placements = try MockScreen.docked(
      "overlay-dryrun-brightness", folder: Self.folder, testMode: true, model: model,
      decisions: [
        .wouldRun(BuiltInAction.brightness, zone: .edge(.left), kind: .slide),
        .displayCheckDue(key: "4c2d-7154-9", name: "Desk 34"),
      ])
    #expect(placements.map(\.content.title) == ["Would set Brightness"])
    #expect(!placements.contains { $0.content.kind == .level || $0.content.isDisplayCheck })
  }
}

/// A 1280 × 800 mock screen: a menu bar with Edgy's glyph, a warm desktop and one document window
/// whose frame and text frame are fed to the controller as the work area, so the shots show the
/// real docking and avoidance.
@MainActor
enum MockScreen {
  static let menuBarHeight: CGFloat = 24
  static let screen = OverlayScreen(
    id: "1", name: "Desk 34", frame: CGRect(x: 0, y: 0, width: 1280, height: 800),
    visibleFrame: CGRect(x: 0, y: 0, width: 1280, height: 800 - menuBarHeight))
  /// The document window and its focused text (AppKit coordinates, origin bottom-left).
  static let window = CGRect(x: 300, y: 90, width: 680, height: 630)
  static let text = window.insetBy(dx: 48, dy: 48)

  static let renderD: [LiveDecision] = [
    .actionRan(
      BuiltInAction.volume, zone: .edge(.right), kind: .slide, outcome: ActionOutcome(level: 0.64, systemHUDShown: true)
    ),
    .rejected(
      contactID: 2, zone: .corner(.bottomLeft), reason: .palm, deviceID: 1,
      measure: .init(measured: 21, limit: 18, unit: .mm)),
  ]
  static let hold: [LiveDecision] = [
    .actionRan(BuiltInAction.keyboardHold, zone: .edge(.bottom), kind: .longPress, outcome: ActionOutcome(detail: "fn"))
  ]
  static let levelAndCheck: [LiveDecision] = [
    .actionRan(
      BuiltInAction.brightness, zone: .edge(.left), kind: .slide, outcome: ActionOutcome(level: 0.4, detail: "Desk 34")),
    .displayCheckDue(key: "4c2d-7154-9", name: "Desk 34"),
  ]
  static let renderS8: [LiveDecision] = levelAndCheck + hold

  @discardableResult
  static func docked(
    _ name: String, folder: String, testMode: Bool, darkDocument: Bool = false,
    model: SettingsModel = PreviewFixtures.model(), decisions: [LiveDecision]
  ) throws -> [PlatePlacement] {
    let measurer = PanelPresenter()
    let presenter = SizingPresenter(measure: measurer.size(of:))
    let screens = FakeOverlayScreens([screen], work: OverlayWorkArea(text: text, window: window))
    let controller = OverlayController(model: model, screens: screens, presenter: presenter, clock: ManualClock())
    controller.start()
    controller.showsTestModePlates = testMode
    model.simulate(LiveFeedUpdate(touches: nil, decisions: decisions))
    controller.pump()
    let placements = presenter.shown
    for placement in placements {
      #expect(!placement.frame.intersects(text), "\(placement.content.title) covers the text")
      #expect(screen.visibleFrame.contains(placement.frame), "\(placement.content.title) is off-screen")
    }
    let view = ZStack(alignment: .topLeading) {
      MockDesktop(
        screen: screen.frame, window: window, text: text, dark: darkDocument,
        glyph: testMode ? .testMode : .normal)
      OverlayCanvasSnapshot(placements: placements, screenFrame: screen.frame)
    }
    .frame(width: screen.frame.width, height: screen.frame.height)
    #expect(try Snapshot.write(view, folder: folder, name: name).count == 2)
    return placements
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

/// A warm desktop with a menu bar (Edgy's exported glyph at the right: its dot is the only Test
/// Mode marker, bone 8) and a document window at `window`, its lines inside `text`.
struct MockDesktop: View {
  var screen: CGRect
  var window: CGRect
  var text: CGRect
  var dark: Bool
  var glyph: MenuGlyph.State

  /// A frame in AppKit coordinates as a SwiftUI offset from the screen's top-left.
  private func offset(_ frame: CGRect) -> CGSize {
    CGSize(width: frame.minX - screen.minX, height: screen.maxY - frame.maxY)
  }

  var body: some View {
    ZStack(alignment: .topLeading) {
      LinearGradient(colors: [Tokens.padTop, Tokens.bar], startPoint: .top, endPoint: .bottom)
      document
        .frame(width: window.width, height: window.height, alignment: .topLeading)
        .offset(offset(window))
      menuBar
    }
    .frame(width: screen.width, height: screen.height, alignment: .topLeading)
  }

  private var document: some View {
    let ink = dark ? Color.white : Color.black
    return ZStack(alignment: .topLeading) {
      RoundedRectangle(cornerRadius: Tokens.radiusPlate).fill(dark ? Color.black : Color.white)
      VStack(alignment: .leading, spacing: 16) {
        Text("Three days in Porto").font(Tokens.font(Tokens.typeTitle, semibold: true))
        ForEach(0..<14, id: \.self) { line in
          Capsule().fill(ink.opacity(0.16)).frame(width: line % 4 == 3 ? 300 : text.width, height: 8)
        }
      }
      .foregroundStyle(ink.opacity(0.85))
      .frame(width: text.width, height: text.height, alignment: .topLeading)
      .offset(x: text.minX - window.minX, y: window.maxY - text.maxY)
    }
  }

  private var menuBar: some View {
    HStack(spacing: 18) {
      Text("Quillpad").font(Tokens.font(Tokens.typeBody, semibold: true))
      Text("File").font(Tokens.font(Tokens.typeBody))
      Text("Edit").font(Tokens.font(Tokens.typeBody))
      Spacer()
      Image(nsImage: MenuGlyph.image(for: glyph)).renderingMode(.template)
    }
    .foregroundStyle(Color.primary)
    .padding(.horizontal, 16)
    .frame(width: screen.width, height: MockScreen.menuBarHeight)
    .background(Color(nsColor: .windowBackgroundColor).opacity(0.85))
  }
}
