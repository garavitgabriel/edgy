import AppKit
import CoreGraphics
import EdgyCore
import Foundation

// Live picker sources (v0.4). Only the app may call the `makeLive…` factories; tests build the
// scanner, Shortcuts listing and recorder from fakes. Building any of them has no side effects.

/// Installed apps from the standard application folders and the running apps.
public func makeLiveInstalledAppsProvider() -> InstalledAppsProviding {
  InstalledAppsScanner(
    folders: InstalledAppsScanner.standardFolders(home: FileManager.default.homeDirectoryForCurrentUser),
    reader: LiveAppFolderReader(), running: LiveRunningApps())
}

/// The user's Shortcuts through the system `shortcuts` command (10 s timeout).
public func makeLiveShortcutsListing() -> ShortcutsListing {
  ShortcutsCommandListing(runner: LiveProcessRunner())
}

/// A key combo recorder on a listen-only event tap, installed only while a recording is open.
/// Needs Input Monitoring (or Accessibility); without it a recording ends `.unavailable`.
public func makeLiveKeyComboRecorder() -> KeyComboRecording {
  KeyComboRecorder(source: LiveKeyEventTap(), scheduler: LiveActionScheduler())
}

// MARK: - Apps

final class LiveAppFolderReader: AppFolderReading {
  func contents(of folder: URL) -> [URL] {
    (try? FileManager.default.contentsOfDirectory(
      at: folder, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
  }

  func isDirectory(_ url: URL) -> Bool {
    (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
  }

  func bundleInfo(at url: URL) -> AppBundleInfo? {
    guard let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier, !bundleID.isEmpty else {
      return nil
    }
    func string(_ key: String) -> String? {
      let value = (bundle.localizedInfoDictionary?[key] ?? bundle.infoDictionary?[key]) as? String
      return value.flatMap { $0.isEmpty ? nil : $0 }
    }
    let name = string("CFBundleDisplayName") ?? string("CFBundleName") ?? url.deletingPathExtension().lastPathComponent
    return AppBundleInfo(name: name, bundleID: bundleID, path: url.path)
  }
}

final class LiveRunningApps: RunningAppsListing {
  func runningApps() -> [AppBundleInfo] {
    NSWorkspace.shared.runningApplications.compactMap { app in
      guard app.activationPolicy == .regular, let bundleID = app.bundleIdentifier, let url = app.bundleURL else {
        return nil
      }
      let name = app.localizedName ?? url.deletingPathExtension().lastPathComponent
      return AppBundleInfo(name: name, bundleID: bundleID, path: url.path)
    }
  }
}

// MARK: - Processes

/// Runs a command with a timeout, reading its output as it comes (so a large output can't fill
/// the pipe and stall the command).
final class LiveProcessRunner: ProcessRunning {
  func run(_ executable: URL, arguments: [String], timeout: TimeInterval) async -> ProcessOutcome {
    await withCheckedContinuation { (continuation: CheckedContinuation<ProcessOutcome, Never>) in
      let once = Once(continuation)
      let process = Process()
      process.executableURL = executable
      process.arguments = arguments
      let output = Pipe()
      let errorOutput = Pipe()
      process.standardOutput = output
      process.standardError = errorOutput
      process.standardInput = FileHandle.nullDevice
      let collected = Collected()
      output.fileHandleForReading.readabilityHandler = { collected.appendOutput($0.availableData) }
      errorOutput.fileHandleForReading.readabilityHandler = { collected.appendError($0.availableData) }
      process.terminationHandler = { process in
        output.fileHandleForReading.readabilityHandler = nil
        errorOutput.fileHandleForReading.readabilityHandler = nil
        collected.appendOutput(output.fileHandleForReading.readDataToEndOfFile())
        collected.appendError(errorOutput.fileHandleForReading.readDataToEndOfFile())
        let (out, err) = collected.snapshot()
        once.resume(.exited(status: process.terminationStatus, output: out, errorOutput: err))
      }
      do {
        try process.run()
      } catch {
        once.resume(.failedToLaunch(error.localizedDescription))
        return
      }
      DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
        guard process.isRunning else { return }
        if once.resume(.timedOut) { process.terminate() }
      }
    }
  }

  /// Resumes a continuation exactly once.
  private final class Once: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<ProcessOutcome, Never>?
    init(_ continuation: CheckedContinuation<ProcessOutcome, Never>) { self.continuation = continuation }
    @discardableResult
    func resume(_ outcome: ProcessOutcome) -> Bool {
      lock.lock()
      let continuation = self.continuation
      self.continuation = nil
      lock.unlock()
      continuation?.resume(returning: outcome)
      return continuation != nil
    }
  }

  private final class Collected: @unchecked Sendable {
    private let lock = NSLock()
    private var output = Data()
    private var error = Data()
    func appendOutput(_ data: Data) {
      lock.lock()
      output.append(data)
      lock.unlock()
    }
    func appendError(_ data: Data) {
      lock.lock()
      error.append(data)
      lock.unlock()
    }
    func snapshot() -> (Data, Data) {
      lock.lock()
      defer { lock.unlock() }
      return (output, error)
    }
  }
}

// MARK: - Key events

/// A listen-only session event tap for key-down and flags-changed events, on the main run loop.
/// It never changes or blocks an event. Installed by `start`, removed by `stop`.
final class LiveKeyEventTap: KeyEventSource, @unchecked Sendable {
  private let lock = NSLock()
  private var tap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var handler: (@Sendable (KeyRecorderInput) -> Void)?

  func start(_ handler: @escaping @Sendable (KeyRecorderInput) -> Void) throws {
    stop()
    let mask = CGEventMask(1 << CGEventType.keyDown.rawValue) | CGEventMask(1 << CGEventType.flagsChanged.rawValue)
    let callback: CGEventTapCallBack = { _, type, event, info in
      if let info {
        Unmanaged<LiveKeyEventTap>.fromOpaque(info).takeUnretainedValue().receive(type, event)
      }
      return Unmanaged.passUnretained(event)
    }
    guard
      let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly, eventsOfInterest: mask,
        callback: callback, userInfo: Unmanaged.passUnretained(self).toOpaque())
    else {
      actionsLog.error("key recorder: cannot create a listen-only event tap (Input Monitoring not granted?)")
      throw OutputError("Edgy needs Input Monitoring permission to record keys.")
    }
    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    lock.lock()
    self.tap = tap
    self.runLoopSource = source
    self.handler = handler
    lock.unlock()
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
  }

  func stop() {
    lock.lock()
    let tap = self.tap
    let source = runLoopSource
    self.tap = nil
    runLoopSource = nil
    handler = nil
    lock.unlock()
    if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
    if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
    if let tap { CFMachPortInvalidate(tap) }
  }

  private func receive(_ type: CGEventType, _ event: CGEvent) {
    lock.lock()
    let handler = self.handler
    let tap = self.tap
    lock.unlock()
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
      return
    }
    guard
      let handler,
      let input = KeyRecorderInput.from(
        type: type, keyCode: event.getIntegerValueField(.keyboardEventKeycode), flags: event.flags,
        isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0)
    else { return }
    handler(input)
  }
}
