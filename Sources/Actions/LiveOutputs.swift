import AppKit
import CoreGraphics
import Foundation
import IOKit.hidsystem
import os

let actionsLog = Logger(subsystem: "com.garavit.edgy", category: "actions")

// MARK: - Brightness

/// Built-in display backlight through the private DisplayServices framework, resolved by name
/// at runtime on first use. Any lookup failure leaves the output unavailable with one log line.
final class LiveBrightnessOutput: BrightnessOutput {
  private typealias GetFn = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
  private typealias SetFn = @convention(c) (UInt32, Float) -> Int32

  private struct Symbols {
    var get: GetFn
    var set: SetFn
  }

  private lazy var symbols: Symbols? = Self.load()

  var isAvailable: Bool { symbols != nil && Self.builtInDisplay() != nil }

  func brightness() throws -> Double {
    let (symbols, display) = try resolve()
    var value: Float = 0
    let status = symbols.get(display, &value)
    guard status == 0 else { throw OutputError("brightness read failed (\(status))") }
    return Double(value)
  }

  func setBrightness(_ level: Double) throws {
    let (symbols, display) = try resolve()
    let status = symbols.set(display, Float(level))
    guard status == 0 else { throw OutputError("brightness write failed (\(status))") }
  }

  private func resolve() throws -> (Symbols, CGDirectDisplayID) {
    guard let symbols else { throw OutputError("display brightness control not available") }
    guard let display = Self.builtInDisplay() else { throw OutputError("no built-in display") }
    return (symbols, display)
  }

  private static func builtInDisplay() -> CGDirectDisplayID? {
    var count: UInt32 = 0
    guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return nil }
    var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
    guard CGGetOnlineDisplayList(count, &displays, &count) == .success else { return nil }
    return displays.prefix(Int(count)).first { CGDisplayIsBuiltin($0) != 0 }
  }

  private static func load() -> Symbols? {
    let path = "/System/Library/PrivateFrameworks/DisplayServices.framework"
    guard let bundle = CFBundleCreate(kCFAllocatorDefault, URL(fileURLWithPath: path) as CFURL) else {
      actionsLog.error("brightness unavailable: cannot open \(path, privacy: .public)")
      return nil
    }
    guard
      let get = CFBundleGetFunctionPointerForName(bundle, "DisplayServicesGetBrightness" as CFString),
      let set = CFBundleGetFunctionPointerForName(bundle, "DisplayServicesSetBrightness" as CFString)
    else {
      actionsLog.error("brightness unavailable: brightness functions not found")
      return nil
    }
    return Symbols(get: unsafeBitCast(get, to: GetFn.self), set: unsafeBitCast(set, to: SetFn.self))
  }
}

// MARK: - Media keys

/// Posts system-defined media-key events, exactly as the keyboard's media keys do.
/// Needs Accessibility to post events.
final class LiveMediaKeyOutput: MediaKeyOutput {
  func playPause() { Self.press(NX_KEYTYPE_PLAY) }
  func next() { Self.press(NX_KEYTYPE_NEXT) }
  func previous() { Self.press(NX_KEYTYPE_PREVIOUS) }

  private static func press(_ key: Int32) {
    DispatchQueue.main.async {
      for down in [true, false] {
        let state = down ? 0xA : 0xB
        let event = NSEvent.otherEvent(
          with: .systemDefined, location: .zero, modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(state << 8)),
          timestamp: 0, windowNumber: 0, context: nil, subtype: 8, data1: Int(key) << 16 | state << 8, data2: -1)
        event?.cgEvent?.post(tap: .cghidEventTap)
      }
    }
  }
}

// MARK: - HUD

/// The XPC surface of the system's on-screen-display helper.
@objc protocol SystemOSDHelper {
  @objc(showImage:onDisplayID:priority:msecUntilFade:filledChiclets:totalChiclets:locked:)
  func showImage(
    _ image: Int64, onDisplayID displayID: UInt32, priority: UInt32, msecUntilFade: UInt32,
    filledChiclets: UInt32, totalChiclets: UInt32, locked: Bool)
}

/// The native volume / brightness HUD over XPC. Connects on first use; if the helper is missing
/// or rejects the connection, logs once and goes quiet for the rest of the run.
final class LiveHUDOutput: HUDOutput, @unchecked Sendable {
  /// Image identifiers the helper understands. Verified by `scripts/smoke-actions.sh`.
  enum Image: Int64 {
    case brightness = 1
    case volume = 3
    case muted = 4
  }

  private static let chiclets: UInt32 = 16
  private let lock = NSLock()
  private var connection: NSXPCConnection?
  private var failed = false

  func show(_ kind: HUDKind, level: Double) {
    let image: Image
    switch kind {
    case .brightness: image = .brightness
    case .volume(let muted, _): image = muted ? .muted : .volume
    }
    guard let proxy = proxy() else { return }
    let filled = UInt32((min(max(level, 0), 1) * Double(Self.chiclets)).rounded())
    proxy.showImage(
      image.rawValue, onDisplayID: CGMainDisplayID(), priority: 0x1F4, msecUntilFade: 1000,
      filledChiclets: filled, totalChiclets: Self.chiclets, locked: false)
  }

  private func proxy() -> SystemOSDHelper? {
    lock.lock()
    defer { lock.unlock() }
    if failed { return nil }
    if connection == nil {
      let new = NSXPCConnection(machServiceName: "com.apple.OSDUIHelper", options: [])
      new.remoteObjectInterface = NSXPCInterface(with: SystemOSDHelper.self)
      new.invalidationHandler = { [weak self] in self?.fail("connection invalidated") }
      new.resume()
      connection = new
    }
    return connection?.remoteObjectProxyWithErrorHandler { [weak self] error in
      self?.fail(error.localizedDescription)
    } as? SystemOSDHelper
  }

  private func fail(_ reason: String) {
    lock.lock()
    let first = !failed
    failed = true
    let dropped = connection
    connection = nil
    lock.unlock()
    if first {
      actionsLog.error("HUD unavailable: \(reason, privacy: .public)")
      dropped?.invalidate()
    }
  }
}

// MARK: - Haptics

/// Trackpad haptics. Trackpads without Force Touch simply do nothing.
final class LiveHapticOutput: HapticOutput {
  func tick() { Self.perform(.alignment) }
  func strongTick() { Self.perform(.levelChange) }

  private static func perform(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
    DispatchQueue.main.async {
      NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }
  }
}

// MARK: - Shortcuts

/// Runs a Shortcut through the system command-line tool on a background queue.
final class LiveShortcutRunner: ShortcutRunner {
  private static let tool = URL(fileURLWithPath: "/usr/bin/shortcuts")

  func run(name: String) {
    DispatchQueue.global(qos: .userInitiated).async {
      let process = Process()
      process.executableURL = Self.tool
      process.arguments = ["run", name]
      process.standardOutput = FileHandle.nullDevice
      process.standardError = FileHandle.nullDevice
      process.terminationHandler = { process in
        if process.terminationStatus != 0 {
          actionsLog.error(
            "shortcut \(name, privacy: .private) exited with status \(process.terminationStatus)")
        }
      }
      do {
        try process.run()
      } catch {
        actionsLog.error("shortcut \(name, privacy: .private) failed to launch: \(error, privacy: .public)")
      }
    }
  }
}
