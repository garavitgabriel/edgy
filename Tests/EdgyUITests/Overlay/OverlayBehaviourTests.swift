import Actions
import AppKit
import CoreGraphics
import EdgyCore
import EdgyRuntime
import Foundation
import SwiftUI
import Testing

@testable import EdgyUI

// MARK: Fakes (nothing here reaches a real screen)

@MainActor
final class FakeOverlayScreens: OverlayScreenProviding {
  var screens: [OverlayScreen]
  var mainScreenID: String?

  init(_ screens: [OverlayScreen], main: String? = nil) {
    self.screens = screens
    mainScreenID = main ?? screens.first?.id
  }
}

@MainActor
final class RecordingPresenter: OverlayPresenting {
  var plateSize = CGSize(width: 260, height: 60)
  private(set) var shown: [PlatePlacement] = []
  private(set) var answer: (@MainActor (Bool) -> Void)?
  private(set) var tornDown = 0

  func size(of content: PlateContent) -> CGSize { plateSize }

  func present(_ placements: [PlatePlacement], screens: [OverlayScreen], answer: @escaping @MainActor (Bool) -> Void) {
    shown = placements
    self.answer = answer
  }

  func tearDown() {
    shown = []
    tornDown += 1
  }
}

@MainActor
final class ManualClock: OverlayClock {
  var now: TimeInterval = 1000
  private(set) var ticking = false
  func startTicking(_ tick: @escaping @MainActor () -> Void) { ticking = true }
  func stopTicking() { ticking = false }
}

let laptopScreen = OverlayScreen(
  id: "1", name: "Built-in Display", frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
  visibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 949))
let deskScreen = OverlayScreen(
  id: "2", name: "Desk 34", frame: CGRect(x: 1512, y: 0, width: 2560, height: 1440),
  visibleFrame: CGRect(x: 1512, y: 0, width: 2560, height: 1415))

@MainActor
func overlayRig(
  screens: [OverlayScreen] = [laptopScreen], testMode: Bool = true, model: SettingsModel = PreviewFixtures.model()
) -> (OverlayController, RecordingPresenter, ManualClock, SettingsModel) {
  let presenter = RecordingPresenter()
  let clock = ManualClock()
  let controller = OverlayController(
    model: model, screens: FakeOverlayScreens(screens), presenter: presenter, clock: clock)
  controller.start()
  controller.showsTestModePlates = testMode
  return (controller, presenter, clock, model)
}

@MainActor
func feed(_ model: SettingsModel, _ decisions: LiveDecision...) {
  model.simulate(LiveFeedUpdate(touches: nil, decisions: decisions))
}

let volumeRan = LiveDecision.actionRan(
  BuiltInAction.volume, zone: .edge(.right), kind: .slide, outcome: ActionOutcome(level: 0.64, systemHUDShown: true))

// MARK: Docking geometry

@Suite struct DockingTests {
  let visible = CGRect(x: 0, y: 0, width: 1000, height: 800)
  let size = CGSize(width: 200, height: 60)
  let m = PlateDocking.margin

  @Test func rightEdgeDocksAtTheRightMiddle() {
    let frame = PlateDocking.frame(zone: .edge(.right), size: size, in: visible)
    #expect(frame.maxX == visible.maxX - m)
    #expect(frame.midY == visible.midY)
  }

  @Test func leftEdgeDocksAtTheLeftMiddle() {
    let frame = PlateDocking.frame(zone: .edge(.left), size: size, in: visible)
    #expect(frame.minX == visible.minX + m)
    #expect(frame.midY == visible.midY)
  }

  @Test func topAndBottomEdgesDockCentred() {
    let top = PlateDocking.frame(zone: .edge(.top), size: size, in: visible)
    #expect(top.maxY == visible.maxY - m)
    #expect(top.midX == visible.midX)
    let bottom = PlateDocking.frame(zone: .edge(.bottom), size: size, in: visible)
    #expect(bottom.minY == visible.minY + m)
    #expect(bottom.midX == visible.midX)
  }

