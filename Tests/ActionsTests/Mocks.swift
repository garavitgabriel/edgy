import CoreGraphics
import Displays
import EdgyCore
import Foundation

@testable import Actions

final class MockAudioOutput: AudioOutput {
  var volume = 0.5
  var muted = false
  var inputMuted = false
  var headphones = false
  var failure: OutputError?
  private(set) var setVolumeCalls: [Double] = []
  private(set) var setMutedCalls: [Bool] = []
  private(set) var setInputMutedCalls: [Bool] = []

  func outputVolume() throws -> Double {
    if let failure { throw failure }
    return volume
  }
  func setOutputVolume(_ level: Double) throws {
    if let failure { throw failure }
    setVolumeCalls.append(level)
    volume = level
  }
  func isOutputMuted() throws -> Bool { muted }
  func setOutputMuted(_ muted: Bool) throws {
    setMutedCalls.append(muted)
    self.muted = muted
  }
  func isInputMuted() throws -> Bool { inputMuted }
  func setInputMuted(_ muted: Bool) throws {
    if let failure { throw failure }
    setInputMutedCalls.append(muted)
    inputMuted = muted
  }
  func outputIsHeadphones() -> Bool { headphones }
}

final class MockBrightnessOutput: BrightnessOutput {
  var isAvailable = true
  var level = 0.5
  private(set) var setCalls: [Double] = []

  func brightness() throws -> Double { level }
  func setBrightness(_ level: Double) throws {
    setCalls.append(level)
    self.level = level
  }
}

final class MockMediaKeyOutput: MediaKeyOutput {
  enum Key: Equatable { case playPause, next, previous }
  private(set) var keys: [Key] = []
  func playPause() { keys.append(.playPause) }
  func next() { keys.append(.next) }
  func previous() { keys.append(.previous) }
}

final class MockHUDOutput: HUDOutput {
  struct Shown: Equatable {
    var kind: HUDKind
    var level: Double
  }
  private(set) var shown: [Shown] = []
  func show(_ kind: HUDKind, level: Double) { shown.append(Shown(kind: kind, level: level)) }
}

final class MockHapticOutput: HapticOutput {
  private(set) var ticks = 0
  private(set) var strongTicks = 0
  private(set) var strengths: [Int] = []
  func tick(strength: Int) {
    ticks += 1
    strengths.append(strength)
  }
  func strongTick(strength: Int) {
    strongTicks += 1
    strengths.append(strength)
  }
}

final class MockShortcutRunner: ShortcutRunner {
  private(set) var ran: [String] = []
  func run(name: String) { ran.append(name) }
}

final class MockKeyboardOutput: KeyboardOutput {
  private(set) var posted: [String] = []
  var failure: OutputError?
  /// Low-level events from `setModifiers` / `key`, e.g. `"cmd down"`, `"cmd+tab down"`, `"cmd up"`.
  private(set) var events: [String] = []
  /// Modifier keys currently down, and the other keys currently down.
  private(set) var heldModifiers = Set<KeyCombo.Modifier>()
  private(set) var heldKeys = Set<String>()
  /// Throws on the first low-level event equal to this (e.g. `"cmd+shift+tab down"`), once.
  var failOnEvent: String?

  func post(_ combo: KeyCombo) throws {
    if let failure { throw failure }
    posted.append(combo.description)
  }
  func setModifiers(_ modifiers: [KeyCombo.Modifier], down: Bool) throws {
    for modifier in modifiers {
      let event = modifier.rawValue + (down ? " down" : " up")
      try check(event)
      events.append(event)
      if down { heldModifiers.insert(modifier) } else { heldModifiers.remove(modifier) }
    }
  }
  func key(_ key: String, down: Bool, modifiers: Set<KeyCombo.Modifier>) throws {
    let event = KeyCombo(modifiers: modifiers, key: key).description + (down ? " down" : " up")
    try check(event)
    events.append(event)
    if down { heldKeys.insert(key) } else { heldKeys.remove(key) }
  }
  /// Nothing left down.
  var allReleased: Bool { heldModifiers.isEmpty && heldKeys.isEmpty }

  private func check(_ event: String) throws {
    if let failure { throw failure }
    if event == failOnEvent {
      failOnEvent = nil
      throw OutputError("key event failed")
    }
  }
}

