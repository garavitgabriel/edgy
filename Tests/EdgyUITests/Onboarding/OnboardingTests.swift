import Actions
import AppKit
import EdgyCore
import EdgyRuntime
import Foundation
import Testing

@testable import EdgyUI

/// A scripted Accessibility answer.
@MainActor
final class FakePermissions: PermissionChecking {
  var accessibility: PermissionState
  init(_ state: PermissionState) { accessibility = state }
}

/// Runs scheduled work only when the test says so.
@MainActor
final class ManualScheduler: Scheduling {
  private final class Work: ScheduledWork {
    var cancelled = false
    func cancel() { cancelled = true }
  }

  private var queue: [(Work, @MainActor @Sendable () -> Void)] = []

  @discardableResult
  func schedule(after seconds: TimeInterval, _ work: @escaping @MainActor @Sendable () -> Void) -> ScheduledWork {
    let handle = Work()
    queue.append((handle, work))
    return handle
  }

  func runAll() {
    let due = queue
    queue = []
    for (handle, work) in due where !handle.cancelled { work() }
  }
}

/// Counts the controller's outward calls.
@MainActor
final class OnboardingCalls {
  var openSettings = 0
  var finish = 0

  var actions: OnboardingActions {
    OnboardingActions(
      openAccessibilitySettings: { [self] in openSettings += 1 }, finish: { [self] in finish += 1 })
  }
}

@MainActor
enum OnboardingFixtures {
  static let rightSlide = LiveDecision.recognized(
    zone: .edge(.right), kind: .slide, phase: .began, deviceID: PreviewFixtures.externalPad.id)

  static func decisions(_ decisions: [LiveDecision]) -> LiveFeedUpdate {
    LiveFeedUpdate(touches: nil, decisions: decisions)
  }

  /// A model on plain defaults (first launch).
  static func model(config: EdgyConfig = .defaults) -> SettingsModel {
    PreviewFixtures.model(config: config)
  }

  /// Lets the state's observation hop (a main-actor task) run.
  static func settle() async {
    for _ in 0..<20 { await Task.yield() }
  }

  /// A state moved to `step` the way a user gets there (Skip for now, a slide, Continue).
  static func state(at step: OnboardingState.Step, model: SettingsModel, actions: OnboardingActions = .none)
    -> OnboardingState
  {
    let state = OnboardingState(model: model, actions: actions)
    if step >= .tryIt { state.quiet() }
    if step >= .preset {
      state.receive([rightSlide])
      state.primary()
    }
    if step >= .launchAtLogin { state.primary() }
    return state
  }
}

@MainActor
@Suite struct OnboardingFlowTests {
  @Test func opensOnAccessibilityWithOpenSettingsAndSkip() {
    let calls = OnboardingCalls()
    let state = OnboardingState(model: OnboardingFixtures.model(), actions: calls.actions)
    #expect(state.step == .accessibility)
    #expect(state.primaryTitle == "Open Settings")
    #expect(state.quietTitle == "Skip for now")
    state.primary()
    #expect(calls.openSettings == 1)
    #expect(state.step == .accessibility)
  }

  @Test func permissionFlipsLiveFromTheChecker() {
    let model = OnboardingFixtures.model()
    let checker = FakePermissions(.denied)
    let scheduler = ManualScheduler()
    let controller = OnboardingController(
      model: model, actions: .none, permissions: checker, scheduler: scheduler)
    controller.startWatching()
    let state = controller.state
    #expect(state.accessibility == .denied)
    #expect(!state.isDone(.accessibility))

    scheduler.runAll()
    #expect(state.accessibility == .denied)

    checker.accessibility = .granted
    scheduler.runAll()
    #expect(state.accessibility == .granted)
    #expect(state.isDone(.accessibility))
    #expect(state.primaryTitle == "Continue")
    #expect(state.quietTitle == nil)
    #expect(state.step == .accessibility)

    state.primary()
    #expect(state.step == .tryIt)
    #expect(state.isDone(.accessibility))
  }