  @Test(arguments: Zone.Corner.allCases) func cornersDockInTheirCorner(corner: Zone.Corner) {
    let frame = PlateDocking.frame(zone: .corner(corner), size: size, in: visible)
    let isRight = corner == .topRight || corner == .bottomRight
    let isTop = corner == .topLeft || corner == .topRight
    #expect(isRight ? frame.maxX == visible.maxX - m : frame.minX == visible.minX + m)
    #expect(isTop ? frame.maxY == visible.maxY - m : frame.minY == visible.minY + m)
  }

  @Test func splitSideSegmentsDockBesideTheirPart() {
    let upper = PlateDocking.frame(zone: .edge(.right, segment: 1, segments: 2), size: size, in: visible)
    let lower = PlateDocking.frame(zone: .edge(.right, segment: 0, segments: 2), size: size, in: visible)
    #expect(upper.midY > visible.midY)
    #expect(lower.midY < visible.midY)
  }

  @Test(arguments: [Zone.edge(.right), .edge(.left), .edge(.top), .edge(.bottom), .corner(.topRight)])
  func platesStayFullyOnScreenEvenWhenStacked(zone: Zone) {
    for stack in 0..<12 {
      let frame = PlateDocking.frame(zone: zone, size: size, in: visible, stack: stack)
      #expect(visible.insetBy(dx: m, dy: m).contains(frame))
    }
  }

  @Test func aPlateWiderThanItsSegmentStillFits() {
    let wide = CGSize(width: 600, height: 60)
    let frame = PlateDocking.frame(zone: .edge(.top, segment: 3, segments: 4), size: wide, in: visible)
    #expect(visible.insetBy(dx: m, dy: m).contains(frame))
  }

  @Test func displayCheckSitsBesideTheLevelPlateTowardTheMiddle() {
    let check = CGSize(width: 320, height: 110)
    let leftLevel = PlateDocking.frame(zone: .edge(.left), size: size, in: visible)
    let besideLeft = PlateDocking.beside(leftLevel, size: check, zone: .edge(.left), in: visible)
    #expect(besideLeft.minX == leftLevel.maxX + m)
    #expect(besideLeft.maxY == leftLevel.maxY)
    let rightLevel = PlateDocking.frame(zone: .edge(.right), size: size, in: visible)
    let besideRight = PlateDocking.beside(rightLevel, size: check, zone: .edge(.right), in: visible)
    #expect(besideRight.maxX == rightLevel.minX - m)
  }
}

// MARK: Timeline and fades (injected clock)

@MainActor @Suite struct TimelineTests {
  @Test func testModePlatesFadeOnTime() {
    let (controller, presenter, clock, model) = overlayRig()
    feed(model, .actionRan(BuiltInAction.playPause, zone: .edge(.bottom), kind: .doubleTap))
    controller.pump()
    #expect(presenter.shown.map(\.content.title) == ["Play/Pause"])
    clock.now += OverlayTimeline.plateLinger + 0.1
    controller.pump()
    #expect(abs((presenter.shown.first?.opacity ?? 0) - 0.5) < 0.001)
    clock.now += 0.1
    controller.pump()
    #expect(presenter.shown.isEmpty)
  }

  @Test func levelPlateFades1point2sAfterTheSlideEnds() {
    let (controller, presenter, clock, model) = overlayRig(testMode: false)
    feed(
      model,
      .actionRan(
        BuiltInAction.brightness, zone: .edge(.left), kind: .slide,
        outcome: ActionOutcome(level: 0.3, detail: "Desk 34")))
    controller.pump()
    clock.now += 5
    feed(
      model,
      .actionUpdated(
        BuiltInAction.brightness, zone: .edge(.left), kind: .slide,
        outcome: ActionOutcome(level: 0.4, detail: "Desk 34")))
    controller.pump()
    #expect(presenter.shown.map(\.content.title) == ["Brightness 40%"])
    #expect(presenter.shown.first?.opacity == 1)
    feed(model, .recognized(zone: .edge(.left), kind: .slide, phase: .ended, deviceID: 1))
    controller.pump()
    clock.now += 1.2
    controller.pump()
    #expect(presenter.shown.first?.opacity == 1)
    clock.now += 0.2
    controller.pump()
    #expect(presenter.shown.isEmpty)
  }

