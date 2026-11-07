import EdgyCore
import EdgyRuntime
import Foundation
import Testing

@testable import EdgyUI

/// A scripted engine: records what the popover asks for, touches nothing real.
final class FakeEngine: LiveEngine, @unchecked Sendable {
  var status = EngineStatus(
    running: true, enabled: true,
    devices: [
      TouchDeviceInfo(id: 1, kind: .externalTrackpad, sensorSizeMM: Size2D(width: 160, height: 115), familyID: 0)
    ])
  var isTestMode = false
  var pausedUntil: [Date?] = []
  var resumes = 0

  func onStatusChange(_ handler: @escaping @Sendable (EngineStatus) -> Void) {}
  func observeFeed(on queue: DispatchQueue, _ handler: @escaping @Sendable (LiveFeedUpdate) -> Void) -> UUID { UUID() }
  func removeFeedObserver(_ id: UUID) {}
  func setTestMode(_ on: Bool) { isTestMode = on }
  func pause(until: Date?) { pausedUntil.append(until) }
  func resume() { resumes += 1 }
}

@MainActor
func modelWithFakeEngine() -> (SettingsModel, FakeEngine) {
  let engine = FakeEngine()
  let model = SettingsModel(editor: PreviewFixtures.model().editor, engine: engine)
  return (model, engine)
}

// MARK: Test Mode and "Don't run actions"

@MainActor @Test func dontRunActionsShowsOnlyWhileTestModeIsOn() {
  let (model, _) = modelWithFakeEngine()
  let state = MenuBarState()
  #expect(!state.showsDontRunActions)
  state.setTestMode(true, model: model)
  #expect(state.showsDontRunActions)
  #expect(!state.dontRunActions, "off by default")
  state.setTestMode(false, model: model)
  #expect(!state.showsDontRunActions)
}

@MainActor @Test func testModeAloneKeepsActionsRunning() {
  let (model, engine) = modelWithFakeEngine()
  let state = MenuBarState()
  state.setTestMode(true, model: model)
  #expect(state.testMode)
  #expect(!model.isTestMode)
  #expect(!engine.isTestMode, "the overlay shows; actions still run")
}

@MainActor @Test func dontRunActionsTurnsOnTheEngineDryRun() {
  let (model, engine) = modelWithFakeEngine()
  let state = MenuBarState()
  state.setTestMode(true, model: model)
  state.setDontRunActions(true, model: model)
  #expect(model.isTestMode)
  #expect(engine.isTestMode)
  state.setDontRunActions(false, model: model)
  #expect(!engine.isTestMode)
}

@MainActor @Test func turningTestModeOffResetsDontRunActions() {
  let (model, engine) = modelWithFakeEngine()
  let state = MenuBarState()
  state.setTestMode(true, model: model)
  state.setDontRunActions(true, model: model)
  state.setTestMode(false, model: model)
  #expect(!state.dontRunActions)
  #expect(!engine.isTestMode, "no one is left with an Edgy that silently does nothing")
  state.setTestMode(true, model: model)
  #expect(!state.dontRunActions, "not remembered")
}

@MainActor @Test func dontRunActionsIgnoredWhileTestModeIsOff() {
  let (model, engine) = modelWithFakeEngine()
  let state = MenuBarState()
  state.setDontRunActions(true, model: model)
  #expect(!state.dontRunActions)
  #expect(!engine.isTestMode)
}

@MainActor @Test func overlayFlagIsReportedToTheController() {
  let (model, _) = modelWithFakeEngine()
  let controller = MenuBarController(model: model)
  var seen: [Bool] = []
  controller.onOverlayVisibleChange = { seen.append($0) }
  controller.state.setTestMode(true, model: model)
  #expect(controller.isOverlayVisible)
  #expect(controller.glyphState == .testMode)
  controller.state.setTestMode(false, model: model)
  #expect(seen == [true, false])
  #expect(controller.glyphState == .normal)
}

// MARK: Paused

@Test func pausedCopyCountsDownInWholeMinutes() {
  let now = Date(timeIntervalSinceReferenceDate: 0)
  #expect(PopoverCopy.paused(until: now.addingTimeInterval(47 * 60 + 30), now: now) == "Paused, 47 min left")
  #expect(PopoverCopy.paused(until: now.addingTimeInterval(60), now: now) == "Paused, 1 min left")
  #expect(PopoverCopy.paused(until: now.addingTimeInterval(119), now: now) == "Paused, 1 min left")
  #expect(PopoverCopy.paused(until: now.addingTimeInterval(59), now: now) == "Paused, less than a minute left")
}

