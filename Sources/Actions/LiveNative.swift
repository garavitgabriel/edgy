import AppKit
import CoreGraphics
import EdgyCore
import Foundation
import IOKit.hidsystem
import ObjectiveC

// MARK: - Level keys

/// The keyboard's volume, brightness and mute keys, posted as system-defined events exactly as
/// the hardware keys arrive. macOS then changes the level itself and shows its current HUD,
/// including the variants for wireless earbuds and other devices.
///
/// Fine steps: holding shift and option with a volume or brightness key moves the level a
/// quarter step (1/64 of the range instead of 1/16). That is long-standing macOS behaviour;
/// `scripts/smoke-actions.sh` measures it on the running macOS (step "level keys") because tests
/// can't. Posting needs the post-event (Accessibility) permission; without it, or if an event
/// can't be built, `press` throws before posting anything and the registry falls back.
final class LiveLevelKeyOutput: LevelKeyOutput {
  /// Aux-control key states in the system-defined event.
  private static let keyDown = 0xA
  private static let keyUp = 0xB
  /// Subtype of system-defined events carrying aux-control (media and level) keys.
  private static let auxControlSubtype: Int16 = 8

  static func code(_ key: LevelKey) -> Int32 {
    switch key {
    case .volumeUp: return NX_KEYTYPE_SOUND_UP
    case .volumeDown: return NX_KEYTYPE_SOUND_DOWN
    case .mute: return NX_KEYTYPE_MUTE
    case .brightnessUp: return NX_KEYTYPE_BRIGHTNESS_UP
    case .brightnessDown: return NX_KEYTYPE_BRIGHTNESS_DOWN
    }
  }

  func press(_ key: LevelKey, count: Int, fine: Bool) throws {
    guard count > 0 else { return }
    guard CGPreflightPostEventAccess() else {
      throw OutputError("Edgy may not post key events (Accessibility permission not granted)")
    }
    let modifiers: NSEvent.ModifierFlags = fine ? [.shift, .option] : []
    var events: [CGEvent] = []
    for _ in 0..<count {
      for state in [Self.keyDown, Self.keyUp] {
        guard
          let event = NSEvent.otherEvent(
            with: .systemDefined, location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(state << 8)).union(modifiers), timestamp: 0,
            windowNumber: 0, context: nil, subtype: Self.auxControlSubtype,
            data1: Int(Self.code(key)) << 16 | state << 8, data2: -1),
          let cgEvent = event.cgEvent
        else { throw OutputError("cannot create a \(key.rawValue) key event") }
        events.append(cgEvent)
      }
    }
    for event in events { event.post(tap: .cghidEventTap) }
  }
}

// MARK: - Keyboard backlight

/// The built-in keyboard's backlight through the private CoreBrightness framework, loaded by
/// name at runtime. Its `KeyboardBrightnessClient` class lists backlit keyboards
/// (`copyKeyboardBacklightIDs`) and reads / sets each one's level (`brightnessForKeyboard:`,
/// `setBrightness:forKeyboard:`). Any lookup failure leaves the output unavailable with one log
/// line. Selectors checked against macOS 27 (2026-11-06).
final class LiveKeyboardBacklightOutput: KeyboardBacklightOutput {
  private typealias CopyIDs = @convention(c) (AnyObject, Selector) -> Unmanaged<NSArray>?
  private typealias Get = @convention(c) (AnyObject, Selector, UInt64) -> Float
  private typealias SetLevel = @convention(c) (AnyObject, Selector, Float, UInt64) -> Bool
  private typealias IsBuiltIn = @convention(c) (AnyObject, Selector, UInt64) -> Bool

  private struct Client {
    var object: AnyObject
    var get: Get
    var set: SetLevel
    /// The built-in backlit keyboard (or the first backlit one).
    var keyboard: UInt64
  }

  private lazy var client: Client? = Self.load()

  var isAvailable: Bool { client != nil }

  func level() throws -> Double {
    let client = try resolve()
    return Double(client.get(client.object, Self.getSelector, client.keyboard))
  }

  func setLevel(_ level: Double) throws {
    let client = try resolve()
    guard client.set(client.object, Self.setSelector, Float(min(max(level, 0), 1)), client.keyboard) else {
      throw OutputError("the keyboard backlight refused the new level")
    }
  }