  @Test func holdReadsReleasedFor0point6sThenFades200ms() {
    let (controller, presenter, clock, model) = overlayRig()
    feed(
      model,
      .actionRan(
        BuiltInAction.keyboardHold, zone: .edge(.bottom), kind: .longPress, outcome: ActionOutcome(detail: "fn")))
    controller.pump()
    clock.now += 30
    controller.pump()
    #expect(presenter.shown.map(\.content.title) == ["Holding fn"])
    feed(model, .recognized(zone: .edge(.bottom), kind: .longPress, phase: .ended, deviceID: 1))
    controller.pump()
    #expect(presenter.shown.map(\.content.title) == ["Released fn"])
    clock.now += 0.6
    controller.pump()
    #expect(presenter.shown.first?.opacity == 1)
    clock.now += 0.1
    controller.pump()
    #expect(abs((presenter.shown.first?.opacity ?? 0) - 0.5) < 0.001)
    clock.now += 0.1
    controller.pump()
    #expect(presenter.shown.isEmpty)
  }

  @Test func cancelledHoldSaysTheFingerLeft() {
    let (controller, presenter, _, model) = overlayRig()
    feed(
      model,
      .actionRan(
        BuiltInAction.keyboardHold, zone: .edge(.bottom), kind: .longPress, outcome: ActionOutcome(detail: "fn")),
      .recognized(zone: .edge(.bottom), kind: .longPress, phase: .cancelled, deviceID: 1))
    controller.pump()
    #expect(presenter.shown.map(\.content.title) == ["Released fn, finger left the zone"])
  }

  @Test func platesReplaceEachOtherPerZone() {
    let (controller, presenter, _, model) = overlayRig()
    feed(
      model,
      .rejected(contactID: 1, zone: .edge(.bottom), reason: .physicalClick, deviceID: 1),
      .actionRan(BuiltInAction.playPause, zone: .edge(.bottom), kind: .doubleTap),
      .actionRan(BuiltInAction.mute, zone: .corner(.topRight), kind: .doubleTap))
    controller.pump()
    #expect(presenter.shown.map(\.content.title) == ["Play/Pause", "Mute"])
  }

  @Test func platesNeverPileUpWithoutBound() {
    let (controller, presenter, _, model) = overlayRig()
    for segment in 0..<4 {
      for edge in Zone.Edge.allCases {
        feed(model, .actionRan(BuiltInAction.mute, zone: .edge(edge, segment: segment, segments: 4), kind: .tap))
      }
    }
    controller.pump()
    #expect(presenter.shown.count == OverlayTimeline.maxPlates)
  }

  @Test func testModeOffShowsOnlyLevelPlates() {
    let (controller, presenter, _, model) = overlayRig(testMode: false)
    feed(
      model, volumeRan,
      .rejected(contactID: 1, zone: .edge(.bottom), reason: .physicalClick, deviceID: 1),
      .actionRan(
        BuiltInAction.keyboardBacklight, zone: .edge(.left), kind: .slide, outcome: ActionOutcome(level: 0.6)))
    controller.pump()
    #expect(presenter.shown.map(\.content.title) == ["Keyboard 60%"])
  }

  @Test func turningTestModeOffClearsItsPlates() {
    let (controller, presenter, _, model) = overlayRig()
    feed(model, volumeRan)
    controller.pump()
    #expect(presenter.shown.count == 1)
    controller.showsTestModePlates = false
    #expect(presenter.shown.isEmpty)
  }

  @Test func stopTakesEverythingDown() {
    let (controller, presenter, clock, model) = overlayRig()
    #expect(clock.ticking)
    feed(model, volumeRan)
    controller.pump()
    controller.stop()
    #expect(!clock.ticking)
    #expect(presenter.tornDown == 1)
    #expect(presenter.shown.isEmpty)
  }
}

// MARK: Screens

