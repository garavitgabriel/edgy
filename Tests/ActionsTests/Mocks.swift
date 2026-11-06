import CoreGraphics
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
  func post(_ combo: KeyCombo) throws {
    if let failure { throw failure }
    posted.append(combo.description)
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

  func focusedWindow() throws -> WindowSnapshot {
    guard let window else { throw OutputError("the frontmost app has no focused window") }
    return window
  }
  func setFrame(_ frame: CGRect, of window: WindowID) throws {
    setFrames.append(frame)
    if self.window?.id == window { self.window?.frame = frame }
  }
  func minimize(_ window: WindowID) throws { minimized.append(window) }
}

final class MockSystemOutput: SystemOutput {
  private(set) var commands: [SystemCommand] = []
  func perform(_ command: SystemCommand) throws { commands.append(command) }
}

/// A registry wired entirely to recording mocks.
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
  let registry: ActionRegistry

  init(settings: AppSettings = .defaults) {
    registry = ActionRegistry(
      settings: settings, audio: audio, display: display, media: media, hud: hud, haptics: haptics,
      shortcuts: shortcuts, keyboard: keyboard, workspace: workspace, windows: windows, system: system)
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
