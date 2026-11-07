import AppKit
import ApplicationServices
import CoreGraphics
import EdgyCore
import Foundation

// MARK: - Keyboard

/// Posts key combos as hardware-like key events to the HID event tap: each modifier key goes
/// down in turn, then the key, then everything comes back up in reverse. Pressing the modifier
/// keys themselves (not just flagging the key event) is what some system shortcuts need to
/// match. Needs Accessibility.
final class LiveKeyboardOutput: KeyboardOutput {
  func post(_ combo: KeyCombo) throws {
    guard let name = combo.key else {
      throw OutputError("\"\(combo)\" is modifiers only; it can be held but not sent as a shortcut")
    }
    guard let code = KeyCodes.byName[name] else {
      throw OutputError("no key code for \"\(name)\"")
    }
    guard let source = CGEventSource(stateID: .hidSystemState) else {
      throw OutputError("cannot create a keyboard event source")
    }
    let modifiers = KeyCombo.Modifier.allCases.filter(combo.modifiers.contains).compactMap {
      KeyCodes.modifiers[$0]
    }
    var events: [CGEvent] = []
    var held: CGEventFlags = []
    func add(_ code: CGKeyCode, down: Bool, flags: CGEventFlags) throws {
      guard let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) else {
        throw OutputError("cannot create a key event")
      }
      event.flags = flags
      events.append(event)
    }
    for modifier in modifiers {
      held.insert(modifier.flag)
      try add(modifier.code, down: true, flags: held)
    }
    let keyFlags = KeyCodes.flags(for: combo)
    try add(code, down: true, flags: keyFlags)
    try add(code, down: false, flags: keyFlags)
    for modifier in modifiers.reversed() {
      held.remove(modifier.flag)
      try add(modifier.code, down: false, flags: held)
    }
    for event in events { event.post(tap: .cghidEventTap) }
  }

  /// Modifiers currently held down by `setModifiers`; their flags go on every later event.
  /// Behind `lock`: a hold watchdog may release them from the scheduler's queue.
  private var held = Set<KeyCombo.Modifier>()
  private let lock = NSLock()

  /// Each modifier goes out as a flags-changed event with the modifier key's own code and the
  /// whole held state as flags (fn = the secondary-fn flag), which is what the physical key
  /// sends. See `KeyCodes.modifierEvents` for the event route.
  func setModifiers(_ modifiers: [KeyCombo.Modifier], down: Bool) throws {
    let source = try Self.source()
    lock.lock()
    defer { lock.unlock() }
    let plan = KeyCodes.modifierEvents(modifiers, down: down, held: held)
    held = plan.held
    for spec in plan.events {
      guard let event = CGEvent(keyboardEventSource: source, virtualKey: spec.code, keyDown: spec.down) else {
        throw OutputError("cannot create a key event")
      }
      event.type = .flagsChanged
      event.flags = spec.flags
      event.post(tap: .cghidEventTap)
    }
  }

  func key(_ key: String, down: Bool, modifiers: Set<KeyCombo.Modifier>) throws {
    guard let code = KeyCodes.byName[key] else { throw OutputError("no key code for \"\(key)\"") }
    let source = try Self.source()
    guard let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) else {
      throw OutputError("cannot create a key event")
    }
    lock.lock()
    let held = self.held
    lock.unlock()
    event.flags = KeyCodes.heldFlags(modifiers.union(held)).union(KeyCodes.implicitFlags(for: key))
    event.post(tap: .cghidEventTap)
  }

  private static func source() throws -> CGEventSource {
    guard let source = CGEventSource(stateID: .hidSystemState) else {
      throw OutputError("cannot create a keyboard event source")
    }
    return source
  }
}

// MARK: - Workspace

/// Apps, URLs and files through `NSWorkspace` / `NSRunningApplication`. Checks that can fail
/// (app installed, file exists) run on the caller's thread so the error reaches the registry;
/// the launch itself is handed to the system and returns immediately.
final class LiveWorkspaceOutput: WorkspaceOutput {
  func isFrontmost(bundleID: String) -> Bool {
    NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleID
  }

  func activate(bundleID: String) throws {
    if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
      running.unhide()
      running.activate()
      return
    }
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
      throw OutputError("no app installed with bundle ID \(bundleID)")
    }
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true
    NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
      if let error {
        actionsLog.error("open app \(bundleID, privacy: .public) failed: \(error, privacy: .public)")
      }
    }
  }

  func hide(bundleID: String) {
    for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) { app.hide() }
  }

  func open(url: URL) throws {
    guard NSWorkspace.shared.urlForApplication(toOpen: url) != nil else {
      throw OutputError("no app opens \(url.scheme ?? "this kind of") URLs")
    }
    NSWorkspace.shared.open(url, configuration: NSWorkspace.OpenConfiguration()) { _, error in
      if let error { actionsLog.error("open URL failed: \(error, privacy: .public)") }
    }
  }

  func open(file: URL) throws {
    guard FileManager.default.fileExists(atPath: file.path) else {
      throw OutputError("nothing at \(file.path)")
    }
    NSWorkspace.shared.open(file, configuration: NSWorkspace.OpenConfiguration()) { _, error in
      if let error { actionsLog.error("open file failed: \(error, privacy: .public)") }
    }
  }
}