@MainActor @Suite struct OverlayScreenTests {
  @Test func testModePlatesGoOnTheScreenBeingWorkedOn() {
    let presenter = RecordingPresenter()
    let model = PreviewFixtures.model()
    let controller = OverlayController(
      model: model, screens: FakeOverlayScreens([laptopScreen, deskScreen], main: "2"), presenter: presenter,
      clock: ManualClock())
    controller.start()
    controller.showsTestModePlates = true
    feed(model, volumeRan)
    controller.pump()
    let placed = presenter.shown.first
    #expect(placed?.screenID == "2")
    #expect(placed.map { deskScreen.visibleFrame.contains($0.frame) } == true)
    #expect(placed?.frame.maxX == deskScreen.visibleFrame.maxX - PlateDocking.margin)
  }

  @Test func levelPlateGoesOnTheDisplayItChanged() {
    let presenter = RecordingPresenter()
    let model = PreviewFixtures.model()
    let controller = OverlayController(
      model: model, screens: FakeOverlayScreens([laptopScreen, deskScreen], main: "1"), presenter: presenter,
      clock: ManualClock())
    controller.start()
    feed(
      model,
      .actionRan(
        BuiltInAction.brightness, zone: .edge(.left), kind: .slide,
        outcome: ActionOutcome(level: 0.4, detail: "Desk 34")))
    controller.pump()
    #expect(presenter.shown.first?.screenID == "2")
    #expect(presenter.shown.first?.frame.minX == deskScreen.visibleFrame.minX + PlateDocking.margin)
  }

  @Test func noLevelPlateInDryRun() {
    let engine = OverlayFakeEngine()
    engine.isTestMode = true
    let model = SettingsModel(editor: PreviewFixtures.model().editor, engine: engine)
    let (controller, presenter, _, _) = overlayRig(testMode: true, model: model)
    #expect(model.isDryRun)
    feed(
      model, .wouldRun(BuiltInAction.brightness, zone: .edge(.left), kind: .slide),
      .actionRan(
        BuiltInAction.keyboardBacklight, zone: .edge(.right), kind: .slide, outcome: ActionOutcome(level: 0.6)))
    controller.pump()
    #expect(!presenter.shown.contains { $0.content.kind == .level })
    #expect(presenter.shown.contains { $0.content.mark == .wouldRun })
  }
}

/// A scripted engine for dry run; it only records the Test Mode flag.
final class OverlayFakeEngine: LiveEngine, @unchecked Sendable {
  var status = EngineStatus(
    running: true, enabled: true,
    devices: [
      TouchDeviceInfo(id: 1, kind: .externalTrackpad, sensorSizeMM: Size2D(width: 160, height: 115), familyID: 0)
    ])
  var isTestMode = false
  func onStatusChange(_ handler: @escaping @Sendable (EngineStatus) -> Void) {}
  func observeFeed(on queue: DispatchQueue, _ handler: @escaping @Sendable (LiveFeedUpdate) -> Void) -> UUID { UUID() }
  func removeFeedObserver(_ id: UUID) {}
  func setTestMode(_ on: Bool) { isTestMode = on }
  func pause(until: Date?) {}
  func resume() {}
}

// MARK: Display check

@MainActor @Suite struct DisplayCheckTests {
  let key = "4c2d-7154-9"
  var due: LiveDecision { .displayCheckDue(key: key, name: "Desk 34") }

  @Test func showsBesideTheLevelPlateAndCountsTheAsk() {
    let (controller, presenter, _, model) = overlayRig(screens: [laptopScreen, deskScreen], testMode: false)
    feed(
      model,
      .actionRan(
        BuiltInAction.brightness, zone: .edge(.left), kind: .slide,
        outcome: ActionOutcome(level: 0.4, detail: "Desk 34")),
      due)
    controller.pump()
    #expect(presenter.shown.map(\.content.title) == ["Brightness 40%", PlateContent.displayCheckQuestion])
    let level = presenter.shown[0].frame
    let check = presenter.shown[1].frame
    #expect(presenter.shown[1].screenID == "2")
    #expect(check.minX == level.maxX + PlateDocking.margin)
    #expect(model.editor.config.app.displayCheckAsks[key] == 1)
  }