@Test func pauseRowIsHiddenWhilePaused() {
  // The config file rows left the list (chief, 2026-11-07); recovery stays in the broken-config block.
  #expect(MenuRow.visible(paused: false) == [.pause, .settings, .about, .quit])
  #expect(MenuRow.visible(paused: true) == [.settings, .about, .quit])
}

@Test func listCopyAndShortcutsMatchTheBrief() {
  #expect(
    MenuRow.allCases.map(\.title) == [
      "Pause for 1 hour", "Settings…", "Open config file", "Reload config", "About Edgy", "Quit Edgy",
    ])
  #expect(MenuRow.allCases.map(\.shortcut) == [nil, "⌘,", nil, "⌘R", nil, "⌘Q"])
  #expect(MenuRow.allCases.filter(\.startsSecondGroup) == [.about])
}

// MARK: List actions

@MainActor @Test func listRowsCallTheirClosures() {
  let (model, engine) = modelWithFakeEngine()
  var calls: [String] = []
  let actions = MenuBarActions(
    openSettings: { calls.append("settings") }, openConfigFile: { calls.append("config") },
    reloadConfig: { calls.append("reload") }, about: { calls.append("about") }, quit: { calls.append("quit") })
  let now = Date(timeIntervalSinceReferenceDate: 1000)
  for row in MenuRow.allCases { row.perform(actions: actions, model: model, now: now) }
  #expect(calls == ["settings", "config", "reload", "about", "quit"])
  #expect(engine.pausedUntil == [now.addingTimeInterval(3600)], "Pause for 1 hour")
}

@MainActor @Test func controllerActionsClosePopoverFirst() {
  var order: [String] = []
  let actions = MenuBarActions(quit: { order.append("quit") }).preceded { order.append("close") }
  actions.quit()
  #expect(order == ["close", "quit"])
}

// MARK: Chips

@MainActor @Test func chipsPutDefaultFirstWhenTheFrontmostAppHasNoProfile() {
  let model = PreviewFixtures.model()
  let chips = ProfileChip.chips(model: model, frontmost: "com.example.other", apps: [])
  #expect(chips.map(\.name) == ["Default", "Huddle", "Wayfare"])
  #expect(chips.filter(\.isLive).map(\.ref) == [.default])
}

@MainActor @Test func frontmostAppsChipComesFirstAndIsLive() {
  let model = PreviewFixtures.model()
  let chips = ProfileChip.chips(model: model, frontmost: PreviewFixtures.wayfare, apps: [])
  #expect(chips.map(\.name) == ["Wayfare", "Default", "Huddle"])
  #expect(chips.filter(\.isLive).map(\.ref) == [.app(PreviewFixtures.wayfare)])
  #expect(chips.first { $0.name == "Huddle" }?.isOff == true)
}

@MainActor @Test func offAppInFrontFadesTheMiniMirror() {
  let model = PreviewFixtures.model()
  let state = MenuBarState()
  state.frontmostBundleID = PreviewFixtures.huddle
  #expect(PopoverMirror.resolve(state: state, model: model).faded)
  state.frontmostBundleID = PreviewFixtures.wayfare
  #expect(!PopoverMirror.resolve(state: state, model: model).faded)
  model.setEnabled(false)
  #expect(PopoverMirror.resolve(state: state, model: model).faded)
}

// MARK: Top half

@MainActor @Test func topHalfPrecedence() {
  let model = PreviewFixtures.model()
  let state = MenuBarState()
  #expect(PopoverTop.resolve(state: state, model: model) == .normal(PopoverMirror.resolve(state: state, model: model)))
  state.accessibility = .unknown
  if case .normal = PopoverTop.resolve(state: state, model: model) {} else { Issue.record("unknown shows nothing") }
  state.accessibility = .denied
  #expect(PopoverTop.resolve(state: state, model: model) == .needsAccessibility)
  let problem = EdgyUI.ConfigProblem(line: 14, message: "Unexpected character")
  state.configProblem = problem
  #expect(PopoverTop.resolve(state: state, model: model) == .brokenConfig(problem))
  #expect(
    problem.sentence
      == "config.json has an error on line 14: Unexpected character. Edgy kept the last working settings.")
}

@MainActor @Test func enabledSwitchIsGlobal() {
  let model = PreviewFixtures.model()
  model.selectedProfile = .app(PreviewFixtures.wayfare)
  model.setEnabled(false)
  #expect(!model.editor.config.app.enabled)
  model.setEnabled(true)
  #expect(model.editor.config.app.enabled)
}