// MARK: - Windows

/// The frontmost app's focused window through the Accessibility API. AX positions are already
/// top-left-origin global coordinates; the screen's visible frame comes from `NSScreen`
/// (bottom-left origin) and is flipped with `WindowGeometry.flip`. Needs Accessibility.
final class LiveWindowOutput: WindowOutput, @unchecked Sendable {
  /// Windows handed out by `focusedWindow`, so later calls act on the same element. Locked: a
  /// full-screen wait reads it from the waiter's queue.
  private var elements: [WindowID: AXUIElement] = [:]
  private let lock = NSLock()

  /// The window's full-screen state. Not in the SDK's constants, but a long-standing standard
  /// window attribute.
  static let fullScreenAttribute = "AXFullScreen"

  func snapshot(of window: WindowID) throws -> WindowSnapshot {
    let element = try element(window)
    let frame = try Self.frame(of: element)
    return WindowSnapshot(
      id: window, frame: frame, visibleFrame: try Self.visibleFrame(containing: frame),
      isFullScreen: Self.isFullScreen(element))
  }

  func exitFullScreen(_ window: WindowID) throws {
    let status = AXUIElementSetAttributeValue(
      try element(window), Self.fullScreenAttribute as CFString, kCFBooleanFalse)
    guard status == .success else {
      throw OutputError("cannot take the window out of full screen (\(status.rawValue))")
    }
  }

  private static func isFullScreen(_ element: AXUIElement) -> Bool {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, fullScreenAttribute as CFString, &value) == .success,
      let flag = value as? Bool
    else { return false }
    return flag
  }

  func focusedWindow() throws -> WindowSnapshot {
    guard AXIsProcessTrusted() else { throw OutputError("Accessibility permission not granted") }
    guard let app = NSWorkspace.shared.frontmostApplication else { throw OutputError("no frontmost app") }
    let appElement = AXUIElementCreateApplication(app.processIdentifier)
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &value) == .success,
      let value, CFGetTypeID(value) == AXUIElementGetTypeID()
    else { throw OutputError("the frontmost app has no focused window") }
    let window = value as! AXUIElement
    let frame = try Self.frame(of: window)
    let id = WindowID(pid: app.processIdentifier, token: Int(bitPattern: UInt(CFHash(window))))
    lock.withLock {
      elements = elements.filter { $0.key.pid == id.pid }
      elements[id] = window
    }
    return WindowSnapshot(
      id: id, frame: frame, visibleFrame: try Self.visibleFrame(containing: frame),
      isFullScreen: Self.isFullScreen(window))
  }

  func setFrame(_ frame: CGRect, of window: WindowID) throws {
    let element = try element(window)
    // Size, position, size: the second size lands correctly when the first was limited by the
    // old position running off the screen edge.
    try Self.set(kAXSizeAttribute, size: frame.size, on: element)
    try Self.set(kAXPositionAttribute, point: frame.origin, on: element)
    try Self.set(kAXSizeAttribute, size: frame.size, on: element)
  }

  func minimize(_ window: WindowID) throws {
    let status = AXUIElementSetAttributeValue(
      try element(window), kAXMinimizedAttribute as CFString, kCFBooleanTrue)
    guard status == .success else { throw OutputError("cannot minimize the window (\(status.rawValue))") }
  }

  private func element(_ window: WindowID) throws -> AXUIElement {
    guard let element = lock.withLock({ elements[window] }) else { throw OutputError("the window is gone") }
    return element
  }

  private static func frame(of window: AXUIElement) throws -> CGRect {
    var position = CGPoint.zero
    var size = CGSize.zero
    var raw: CFTypeRef?
    guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &raw) == .success,
      let raw, CFGetTypeID(raw) == AXValueGetTypeID(),
      AXValueGetValue(raw as! AXValue, .cgPoint, &position)
    else { throw OutputError("cannot read the window position") }
    var rawSize: CFTypeRef?
    guard AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &rawSize) == .success,
      let rawSize, CFGetTypeID(rawSize) == AXValueGetTypeID(),
      AXValueGetValue(rawSize as! AXValue, .cgSize, &size)
    else { throw OutputError("cannot read the window size") }
    return CGRect(origin: position, size: size)
  }

  private static func set(_ attribute: String, point: CGPoint, on element: AXUIElement) throws {
    var point = point
    guard let value = AXValueCreate(.cgPoint, &point),
      AXUIElementSetAttributeValue(element, attribute as CFString, value) == .success
    else { throw OutputError("cannot move the window") }
  }

  private static func set(_ attribute: String, size: CGSize, on element: AXUIElement) throws {
    var size = size
    guard let value = AXValueCreate(.cgSize, &size),
      AXUIElementSetAttributeValue(element, attribute as CFString, value) == .success
    else { throw OutputError("cannot resize the window") }
  }

  /// The visible frame, in top-left coordinates, of the screen holding most of `frame`.
  private static func visibleFrame(containing frame: CGRect) throws -> CGRect {
    let screens = NSScreen.screens
    guard let primary = screens.first else { throw OutputError("no screen") }
    let height = primary.frame.height
    func overlap(_ screen: NSScreen) -> CGFloat {
      let shared = WindowGeometry.flip(screen.frame, primaryHeight: height).intersection(frame)
      return shared.isNull ? 0 : shared.width * shared.height
    }
    let best = screens.max { overlap($0) < overlap($1) } ?? primary
    return WindowGeometry.flip(best.visibleFrame, primaryHeight: height)
  }
}