  @Test func yesConfirmsTheDisplay() {
    let (controller, presenter, _, model) = overlayRig(testMode: false)
    feed(model, due)
    controller.pump()
    presenter.answer?(true)
    #expect(model.editor.config.app.confirmedDisplays.contains(key))
    #expect(presenter.shown.isEmpty)
  }

  @Test func noTurnsItOffForThisDisplay() {
    let (controller, presenter, _, model) = overlayRig(testMode: false)
    feed(model, due)
    controller.pump()
    presenter.answer?(false)
    #expect(model.editor.config.app.unresponsiveDisplays.contains(key))
    #expect(!model.editor.displayCheckDue(key: key))
  }

  @Test func fadesAfter15sUnanswered() {
    let (controller, presenter, clock, model) = overlayRig(testMode: false)
    feed(model, due)
    controller.pump()
    clock.now += 15
    controller.pump()
    #expect(presenter.shown.first?.opacity == 1)
    clock.now += 0.2
    controller.pump()
    #expect(presenter.shown.isEmpty)
    #expect(controller.askingDisplay == nil)
  }

  @Test func asksAtMostThreeTimes() {
    let (controller, presenter, clock, model) = overlayRig(testMode: false)
    for _ in 0..<5 {
      feed(model, due)
      controller.pump()
      clock.now += 20
      controller.pump()
    }
    #expect(model.editor.config.app.displayCheckAsks[key] == 3)
    feed(model, due)
    controller.pump()
    #expect(presenter.shown.isEmpty)
  }
}

// MARK: Ordinary pointer use

@MainActor @Test func plainTouchesNeverMakeAPlate() {
  let (controller, presenter, _, model) = overlayRig()
  let touch = LiveTouch(id: 1, position: Point2D(x: 80, y: 60), state: .down)
  model.simulate(
    LiveFeedUpdate(touches: LiveTouchFrame(deviceID: 1, timestamp: 1, touches: [touch]), decisions: []))
  feed(
    model,
    .rejected(
      contactID: 1, zone: nil, reason: .startedOutsideZone, deviceID: 1,
      measure: .init(measured: 25, limit: 8, unit: .mm)))
  controller.pump()
  #expect(presenter.shown.isEmpty)
}

// MARK: Contrast (bone 9: ≥4.5:1 over light and dark documents)

@MainActor @Suite struct PlateContrastTests {
  /// sRGB components of a token under an appearance.
  func rgb(_ color: Color, dark: Bool) -> (Double, Double, Double) {
    var result = (0.0, 0.0, 0.0)
    NSAppearance(named: dark ? .darkAqua : .aqua)!.performAsCurrentDrawingAppearance {
      let ns = NSColor(color).usingColorSpace(.sRGB)!
      result = (Double(ns.redComponent), Double(ns.greenComponent), Double(ns.blueComponent))
    }
    return result
  }

  func luminance(_ c: (Double, Double, Double)) -> Double {
    func lin(_ v: Double) -> Double { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
    return 0.2126 * lin(c.0) + 0.7152 * lin(c.1) + 0.0722 * lin(c.2)
  }

  func contrast(_ text: Color, overDocument doc: Double, dark: Bool) -> Double {
    let tint = rgb(Tokens.windowTint, dark: dark)
    let a = PlateMetrics.tintOpacity
    let plate = (tint.0 * a + doc * (1 - a), tint.1 * a + doc * (1 - a), tint.2 * a + doc * (1 - a))
    let l1 = luminance(rgb(text, dark: dark))
    let l2 = luminance(plate)
    return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
  }

  @Test(arguments: [true, false]) func plateTextReadsOverWhiteAndBlackDocuments(dark: Bool) {
    for document in [0.0, 1.0] {
      #expect(contrast(Tokens.ink, overDocument: document, dark: dark) >= 4.5)
      #expect(contrast(Tokens.ink2, overDocument: document, dark: dark) >= 4.5)
    }
  }
}