  @Test func skipForNowContinuesWithoutAccess() {
    let state = OnboardingState(model: OnboardingFixtures.model())
    state.setAccessibility(.denied)
    state.quiet()
    #expect(state.step == .tryIt)
    #expect(!state.isDone(.accessibility))
    #expect(state.quietTitle == "Back")
  }

  @Test func backWalksTheStepsInReverse() {
    let state = OnboardingFixtures.state(at: .launchAtLogin, model: OnboardingFixtures.model())
    #expect(state.step == .launchAtLogin)
    #expect(state.isDone(.tryIt) && state.isDone(.preset))
    #expect(state.primaryTitle == "Done")
    state.quiet()
    #expect(state.step == .preset)
    #expect(!state.isDone(.preset))
    state.quiet()
    #expect(state.step == .tryIt)
    state.quiet()
    #expect(state.step == .accessibility)
    #expect(state.quietTitle == "Skip for now")
  }

  @Test func continueWaitsForARecognizedRightEdgeSlideFromTheFeed() async {
    let model = OnboardingFixtures.model()
    let state = OnboardingState(model: model)
    state.start()
    state.quiet()
    #expect(!state.canContinue)
    state.primary()
    #expect(state.step == .tryIt)

    model.simulate(
      OnboardingFixtures.decisions([
        .recognized(zone: .edge(.left), kind: .slide, phase: .began, deviceID: 1),
        .recognized(zone: .edge(.right), kind: .swipe(.up), phase: .ended, deviceID: 1),
        .rejected(contactID: 3, zone: .edge(.right), reason: .palm, deviceID: 1),
      ]))
    await OnboardingFixtures.settle()
    #expect(!state.canContinue)

    model.simulate(OnboardingFixtures.decisions([OnboardingFixtures.rightSlide]))
    await OnboardingFixtures.settle()
    #expect(state.slideRecognized)
    #expect(state.canContinue)
    // Read, not taken: the overlay's channel is untouched.
    #expect(model.pendingDecisions.count == 4)

    state.primary()
    #expect(state.step == .preset)
  }

