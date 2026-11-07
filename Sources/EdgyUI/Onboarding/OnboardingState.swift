import EdgyCore
import EdgyRuntime
import Foundation
import Observation

/// What onboarding's buttons do outside the window. The app supplies the live versions; the
/// default does nothing, so previews and tests never touch the system.
public struct OnboardingActions: Sendable {
  public typealias Command = @MainActor @Sendable () -> Void

  /// Opens the system privacy pane (step 1's **Open Settings**).
  public var openAccessibilitySettings: Command
  /// Onboarding is done (**Done** on step 4). The window has already closed; the app marks
  /// onboarding done and opens the menu-bar popover once. Called at most once.
  public var finish: Command

  public init(openAccessibilitySettings: @escaping Command = {}, finish: @escaping Command = {}) {
    self.openAccessibilitySettings = openAccessibilitySettings
    self.finish = finish
  }

  public static let none = OnboardingActions()
}

/// The onboarding flow (BRIEF § Onboarding): which step shows, the live Accessibility state, the
/// "Try it" gate, the chosen preset and the launch-at-login choice. `OnboardingView` draws it;
/// `OnboardingController` hosts it and feeds it the permission.
///
/// - **Step 1** watches the permission (`setAccessibility`, fed by a `PermissionMonitor`). Granted
///   flips the body to "Access granted." and the primary to Continue; **Skip for now** continues
///   without it.
/// - **Step 2** reads `model.recentDecisions` without taking them (the overlay owns
///   `takeDecisions()`); Continue enables once a slide is recognized on the right edge, and stays
///   enabled.
/// - **Step 3** applies the chosen preset at once through `SettingsEditor.applyPreset` (which runs
///   it through `MachineDefaults`). Every choice made while the step is open is one continuous
///   edit, so the whole step is **one undo step**, however often the user changes their mind.
/// - **Step 4** writes `launchAtLogin` on **Done** (on by default here), then finishes once.
@MainActor
@Observable
public final class OnboardingState {
  public enum Step: Int, CaseIterable, Comparable, Sendable {
    case accessibility = 1
    case tryIt, preset, launchAtLogin

    public static func < (lhs: Step, rhs: Step) -> Bool { lhs.rawValue < rhs.rawValue }

    /// The step row's label.
    public var title: String {
      switch self {
      case .accessibility: return OnboardingCopy.stepAccessibility
      case .tryIt: return OnboardingCopy.stepTryIt
      case .preset: return OnboardingCopy.stepPreset
      case .launchAtLogin: return OnboardingCopy.stepLaunch
      }
    }
  }

  /// The continuous-edit key that groups step 3's choices into one undo step.
  static let presetEditKey = "onboarding.preset"

  public let model: SettingsModel
  public private(set) var step: Step = .accessibility
  /// The live Accessibility permission (`.unknown` until a checker reports).
  public private(set) var accessibility: PermissionState = .unknown
  /// A slide was recognized on the right edge since onboarding opened (step 2's gate).
  public private(set) var slideRecognized = false
  /// Step 3's radio choice. Media is preselected (`EdgyConfig.defaults`).
  public private(set) var preset: Presets.Preset = .media
  /// Step 4's switch: on in onboarding (an explicit choice; the runtime default stays off).
  public var launchAtLogin = true
  /// Done was pressed; `finish` has run.
  public private(set) var isFinished = false
  /// The last editor refusal (a broken config file is read-only), for diagnostics.
  public private(set) var lastError: String?

  @ObservationIgnored var actions: OnboardingActions
  /// Runs before `actions.finish` (the controller closes the window).
  @ObservationIgnored var beforeFinish: (@MainActor () -> Void)?
  @ObservationIgnored private var watching = false
  @ObservationIgnored private let logger: EdgyLogging = SystemLogger(category: "onboarding")

  public init(model: SettingsModel, actions: OnboardingActions = .none) {
    self.model = model
    self.actions = actions
  }

  // MARK: Derived

  public var isAccessibilityGranted: Bool { accessibility == .granted }

  /// A step is done once passed. Step 1 counts only when access is granted (skipping isn't done),
  /// and shows its check mark the moment access is granted, even while it is the current step.
  public func isDone(_ step: Step) -> Bool {
    if step == .accessibility { return isAccessibilityGranted }
    return step < self.step
  }

  /// Step 2 has something to try: the Default profile slides on the right edge.
  public var hasTaughtSlide: Bool {
    _ = model.revision
    return model.editor.effectiveBindings(forApp: nil).contains {
      $0.binding.gesture == .slide && Self.isRightEdge($0.binding.zone)
    }
  }

  /// Whether the primary button works on the current step.
  public var canContinue: Bool {
    switch step {
    case .tryIt:
      // Nothing to try without a trackpad or a right-edge slide: don't trap the user.
      return slideRecognized || model.mirroredDevice == nil || !hasTaughtSlide
    case .accessibility, .preset, .launchAtLogin:
      return true
    }
  }

  /// The round primary's title.
  public var primaryTitle: String {
    switch step {
    case .accessibility: return isAccessibilityGranted ? OnboardingCopy.continueTitle : OnboardingCopy.openSettings
    case .tryIt, .preset: return OnboardingCopy.continueTitle
    case .launchAtLogin: return OnboardingCopy.done
    }
  }

