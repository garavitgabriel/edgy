import EdgyCore

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
  func tick() { ticks += 1 }
  func strongTick() { strongTicks += 1 }
}

final class MockShortcutRunner: ShortcutRunner {
  private(set) var ran: [String] = []
  func run(name: String) { ran.append(name) }
}

/// A registry wired entirely to recording mocks.
struct Harness {
  let audio = MockAudioOutput()
  let display = MockBrightnessOutput()
  let media = MockMediaKeyOutput()
  let hud = MockHUDOutput()
  let haptics = MockHapticOutput()
  let shortcuts = MockShortcutRunner()
  let registry: ActionRegistry

  init(settings: AppSettings = .defaults) {
    registry = ActionRegistry(
      settings: settings, audio: audio, display: display, media: media, hud: hud, haptics: haptics,
      shortcuts: shortcuts)
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