final class MockLevelKeyOutput: LevelKeyOutput {
  struct Press: Equatable {
    var key: LevelKey
    var count: Int
    var fine: Bool
  }
  /// Whether posting works. The default harness models a Mac where it doesn't (see `Harness`).
  var works = false
  private(set) var presses: [Press] = []
  /// Fine steps pressed, signed (+ up, - down), over all volume / brightness presses.
  var netFineSteps: Int {
    presses.reduce(0) {
      switch $1.key {
      case .volumeUp, .brightnessUp: return $0 + $1.count
      case .volumeDown, .brightnessDown: return $0 - $1.count
      case .mute: return $0
      }
    }
  }
  func press(_ key: LevelKey, count: Int, fine: Bool) throws {
    guard works else { throw OutputError("cannot post level keys") }
    presses.append(Press(key: key, count: count, fine: fine))
  }
}

final class MockDisplayBrightness: DisplayBrightnessControlling, @unchecked Sendable {
  var list: [DisplayInfo] = []
  var active: UInt32?
  var levels: [UInt32: Double] = [:]
  var failure: DisplayBrightnessError?
  private(set) var setCalls: [Double] = []
  private(set) var setTargets: [UInt32] = []

  func displays() -> [DisplayInfo] { list }
  func activeDisplayID() -> UInt32? { active }
  func brightness(of id: UInt32) throws -> Double {
    if let failure { throw failure }
    guard let level = levels[id] else { throw DisplayBrightnessError.noSuchDisplay(id) }
    return level
  }
  func setBrightness(_ level: Double, of id: UInt32) throws {
    if let failure { throw failure }
    setCalls.append(level)
    setTargets.append(id)
    levels[id] = level
  }
}

final class MockKeyboardBacklightOutput: KeyboardBacklightOutput {
  var isAvailable = true
  var current = 0.5
  private(set) var setCalls: [Double] = []
  func level() throws -> Double { current }
  func setLevel(_ level: Double) throws {
    setCalls.append(level)
    current = level
  }
}

final class MockDictationOutput: DictationOutput {
  private(set) var toggles = 0
  var failure: OutputError?
  func toggle() throws {
    if let failure { throw failure }
    toggles += 1
  }
}

/// Captures each wait; the test decides when (and whether) the condition held.
final class MockTransitionWaiter: TransitionWaiter, @unchecked Sendable {
  struct Pending {
    var timeout: TimeInterval
    var condition: @Sendable () -> Bool
    var done: @Sendable (Bool) -> Void
  }
  private(set) var pending: [Pending] = []
  private(set) var waits = 0

  func wait(
    timeout: TimeInterval, interval: TimeInterval, until condition: @escaping @Sendable () -> Bool,
    then done: @escaping @Sendable (Bool) -> Void
  ) {
    waits += 1
    pending.append(Pending(timeout: timeout, condition: condition, done: done))
  }

  /// Polls the oldest wait once: completes it with `true` if its condition holds now.
  @discardableResult
  func poll() -> Bool {
    guard let first = pending.first, first.condition() else { return false }
    pending.removeFirst()
    first.done(true)
    return true
  }

  /// The oldest wait runs out of time.
  func timeOut() {
    guard !pending.isEmpty else { return }
    pending.removeFirst().done(false)
  }
}

final class MockWorkspaceOutput: WorkspaceOutput {
  enum Call: Equatable {
    case activate(String)
    case hide(String)
    case openURL(URL)
    case openFile(URL)
  }
  var frontmost: String?
  var installed: Set<String> = []
  var existingFiles: Set<String> = []
  private(set) var calls: [Call] = []

  func isFrontmost(bundleID: String) -> Bool { frontmost == bundleID }
  func activate(bundleID: String) throws {
    guard installed.contains(bundleID) else { throw OutputError("no app installed with bundle ID \(bundleID)") }
    calls.append(.activate(bundleID))
  }
  func hide(bundleID: String) { calls.append(.hide(bundleID)) }
  func open(url: URL) throws { calls.append(.openURL(url)) }
  func open(file: URL) throws {
    guard existingFiles.contains(file.path) else { throw OutputError("nothing at \(file.path)") }
    calls.append(.openFile(file))
  }
}