  /// The quiet text button on the left: Skip for now (step 1, not granted), Back (steps 2–4).
  public var quietTitle: String? {
    switch step {
    case .accessibility: return isAccessibilityGranted ? nil : OnboardingCopy.skip
    case .tryIt, .preset, .launchAtLogin: return OnboardingCopy.back
    }
  }

  // MARK: Commands

  /// Starts reading the feed (idempotent). The view calls it on appear; the controller on show.
  public func start() {
    model.startFeed()
    guard !watching else { return }
    watching = true
    receive(model.recentDecisions)
    watchDecisions()
  }

  /// The round primary: Open Settings, Continue or Done.
  public func primary() {
    switch step {
    case .accessibility:
      if isAccessibilityGranted { go(to: .tryIt) } else { actions.openAccessibilitySettings() }
    case .tryIt:
      guard canContinue else { return }
      go(to: .preset)
    case .preset:
      apply(preset)
      go(to: .launchAtLogin)
    case .launchAtLogin:
      finish()
    }
  }

  /// The quiet button: Skip for now on step 1, Back elsewhere.
  public func quiet() {
    switch step {
    case .accessibility: go(to: .tryIt)
    case .tryIt: go(to: .accessibility)
    case .preset: go(to: .tryIt)
    case .launchAtLogin: go(to: .preset)
    }
  }

  /// Step 3: choose a preset and apply it now.
  public func choose(_ preset: Presets.Preset) {
    self.preset = preset
    guard step == .preset else { return }
    apply(preset)
  }

  /// The permission checker's answer (live flip on step 1).
  public func setAccessibility(_ state: PermissionState) {
    accessibility = state
  }

  /// Decisions from the feed; a recognized right-edge slide opens step 2's gate.
  public func receive(_ decisions: [LiveDecision]) {
    guard !slideRecognized else { return }
    if decisions.contains(where: Self.isTaughtSlide) { slideRecognized = true }
  }

  /// The window closed (Done, or the close button): end any open preset edit.
  public func windowClosed() {
    endPresetEdit()
  }

  // MARK: Matching

  static func isRightEdge(_ zone: Zone) -> Bool {
    if case .edge(.right, _, _) = zone { return true }
    return false
  }

  /// A slide on the right edge that the engine recognized (or ran, or would have run).
  static func isTaughtSlide(_ decision: LiveDecision) -> Bool {
    switch decision {
    case .recognized(let zone, .slide, _, _), .actionRan(_, let zone, .slide, _),
      .actionUpdated(_, let zone, .slide, _), .wouldRun(_, let zone, .slide):
      return isRightEdge(zone)
    default:
      return false
    }
  }

  // MARK: Private

  private func go(to next: Step) {
    guard next != step else { return }
    if step == .preset { endPresetEdit() }
    step = next
    if next == .preset { model.editor.beginContinuousEdit(Self.presetEditKey) }
  }

  private func apply(_ preset: Presets.Preset) {
    attempt("apply preset \(preset.rawValue)") { try model.editor.applyPreset(preset) }
  }

  private func endPresetEdit() {
    attempt("end preset edit") { try model.editor.endContinuousEdit() }
  }

  private func finish() {
    guard !isFinished else { return }
    endPresetEdit()
    let wanted = launchAtLogin
    attempt("launch at login") { try model.editor.updateAppSettings { $0.launchAtLogin = wanted } }
    isFinished = true
    beforeFinish?()
    actions.finish()
  }

  private func attempt(_ what: String, _ body: () throws -> Void) {
    do {
      try body()
    } catch {
      lastError = "\(error)"
      logger.log(.error, "Onboarding could not \(what): \(error)")
    }
  }

  /// Re-reads `pendingDecisions` after every change, without taking them.
  private func watchDecisions() {
    withObservationTracking {
      _ = model.recentDecisions
    } onChange: { [weak self] in
      Task { @MainActor in
        guard let self else { return }
        self.receive(self.model.recentDecisions)
        self.watchDecisions()
      }
    }
  }
}

/// Onboarding copy, word for word from BRIEF § Onboarding.
enum OnboardingCopy {
  static let stepAccessibility = "Accessibility"
  static let stepTryIt = "Try it"
  static let stepPreset = "Pick a preset"
  static let stepLaunch = "Launch at login"

  static let accessibilityHeadline = "Let Edgy run your actions"
  static let accessibilityBody =
    "Edgy uses it to keep the pointer still while you slide and to send the keys most actions need."
  static let accessibilityGranted = "Access granted."
  static let openSettings = "Open Settings"
  static let skip = "Skip for now"

  static let tryItHeadline = "Rest a finger on the right edge and slide up"

  static let presetHeadline = "Pick a starting point"
  static let presetNote = "You can change any of it in Settings."

  static let launchHeadline = "Keep Edgy running"
  static let launchSwitch = "Open Edgy when you log in"

  static let continueTitle = "Continue"
  static let back = "Back"
  static let done = "Done"

  static func name(_ preset: Presets.Preset) -> String {
    switch preset {
    case .media: return "Media"
    case .windows: return "Windows"
    case .minimal: return "Minimal"
    }
  }

  static func line(_ preset: Presets.Preset) -> String {
    switch preset {
    case .media: return "Volume, brightness and music on the edges."
    case .windows: return "Volume and brightness, plus window moves on the bottom edge."
    case .minimal: return "Just volume and brightness."
    }
  }
}