  private func resolve() throws -> Client {
    guard let client else { throw OutputError(ActionRegistry.noBacklightReason) }
    return client
  }

  private static let getSelector = NSSelectorFromString("brightnessForKeyboard:")
  private static let setSelector = NSSelectorFromString("setBrightness:forKeyboard:")

  private static func load() -> Client? {
    let path = "/System/Library/PrivateFrameworks/CoreBrightness.framework"
    guard let bundle = Bundle(path: path), bundle.load() else {
      actionsLog.notice("keyboard backlight unavailable: cannot load \(path, privacy: .public)")
      return nil
    }
    let idsSelector = NSSelectorFromString("copyKeyboardBacklightIDs")
    let builtInSelector = NSSelectorFromString("isKeyboardBuiltIn:")
    guard let cls = NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type,
      [idsSelector, getSelector, setSelector, builtInSelector].allSatisfy({ cls.instancesRespond(to: $0) })
    else {
      actionsLog.notice("keyboard backlight unavailable: brightness client not found")
      return nil
    }
    let object = cls.init()
    func imp<T>(_ selector: Selector, as: T.Type) -> T {
      unsafeBitCast(class_getMethodImplementation(cls, selector), to: T.self)
    }
    let ids = imp(idsSelector, as: CopyIDs.self)(object, idsSelector)?.takeRetainedValue() as? [NSNumber] ?? []
    let isBuiltIn = imp(builtInSelector, as: IsBuiltIn.self)
    let keyboards = ids.map(\.uint64Value)
    guard let keyboard = keyboards.first(where: { isBuiltIn(object, builtInSelector, $0) }) ?? keyboards.first else {
      actionsLog.notice("keyboard backlight unavailable: no backlit keyboard")
      return nil
    }
    return Client(
      object: object, get: imp(getSelector, as: Get.self), set: imp(setSelector, as: SetLevel.self), keyboard: keyboard)
  }
}

// MARK: - Dictation

/// Starts / stops macOS Dictation by pressing the keyboard's dictation (microphone) key: a key
/// event with the code current Apple keyboards report for it. The system treats it like the real
/// key, so this depends on:
///
/// - Dictation turned on (System Settings → Keyboard → Dictation), and
/// - its shortcut including the microphone key (the default on current macOS), and
/// - the post-event (Accessibility) permission.
///
/// There is no public API to start system Dictation from another app, and no system-defined
/// event type for it (unlike volume or brightness). Verified by hand only
/// (`scripts/smoke-actions.sh`, step "dictation").
final class LiveDictationOutput: DictationOutput {
  /// Virtual key code of the dictation key on current Apple keyboards.
  static let dictationKeyCode: CGKeyCode = 0xB0

  func toggle() throws {
    guard CGPreflightPostEventAccess() else {
      throw OutputError("Edgy may not post key events (Accessibility permission not granted)")
    }
    guard let source = CGEventSource(stateID: .hidSystemState),
      let down = CGEvent(keyboardEventSource: source, virtualKey: Self.dictationKeyCode, keyDown: true),
      let up = CGEvent(keyboardEventSource: source, virtualKey: Self.dictationKeyCode, keyDown: false)
    else { throw OutputError("cannot create the dictation key event") }
    down.post(tap: .cghidEventTap)
    up.post(tap: .cghidEventTap)
  }
}

// MARK: - Waiting

/// Polls on a private serial queue. Waits for the condition to hold on two polls in a row, so a
/// window caught mid-animation isn't acted on early.
final class LiveTransitionWaiter: TransitionWaiter {
  private let queue = DispatchQueue(label: "com.garavit.edgy.actions.transition")
  static let requiredConsecutive = 2

  func wait(
    timeout: TimeInterval, interval: TimeInterval, until condition: @escaping @Sendable () -> Bool,
    then done: @escaping @Sendable (Bool) -> Void
  ) {
    let deadline = DispatchTime.now() + timeout
    let queue = self.queue
    @Sendable func poll(_ streak: Int) {
      let streak = condition() ? streak + 1 : 0
      if streak >= Self.requiredConsecutive { return done(true) }
      if DispatchTime.now() >= deadline { return done(false) }
      queue.asyncAfter(deadline: .now() + interval) { poll(streak) }
    }
    queue.async { poll(0) }
  }
}
