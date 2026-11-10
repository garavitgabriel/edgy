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
  /// The focused text and window the fake reports (nothing by default).
  var work = OverlayWorkArea()
  private(set) var workAreaReads = 0

  init(_ screens: [OverlayScreen], main: String? = nil, work: OverlayWorkArea = OverlayWorkArea()) {
    self.screens = screens
    mainScreenID = main ?? screens.first?.id
    self.work = work
  }

  func workArea() -> OverlayWorkArea {
    workAreaReads += 1
    return work
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
  /// How many times the controller asked for a repeating tick (batch 28: zero while idle).
  private(set) var starts = 0
  func startTicking(_ tick: @escaping @MainActor () -> Void) {
    ticking = true
    starts += 1
  }
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

  /// Critique 18 must-fix 1: the check stacks beside its level plate **along the docked edge**
  /// (below it on a side edge, outward on a top or bottom edge), never inward toward the document.
  @Test func displayCheckStacksAlongTheDockedEdge() {
    let check = CGSize(width: 320, height: 110)
    let inner = visible.insetBy(dx: m, dy: m)
    let leftLevel = PlateDocking.frame(zone: .edge(.left), size: size, in: visible)
    let besideLeft = PlateDocking.beside(leftLevel, size: check, zone: .edge(.left), in: visible)
    #expect(besideLeft.minX == leftLevel.minX)
    #expect(besideLeft.maxY == leftLevel.minY - m)
    let rightLevel = PlateDocking.frame(zone: .edge(.right), size: size, in: visible)
    let besideRight = PlateDocking.beside(rightLevel, size: check, zone: .edge(.right), in: visible)
    #expect(besideRight.maxX == rightLevel.maxX)
    #expect(besideRight.maxY == rightLevel.minY - m)
    // A level plate low on its edge: the check goes above it, still on the edge.
    let low = PlateDocking.frame(zone: .edge(.left, segment: 0, segments: 4), size: size, in: visible)
    let aboveLow = PlateDocking.beside(low, size: check, zone: .edge(.left, segment: 0, segments: 4), in: visible)
    #expect(aboveLow.minX == low.minX)
    #expect(aboveLow.minY == low.maxY + m)
    // Bottom edge, left part: outward (toward the left end), on the same line.
    let bottomLeft = PlateDocking.frame(zone: .edge(.bottom, segment: 1, segments: 4), size: size, in: visible)
    let besideBottom = PlateDocking.beside(
      bottomLeft, size: check, zone: .edge(.bottom, segment: 1, segments: 4), in: visible)
    #expect(besideBottom.minY == inner.minY)
    #expect(besideBottom.maxX <= bottomLeft.minX - m || besideBottom.minX >= bottomLeft.maxX + m)
    for frame in [besideLeft, besideRight, aboveLow, besideBottom] { #expect(inner.contains(frame)) }
  }

  // MARK: Keeping clear of the text being worked on (bone 9)

  /// A document window in the middle of the screen with its focused text inside.
  let window = CGRect(x: 150, y: 100, width: 700, height: 600)
  let text = CGRect(x: 190, y: 140, width: 620, height: 520)

  @Test func aPlateNeverCoversTheFocusedText() {
    // A wide plate on the bottom edge would reach up into the text.
    let tall = CGSize(width: 300, height: 160)
    let column = CGRect(x: 340, y: 60, width: 320, height: 600)
    let docked = PlateDocking.frame(zone: .edge(.bottom), size: tall, in: visible)
    #expect(docked.intersects(column))
    let work = OverlayWorkArea(text: column, window: window)
    let settled = PlateDocking.settle(docked, zone: .edge(.bottom), in: visible, work: work)
    #expect(!settled.intersects(column.insetBy(dx: -PlateDocking.workGap, dy: -PlateDocking.workGap)))
    #expect(settled.minY == docked.minY)  // it slid along the edge, not inward
    #expect(visible.insetBy(dx: m, dy: m).contains(settled))
  }

  @Test func aPlateKeepsAGapFromTheWindowWhenThereIsRoom() {
    // The window reaches under the right edge's plate; there's open space above it on that edge.
    let docked = PlateDocking.frame(zone: .edge(.right), size: size, in: visible)
    let crowding = CGRect(x: 150, y: 100, width: 800, height: 500)
    let work = OverlayWorkArea(text: crowding.insetBy(dx: 60, dy: 60), window: crowding)
    let settled = PlateDocking.settle(docked, zone: .edge(.right), in: visible, work: work)
    #expect(!settled.intersects(crowding.insetBy(dx: -PlateDocking.workGap, dy: -PlateDocking.workGap)))
    #expect(settled.maxX == docked.maxX)
  }

  @Test func whenTheWindowFillsTheEdgeThePlateStillClearsTheText() {
    let fullWindow = CGRect(x: 0, y: 0, width: 1000, height: 800)
    let narrowText = CGRect(x: 250, y: 60, width: 500, height: 680)
    let docked = PlateDocking.frame(zone: .edge(.right), size: size, in: visible)
    let settled = PlateDocking.settle(
      docked, zone: .edge(.right), in: visible, work: OverlayWorkArea(text: narrowText, window: fullWindow))
    #expect(settled == docked)
    #expect(!settled.intersects(narrowText))
  }

  @Test func settledPlatesNeverOverlapEachOther() {
    let first = PlateDocking.frame(zone: .edge(.right), size: size, in: visible)
    let clash = first.offsetBy(dx: 0, dy: 20)
    let settled = PlateDocking.settle(clash, zone: .edge(.right), in: visible, work: OverlayWorkArea(), plates: [first])
    #expect(!settled.intersects(first))
    #expect(settled.maxX == first.maxX)
  }
}

// MARK: Timeline and fades (injected clock)

@MainActor @Suite struct TimelineTests {
  /// Critique 18 must-fix 3: BRIEF's timing numbers, stated once. The tests below prove each on the
  /// injected clock (level 1.2 s, hold 0.6 s + 200 ms, display check 15 s, at most 3 asks).
  @Test func timingsAreBRIEFs() {
    #expect(OverlayTimeline.slideLinger == 1.2)  // § Level plate: "fades 1.2 s after the slide ends"
    #expect(OverlayTimeline.releaseLinger == 0.6)  // § Hold: "'Released fn' for 0.6 s"
    #expect(OverlayTimeline.fade == 0.2)  // § Hold: "fades out over 200 ms"
    #expect(OverlayTimeline.displayCheckLinger == 15)  // § Display check: "fades after 15 s"
  }

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
    // Batch 28: the clock no longer runs from `start()`; it starts when a plate goes up.
    // Was: #expect(clock.ticking)
    #expect(!clock.ticking)
    feed(model, volumeRan)
    controller.pump()
    #expect(clock.ticking)
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

  /// Critique 18 must-fix 1, through the controller: the level plate and the display check both
  /// stay clear of the focused text, the check stacked along the level plate's edge. The work area
  /// is read once per batch of new plates, never on the 30 Hz tick.
  @Test func levelPlateAndCheckStayClearOfTheText() {
    let presenter = RecordingPresenter()
    presenter.plateSize = CGSize(width: 230, height: 90)
    let model = PreviewFixtures.model()
    let text = CGRect(x: 200, y: 120, width: 1000, height: 700)
    let screens = FakeOverlayScreens(
      [laptopScreen], work: OverlayWorkArea(text: text, window: text.insetBy(dx: -40, dy: -40)))
    let controller = OverlayController(model: model, screens: screens, presenter: presenter, clock: ManualClock())
    controller.start()
    feed(
      model,
      .actionRan(
        BuiltInAction.brightness, zone: .edge(.left), kind: .slide,
        outcome: ActionOutcome(level: 0.4, detail: "Built-in Display")),
      .displayCheckDue(key: "k", name: "Built-in Display"))
    controller.pump()
    #expect(screens.workAreaReads == 1)
    let level = try? #require(presenter.shown.first { $0.content.kind == .level }?.frame)
    let check = try? #require(presenter.shown.first { $0.content.isDisplayCheck }?.frame)
    for frame in [level, check].compactMap(\.self) {
      #expect(!frame.intersects(text))
      #expect(frame.minX == laptopScreen.visibleFrame.minX + PlateDocking.margin)
    }
    #expect(check.map { c in level.map { c.maxY <= $0.minY - PlateDocking.margin } ?? false } == true)
    for _ in 0..<5 { controller.pump() }
    #expect(screens.workAreaReads == 1)
    // The slide keeps updating every tick: the same plate, so no new read.
    for level in [0.42, 0.44, 0.46, 0.48] {
      feed(
        model,
        .actionUpdated(
          BuiltInAction.brightness, zone: .edge(.left), kind: .slide,
          outcome: ActionOutcome(level: level, detail: "Built-in Display")))
      controller.pump()
    }
    #expect(screens.workAreaReads == 1)
    // A decision with no plate (ordinary pointer use) reads nothing either.
    feed(model, .rejected(contactID: 9, zone: nil, reason: .startedOutsideZone, deviceID: 1))
    controller.pump()
    #expect(screens.workAreaReads == 1)
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
  var feedObservers = 0
  func onStatusChange(_ handler: @escaping @Sendable (EngineStatus) -> Void) {}
  func observeFeed(on queue: DispatchQueue, _ handler: @escaping @Sendable (LiveFeedUpdate) -> Void) -> UUID {
    feedObservers += 1
    return UUID()
  }
  func removeFeedObserver(_ id: UUID) {}
  func setTestMode(_ on: Bool) { isTestMode = on }
  func pause(until: Date?) {}
  func resume() {}
}

// MARK: Display check

@MainActor @Suite struct DisplayCheckTests {
  let key = "4c2d-7154-9"
  var due: LiveDecision { .displayCheckDue(key: key, name: "Desk 34") }

  @Test func showsBesideTheLevelPlateAlongItsEdgeAndCountsTheAsk() {
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
    // Along the docked edge, under the level plate (critique 18 must-fix 1), not inward.
    #expect(check.minX == level.minX)
    #expect(check.maxY == level.minY - PlateDocking.margin)
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
  /// sRGB components and alpha of a token under an appearance.
  func rgba(_ color: Color, dark: Bool) -> (Double, Double, Double, Double) {
    var result = (0.0, 0.0, 0.0, 1.0)
    NSAppearance(named: dark ? .darkAqua : .aqua)!.performAsCurrentDrawingAppearance {
      let ns = NSColor(color).usingColorSpace(.sRGB)!
      result = (
        Double(ns.redComponent), Double(ns.greenComponent), Double(ns.blueComponent), Double(ns.alphaComponent)
      )
    }
    return result
  }

  func luminance(_ c: (Double, Double, Double)) -> Double {
    func lin(_ v: Double) -> Double { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
    return 0.2126 * lin(c.0) + 0.7152 * lin(c.1) + 0.0722 * lin(c.2)
  }

  /// `color` (with its own alpha) composited over an opaque background.
  func over(_ color: Color, _ background: (Double, Double, Double), dark: Bool) -> (Double, Double, Double) {
    let c = rgba(color, dark: dark)
    let a = c.3
    return (c.0 * a + background.0 * (1 - a), c.1 * a + background.1 * (1 - a), c.2 * a + background.2 * (1 - a))
  }

  func ratio(_ a: (Double, Double, Double), _ b: (Double, Double, Double)) -> Double {
    let l1 = luminance(a)
    let l2 = luminance(b)
    return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
  }

  /// The plate (`plateFill`, with its own opacity) over a white (1) or black (0) document.
  func plate(overDocument doc: Double, dark: Bool) -> (Double, Double, Double) {
    over(Tokens.plateFill, (doc, doc, doc), dark: dark)
  }

  @Test(arguments: [true, false]) func plateTextReadsOverWhiteAndBlackDocuments(dark: Bool) {
    for document in [0.0, 1.0] {
      let plate = plate(overDocument: document, dark: dark)
      #expect(ratio(over(Tokens.plateInk, plate, dark: dark), plate) >= 4.5)
      #expect(ratio(over(Tokens.plateInk2, plate, dark: dark), plate) >= 4.5)
    }
  }

  /// Bone 9 ruling: the plate is the same dark plate in both system appearances.
  @Test func plateIsTheSameInLightAndDark() {
    for token in [Tokens.plateFill, Tokens.plateInk, Tokens.plateInk2, Tokens.plateEdge, Tokens.contactRim] {
      let light = rgba(token, dark: false)
      let dark = rgba(token, dark: true)
      #expect(light == dark)
    }
    #expect(luminance(plate(overDocument: 1, dark: false)) < 0.05)
  }

  /// Bone 9 ruling: the accent contact's 1 pt cream rim reaches ≥3:1 on the plate (the accent fill
  /// alone was about 2.6:1).
  @Test(arguments: [0.0, 1.0]) func contactRimReachesThreeToOneOnThePlate(document: Double) {
    let plate = plate(overDocument: document, dark: true)
    #expect(ratio(over(Tokens.contactRim, plate, dark: true), plate) >= 3)
  }

  /// Bone 9 ruling: over a black document the plate's light edge separates it from the page.
  @Test func plateEdgeShowsOverADarkDocument() {
    let black = (0.0, 0.0, 0.0)
    let plate = plate(overDocument: 0, dark: true)
    let edge = over(Tokens.plateEdge, plate, dark: true)
    #expect(luminance(edge) > luminance(plate))
    #expect(ratio(edge, black) > ratio(plate, black))
  }
}

/// Another surface closing (the settings window calls `stopFeed()`) must not silence the overlay.
@MainActor @Test func overlayKeepsTheFeedOnWhenAnotherSurfaceStopsIt() {
  let engine = OverlayFakeEngine()
  let model = SettingsModel(editor: PreviewFixtures.model().editor, engine: engine)
  let (controller, _, _, _) = overlayRig(model: model)
  #expect(engine.feedObservers == 1)
  model.stopFeed()
  controller.pump()
  #expect(engine.feedObservers == 2)
  controller.pump()
  #expect(engine.feedObservers == 2)
}

// MARK: Batch 28: quiet when idle

/// Batch 28: no repeating timer while nothing is up; a decision starts it, an empty timeline stops it.
@MainActor @Test func overlayClockIsStoppedWhenIdleAndStartsOnADecision() {
  let (controller, _, clock, model) = overlayRig()
  #expect(clock.starts == 0)
  #expect(!controller.isTicking)
  // Idle turns (nothing arrived) never ask for ticks.
  controller.pump()
  controller.pump()
  #expect(clock.starts == 0)
  feed(model, volumeRan)
  controller.pump()
  #expect(clock.starts == 1)
  #expect(clock.ticking)
  // Linger, fade, gone: the clock stops with the last plate.
  feed(model, slideEnded)
  controller.pump()
  clock.now += 30
  controller.pump()
  clock.now += 1
  controller.pump()
  #expect(!clock.ticking)
  #expect(!controller.isTicking)
  controller.pump()
  #expect(clock.starts == 1)
}

/// Batch 28: the overlay wakes on a decision by itself, with no tick running.
@MainActor @Test func overlayWakesOnADecisionWithoutAClock() async {
  let (controller, presenter, clock, model) = overlayRig()
  #expect(!clock.ticking)
  feed(model, volumeRan)
  for _ in 0..<20 where presenter.shown.isEmpty { await Task.yield() }
  #expect(presenter.shown.count == 1)
  #expect(clock.ticking)
  // It registers again: a second decision after the first plate is gone wakes it too.
  feed(model, slideEnded)
  controller.pump()
  clock.now += 30
  controller.pump()
  clock.now += 1
  controller.pump()
  #expect(presenter.shown.isEmpty)
  feed(model, volumeRan)
  for _ in 0..<20 where presenter.shown.isEmpty { await Task.yield() }
  #expect(presenter.shown.count == 1)
}

/// Batch 28: screens are read when a plate appears or the screens change, never per tick.
@MainActor @Test func overlayReadsScreensOnlyWhenAPlateAppears() {
  let presenter = RecordingPresenter()
  let model = PreviewFixtures.model()
  let screens = CountingOverlayScreens([laptopScreen])
  let clock = ManualClock()
  let controller = OverlayController(model: model, screens: screens, presenter: presenter, clock: clock)
  controller.start()
  controller.showsTestModePlates = true
  let afterStart = screens.reads
  feed(model, volumeRan)
  controller.pump()
  let afterPlate = screens.reads
  #expect(afterPlate > afterStart)
  for _ in 0..<10 {
    clock.now += 0.03
    controller.pump()
  }
  #expect(screens.reads == afterPlate)
  screens.screens = [deskScreen]
  controller.screensChanged()
  #expect(presenter.shown.first?.screenID == "2")
}

@MainActor
final class CountingOverlayScreens: OverlayScreenProviding {
  private var stored: [OverlayScreen]
  private(set) var reads = 0
  var screens: [OverlayScreen] {
    get {
      reads += 1
      return stored
    }
    set { stored = newValue }
  }
  var mainScreenID: String? { stored.first?.id }
  init(_ screens: [OverlayScreen]) { stored = screens }
  func workArea() -> OverlayWorkArea { OverlayWorkArea() }
}

let slideEnded = LiveDecision.recognized(zone: .edge(.right), kind: .slide, phase: .ended, deviceID: 0)