final class MockWindowOutput: WindowOutput {
  /// The focused window; `nil` → no window.
  var window: WindowSnapshot? = WindowSnapshot(
    id: WindowID(pid: 42, token: 1), frame: CGRect(x: 100, y: 100, width: 800, height: 600),
    visibleFrame: CGRect(x: 0, y: 25, width: 1440, height: 875))
  private(set) var setFrames: [CGRect] = []
  private(set) var minimized: [WindowID] = []
  /// Every call that changes something, in order: `"exitFullScreen"`, `"setFrame"`, `"minimize"`.
  private(set) var log: [String] = []
  /// Leaving full screen gives the window this frame, on the desktop Space with its menu bar.
  var frameAfterFullScreen = CGRect(x: 200, y: 150, width: 900, height: 700)
  var visibleAfterFullScreen = CGRect(x: 0, y: 25, width: 1440, height: 875)

  /// Puts the focused window in full screen: the whole screen, no menu bar.
  func enterFullScreen() {
    window?.isFullScreen = true
    window?.frame = CGRect(x: 0, y: 0, width: 1440, height: 900)
    window?.visibleFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
  }

  /// The system finishes the exit animation.
  func finishLeavingFullScreen() {
    window?.isFullScreen = false
    window?.frame = frameAfterFullScreen
    window?.visibleFrame = visibleAfterFullScreen
  }

  func focusedWindow() throws -> WindowSnapshot {
    guard let window else { throw OutputError("the frontmost app has no focused window") }
    return window
  }
  func snapshot(of id: WindowID) throws -> WindowSnapshot {
    guard let window, window.id == id else { throw OutputError("the window is gone") }
    return window
  }
  func exitFullScreen(_ id: WindowID) throws {
    log.append("exitFullScreen")
  }
  func setFrame(_ frame: CGRect, of window: WindowID) throws {
    log.append("setFrame")
    setFrames.append(frame)
    if self.window?.id == window { self.window?.frame = frame }
  }
  func minimize(_ window: WindowID) throws {
    log.append("minimize")
    minimized.append(window)
  }
}

final class MockSystemOutput: SystemOutput {
  private(set) var commands: [SystemCommand] = []
  func perform(_ command: SystemCommand) throws { commands.append(command) }
}

/// A registry wired entirely to recording mocks.
///
/// By default level keys can't be posted (`levelKeys.works == false`), so volume, brightness and
/// mute take the fallback path (CoreAudio / the built-in output plus the legacy HUD), which is
/// exactly the v0.1/v0.2 behaviour those tests pin. Tests of the native key path pass
/// `levelKeys: true`.
struct Harness {
  let audio = MockAudioOutput()
  let display = MockBrightnessOutput()
  let media = MockMediaKeyOutput()
  let hud = MockHUDOutput()
  let haptics = MockHapticOutput()
  let shortcuts = MockShortcutRunner()
  let keyboard = MockKeyboardOutput()
  let workspace = MockWorkspaceOutput()
  let windows = MockWindowOutput()
  let system = MockSystemOutput()
  let levelKeys = MockLevelKeyOutput()
  let displays = MockDisplayBrightness()
  let backlight = MockKeyboardBacklightOutput()
  let dictation = MockDictationOutput()
  let waiter = MockTransitionWaiter()
  let registry: ActionRegistry

  init(settings: AppSettings = .defaults, levelKeys working: Bool = false) {
    levelKeys.works = working
    registry = ActionRegistry(
      settings: settings, audio: audio, display: display, media: media, hud: hud, haptics: haptics,
      shortcuts: shortcuts, keyboard: keyboard, workspace: workspace, windows: windows, system: system,
      levelKeys: levelKeys, displays: displays, backlight: backlight, dictation: dictation, waiter: waiter)
  }

  func press(_ id: ActionID, down: Bool, _ parameters: [String: String] = [:]) throws {
    try registry.perform(
      id, input: .press(down: down), context: ActionContext(frontmostBundleID: nil, parameters: parameters))
  }

  func trigger(_ id: ActionID, _ parameters: [String: String] = [:]) throws {
    try registry.perform(
      id, input: .trigger, context: ActionContext(frontmostBundleID: nil, parameters: parameters))
  }

  func slide(
    _ id: ActionID, _ delta: Double, phase: GestureEvent.Phase = .changed, _ parameters: [String: String] = [:]
  ) throws {
    try registry.perform(
      id, input: .delta(delta, phase: phase),
      context: ActionContext(frontmostBundleID: nil, parameters: parameters))
  }
}

extension AppSettings {
  static func with(hud: HUDMode = .native, haptics: Bool = true) -> AppSettings {
    var settings = AppSettings.defaults
    settings.hud = hud
    settings.haptics = haptics
    return settings
  }
}