// MARK: - System

/// Mission Control family, Spaces, lock and display sleep, each by the sturdiest public route:
///
/// - Mission Control / App Windows / Show Desktop: ask the Dock directly through
///   `CoreDockSendNotification`, a private function in ApplicationServices resolved by name at
///   runtime. Independent of keyboard shortcuts and hot corners. Running the Mission Control
///   app's executable as a child process did nothing on macOS 27 (hardware test 2026-11-06),
///   so it is only the fallback when the function can't be found.
/// - Spaces left / right: post ctrl+left / ctrl+right. There is no public API to switch Spaces,
///   so this depends on the system "Move left/right a space" shortcuts being enabled and unchanged.
/// - Lock Screen: post ctrl+cmd+q, the system Lock Screen shortcut (same dependency). The
///   alternatives either need a private framework or only lock when "require password
///   immediately" is set.
/// - Sleep Display: `pmset displaysleepnow`, public and permission-free. Whether waking needs a
///   password follows the user's own security settings.
final class LiveSystemOutput: SystemOutput {
  static let missionControl = URL(
    fileURLWithPath: "/System/Applications/Mission Control.app/Contents/MacOS/Mission Control")
  static let pmset = URL(fileURLWithPath: "/usr/bin/pmset")

  private let keyboard: KeyboardOutput

  init(keyboard: KeyboardOutput) { self.keyboard = keyboard }

  func perform(_ command: SystemCommand) throws {
    switch command {
    case .missionControl: try Self.dock("com.apple.expose.awake", fallbackArguments: [])
    case .appWindows: try Self.dock("com.apple.expose.front.awake", fallbackArguments: ["2"])
    case .showDesktop: try Self.dock("com.apple.showdesktop.awake", fallbackArguments: ["1"])
    case .spaceLeft: try keyboard.post(KeyCombo(modifiers: [.ctrl], key: "left"))
    case .spaceRight: try keyboard.post(KeyCombo(modifiers: [.ctrl], key: "right"))
    case .lockScreen: try keyboard.post(KeyCombo(modifiers: [.ctrl, .cmd], key: "q"))
    case .sleepDisplay: try Self.launch(Self.pmset, ["displaysleepnow"])
    }
  }

  private typealias SendDockNotification = @convention(c) (CFString, Int32) -> Void

  /// Resolved once; `nil` when the function isn't there on this macOS.
  private static let sendDockNotification: SendDockNotification? = {
    let path = "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices"
    guard let handle = dlopen(path, RTLD_LAZY), let symbol = dlsym(handle, "CoreDockSendNotification") else {
      actionsLog.notice("CoreDockSendNotification unavailable; Mission Control actions use the app fallback")
      return nil
    }
    return unsafeBitCast(symbol, to: SendDockNotification.self)
  }()

  private static func dock(_ notification: String, fallbackArguments: [String]) throws {
    if let send = sendDockNotification {
      send(notification as CFString, 0)
    } else {
      try launch(missionControl, fallbackArguments)
    }
  }

  /// Starts a tool and returns without waiting for it.
  private static func launch(_ tool: URL, _ arguments: [String]) throws {
    let process = Process()
    process.executableURL = tool
    process.arguments = arguments
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    do {
      try process.run()
    } catch {
      throw OutputError("cannot run \(tool.lastPathComponent): \(error.localizedDescription)")
    }
  }
}