  @Test func theGateCountsSlidesOnTheRightEdgeOnly() {
    #expect(OnboardingState.isTaughtSlide(OnboardingFixtures.rightSlide))
    #expect(
      OnboardingState.isTaughtSlide(
        .recognized(zone: .edge(.right, segment: 1, segments: 2), kind: .slide, phase: .ended, deviceID: 1)))
    #expect(OnboardingState.isTaughtSlide(.actionRan("audio.volume", zone: .edge(.right), kind: .slide)))
    #expect(OnboardingState.isTaughtSlide(.wouldRun("audio.volume", zone: .edge(.right), kind: .slide)))
    #expect(!OnboardingState.isTaughtSlide(.recognized(zone: .edge(.left), kind: .slide, phase: .began, deviceID: 1)))
    #expect(!OnboardingState.isTaughtSlide(.recognized(zone: .edge(.right), kind: .tap, phase: .ended, deviceID: 1)))
    #expect(
      !OnboardingState.isTaughtSlide(.recognized(zone: .corner(.topRight), kind: .tap, phase: .ended, deviceID: 1)))
  }

  @Test func theGateStaysOpenAfterGoingBack() {
    let state = OnboardingFixtures.state(at: .tryIt, model: OnboardingFixtures.model())
    state.receive([OnboardingFixtures.rightSlide])
    state.quiet()
    state.quiet()
    #expect(state.step == .tryIt)
    #expect(state.canContinue)
  }

  @Test func withoutATrackpadTryItDoesNotTrapTheUser() {
    let model = OnboardingFixtures.model()
    let state = OnboardingFixtures.state(at: .tryIt, model: model)
    #expect(!state.canContinue)
    model.simulate(EngineStatus(running: true, devices: []))
    #expect(model.mirroredDevice == nil)
    #expect(state.canContinue)
  }

  @Test func choosingAPresetAppliesItAndTheStepIsOneUndoStep() throws {
    let model = OnboardingFixtures.model()
    let editor = model.editor
    let start = editor.config
    #expect(!editor.canUndo)
    let state = OnboardingFixtures.state(at: .preset, model: model)
    #expect(state.preset == .media)

    state.choose(.windows)
    #expect(editor.config.defaultProfile == Presets.windows.defaultProfile)
    state.choose(.minimal)
    state.choose(.windows)
    #expect(editor.config.defaultProfile == Presets.windows.defaultProfile)
    state.primary()
    #expect(state.step == .launchAtLogin)
    #expect(!editor.isEditingContinuously)
    #expect(editor.config.defaultProfile == Presets.windows.defaultProfile)

    #expect(try editor.undo())
    #expect(editor.config == start)
    #expect(!editor.canUndo)
  }

  @Test func continueAppliesThePreselectedMedia() throws {
    let model = OnboardingFixtures.model(config: Presets.minimal)
    let state = OnboardingFixtures.state(at: .preset, model: model)
    state.primary()
    #expect(model.editor.config.defaultProfile == Presets.media.defaultProfile)
    #expect(try model.editor.undo())
    #expect(model.editor.config.defaultProfile == Presets.minimal.defaultProfile)
  }

  @Test func thePresetIsAdjustedToThisMac() {
    let catalog = makeLiveActionRegistry(settings: .defaults).available
    let fake = FakeActions(
      catalog: catalog, availability: ["display.brightness": .unavailable(reason: "No display that takes it")])
    let editor = SettingsEditor(
      config: .defaults, catalog: catalog, store: MemoryStore(.defaults), scheduler: ImmediateScheduler(),
      actions: fake, apply: { _ in })
    let model = SettingsModel(editor: editor, engine: nil, devices: [PreviewFixtures.externalPad])
    let state = OnboardingFixtures.state(at: .preset, model: model)
    state.choose(.minimal)
    let left = editor.config.defaultProfile.bindings.first { $0.zone == .edge(.left) }
    #expect(left?.action == "apps.switcher")
    #expect(!editor.config.defaultProfile.bindings.contains { $0.action == "display.brightness" })
  }

  @Test func doneWritesLaunchAtLoginOnByDefault() {
    let model = OnboardingFixtures.model()
    #expect(!model.editor.config.app.launchAtLogin)
    let state = OnboardingFixtures.state(at: .launchAtLogin, model: model)
    #expect(state.launchAtLogin)
    #expect(!model.editor.config.app.launchAtLogin)
    state.primary()
    #expect(model.editor.config.app.launchAtLogin)
  }

  @Test func doneWritesLaunchAtLoginOffWhenSwitchedOff() {
    var config = EdgyConfig.defaults
    config.app.launchAtLogin = true
    let model = OnboardingFixtures.model(config: config)
    let state = OnboardingFixtures.state(at: .launchAtLogin, model: model)
    state.launchAtLogin = false
    state.primary()
    #expect(!model.editor.config.app.launchAtLogin)
  }

  @Test func finishIsCalledOnceAndClosesFirst() {
    let calls = OnboardingCalls()
    let controller = OnboardingController(model: OnboardingFixtures.model(), actions: calls.actions)
    var order: [String] = []
    let finish = controller.state.actions.finish
    controller.state.actions.finish = {
      order.append("finish")
      finish()
    }
    let closing = controller.state.beforeFinish
    controller.state.beforeFinish = {
      order.append("close")
      closing?()
    }
    let state = controller.state
    state.quiet()
    state.receive([OnboardingFixtures.rightSlide])
    state.primary()
    state.primary()
    state.primary()
    state.primary()
    state.primary()
    #expect(state.isFinished)
    #expect(calls.finish == 1)
    #expect(order == ["close", "finish"])
  }

  @Test func closingEarlyDoesNotFinishAndEndsThePresetEdit() {
    let calls = OnboardingCalls()
    let model = OnboardingFixtures.model()
    let controller = OnboardingController(model: model, actions: calls.actions)
    let state = controller.state
    state.quiet()
    state.receive([OnboardingFixtures.rightSlide])
    state.primary()
    state.choose(.minimal)
    #expect(model.editor.isEditingContinuously)
    controller.windowWillClose(Notification(name: NSWindow.willCloseNotification))
    #expect(!model.editor.isEditingContinuously)
    #expect(calls.finish == 0)
    #expect(!state.isFinished)
    #expect(model.editor.config.defaultProfile == Presets.minimal.defaultProfile)
  }
}
