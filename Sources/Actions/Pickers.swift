import CoreGraphics
import EdgyCore
import Foundation

// Picker data for the settings UI (v0.4): installed apps, the user's Shortcuts, and a key combo
// recorder. Models only, no views. Each sits behind a protocol with a live implementation
// (`makeLive…` in `LivePickers.swift`) and is built without side effects: nothing is scanned,
// run or listened to until it is asked for.

// MARK: - Installed apps

/// An app the user can pick for `app.open` or for a per-app profile.
public struct InstalledApp: Sendable, Hashable, Identifiable {
  /// Display name (the bundle's display name, else its name, else the file name).
  public var name: String
  public var bundleID: String
  /// Absolute path of the `.app` bundle.
  public var path: String
  /// Running right now (at the time of the listing).
  public var isRunning: Bool

  public var id: String { bundleID }

  public init(name: String, bundleID: String, path: String, isRunning: Bool) {
    self.name = name
    self.bundleID = bundleID
    self.path = path
    self.isRunning = isRunning
  }
}

/// Lists the apps a user can choose from.
public protocol InstalledAppsProviding: Sendable {
  /// Apps in the standard application folders plus running apps, one per bundle ID, sorted by
  /// name. Does its work off the main thread.
  func installedApps() async -> [InstalledApp]
}

/// What the scanner needs to know about one app bundle.
struct AppBundleInfo: Sendable, Hashable {
  var name: String
  var bundleID: String
  var path: String
}

/// The filesystem, as the app scanner sees it. Injected so tests use an in-memory tree.
protocol AppFolderReading: Sendable {
  /// Entries of a folder (hidden ones skipped); empty when it can't be read.
  func contents(of folder: URL) -> [URL]
  func isDirectory(_ url: URL) -> Bool
  /// The bundle's identity, or `nil` when it isn't a usable app (no bundle ID).
  func bundleInfo(at url: URL) -> AppBundleInfo?
}

/// Apps running now that a user would recognize (regular apps with a bundle ID).
protocol RunningAppsListing: Sendable {
  func runningApps() -> [AppBundleInfo]
}

/// Scans app folders and running apps.
///
/// - Folders are searched in order, each one level deep into plain sub-folders (so suites
///   installed as a folder of apps are found); `.app` bundles are not searched inside.
/// - One entry per bundle ID (compared case-insensitively): the first folder that has it wins;
///   a running app adds `isRunning`, and a running app found in no folder is listed at its
///   running path.
/// - Sorted by name (Finder order: case-insensitive, numbers by value), then bundle ID.
final class InstalledAppsScanner: InstalledAppsProviding {
  /// The standard application folders, in priority order.
  static func standardFolders(home: URL) -> [URL] {
    [
      URL(fileURLWithPath: "/Applications"), URL(fileURLWithPath: "/Applications/Utilities"),
      URL(fileURLWithPath: "/System/Applications"), URL(fileURLWithPath: "/System/Applications/Utilities"),
      home.appendingPathComponent("Applications"),
    ]
  }

  let folders: [URL]
  let reader: AppFolderReading
  let running: RunningAppsListing

  init(folders: [URL], reader: AppFolderReading, running: RunningAppsListing) {
    self.folders = folders
    self.reader = reader
    self.running = running
  }

  func installedApps() async -> [InstalledApp] {
    await Task.detached(priority: .userInitiated) { self.scan() }.value
  }

  func scan() -> [InstalledApp] {
    var byID: [String: InstalledApp] = [:]
    var order: [String] = []
    func add(_ info: AppBundleInfo, running isRunning: Bool) {
      let key = info.bundleID.lowercased()
      if byID[key] != nil {
        if isRunning { byID[key]?.isRunning = true }
        return
      }
      byID[key] = InstalledApp(name: info.name, bundleID: info.bundleID, path: info.path, isRunning: isRunning)
      order.append(key)
    }
    for folder in folders {
      for app in bundles(in: folder, depth: 1) { add(app, running: false) }
    }
    for app in running.runningApps() { add(app, running: true) }
    return order.compactMap { byID[$0] }.sorted {
      switch $0.name.localizedStandardCompare($1.name) {
      case .orderedAscending: return true
      case .orderedDescending: return false
      case .orderedSame: return $0.bundleID < $1.bundleID
      }
    }
  }

  private func bundles(in folder: URL, depth: Int) -> [AppBundleInfo] {
    var found: [AppBundleInfo] = []
    for url in reader.contents(of: folder).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
      if url.pathExtension.lowercased() == "app" {
        if let info = reader.bundleInfo(at: url) { found.append(info) }
      } else if depth > 0, reader.isDirectory(url) {
        found += bundles(in: url, depth: depth - 1)
      }
    }
    return found
  }
}

// MARK: - Shortcuts

/// The user's Shortcuts, for `shortcut.run`.
public struct ShortcutsList: Sendable, Equatable {
  /// Shortcut names, sorted by name, no duplicates. Empty when there are none or on failure.
  public var names: [String]
  /// Why the list couldn't be read, in plain words; `nil` on success (even when empty).
  public var failure: String?

  public init(names: [String], failure: String? = nil) {
    self.names = names
    self.failure = failure
  }
}

/// Lists the user's Shortcuts.
public protocol ShortcutsListing: Sendable {
  /// Runs off the main thread; never throws: failures come back as an empty list and a reason.
  func shortcuts() async -> ShortcutsList
}

/// How a child process ended.
enum ProcessOutcome: Sendable, Equatable {
  case exited(status: Int32, output: Data, errorOutput: Data)
  case timedOut
  case failedToLaunch(String)
}

/// Runs a command and collects its output. Injected so tests never spawn a process.
protocol ProcessRunning: Sendable {
  /// Kills the process and returns `.timedOut` if it runs longer than `timeout` seconds.
  func run(_ executable: URL, arguments: [String], timeout: TimeInterval) async -> ProcessOutcome
}

/// `shortcuts list` through the system `shortcuts` command.
final class ShortcutsCommandListing: ShortcutsListing {
  static let tool = URL(fileURLWithPath: "/usr/bin/shortcuts")
  static let defaultTimeout: TimeInterval = 10

  let runner: ProcessRunning
  let timeout: TimeInterval

  init(runner: ProcessRunning, timeout: TimeInterval = defaultTimeout) {
    self.runner = runner
    self.timeout = timeout
  }

  func shortcuts() async -> ShortcutsList {
    let outcome = await runner.run(Self.tool, arguments: ["list"], timeout: timeout)
    let list = Self.list(from: outcome, timeout: timeout)
    if let failure = list.failure {
      actionsLog.error("shortcuts list: \(failure, privacy: .public)")
    }
    return list
  }

  /// Turns the command's outcome into names or a reason.
  static func list(from outcome: ProcessOutcome, timeout: TimeInterval) -> ShortcutsList {
    switch outcome {
    case .failedToLaunch(let reason):
      return ShortcutsList(names: [], failure: "Couldn't run the shortcuts command: \(reason)")
    case .timedOut:
      return ShortcutsList(
        names: [], failure: "The shortcuts command didn't answer within \(Int(timeout.rounded())) seconds.")
    case .exited(let status, let output, let errorOutput):
      guard status == 0 else {
        let detail = firstLine(errorOutput).map { ": \($0)" } ?? ""
        return ShortcutsList(names: [], failure: "The shortcuts command failed (status \(status))\(detail)")
      }
      guard let names = parse(output) else {
        return ShortcutsList(names: [], failure: "The shortcuts command's output wasn't readable text.")
      }
      return ShortcutsList(names: names)
    }
  }

  /// One name per line, exactly as written (inner spaces and any script kept); blank lines
  /// dropped, a trailing carriage return trimmed, duplicates collapsed, sorted by name.
  /// `nil` when the output isn't UTF-8.
  static func parse(_ output: Data) -> [String]? {
    guard let text = String(data: output, encoding: .utf8) else { return nil }
    var seen = Set<String>()
    var names: [String] = []
    // `isNewline`, not "\n": a CRLF pair is one Character in Swift and wouldn't split on "\n".
    for line in text.split(whereSeparator: \.isNewline) {
      let name = String(line)
      guard !name.trimmingCharacters(in: .whitespaces).isEmpty, seen.insert(name).inserted else { continue }
      names.append(name)
    }
    return names.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
  }

  private static func firstLine(_ data: Data) -> String? {
    let text = String(decoding: data, as: UTF8.self)
    return text.split(separator: "\n").first.map { $0.trimmingCharacters(in: .whitespaces) }
      .flatMap { $0.isEmpty ? nil : $0 }
  }
}

// MARK: - Key combo recorder

/// One keyboard event, as the recorder sees it.
public enum KeyRecorderInput: Sendable, Equatable {
  /// The set of modifier keys held changed (a modifier went down or up).
  case flagsChanged(Set<KeyCombo.Modifier>)
  /// A key went down. `key` is its `KeyCombo` name, `nil` for a key Edgy can't name.
  case keyDown(key: String?, isRepeat: Bool)
  /// The recording ran out of time.
  case timeout

  /// Turns a raw event into recorder input; `nil` for event types the recorder ignores.
  static func from(type: CGEventType, keyCode: Int64, flags: CGEventFlags, isRepeat: Bool) -> KeyRecorderInput? {
    switch type {
    case .flagsChanged: return .flagsChanged(KeyCodes.modifiers(in: flags))
    case .keyDown: return .keyDown(key: KeyCodes.name(for: keyCode), isRepeat: isRepeat)
    default: return nil
    }
  }
}

/// Where a recording is.
public enum KeyRecorderState: Sendable, Equatable {
  /// Waiting; `held` are the modifiers down right now (for the live "⌃⌥…" preview).
  case listening(held: Set<KeyCombo.Modifier>)
  /// Done: a key with modifiers, a bare key, or modifiers alone (pressed and released).
  case recorded(KeyCombo)
  /// Escape alone was pressed, or the recording was cancelled.
  case cancelled
  /// Nothing was recorded in time.
  case timedOut
  /// Keys can't be listened to (permission missing); `reason` is plain copy.
  case unavailable(reason: String)

  /// No more states follow this one.
  public var isFinal: Bool {
    if case .listening = self { return false }
    return true
  }
}

/// The recorder's rules, as a pure state machine (no clock, no events of its own).
///
/// - Modifiers come from the tracked flags-changed state, never from a key event's own flags:
///   arrows and function keys carry the fn flag implicitly, and recording `left` must give
///   `left`, not `fn+left`.
/// - A key going down records it with the modifiers held (a bare key is fine). Escape with no
///   modifiers cancels; with modifiers it records (`cmd+escape`).
/// - Modifiers released back to none, with no key in between, record a modifier-only combo of
///   every modifier that was down (`ctrl↓ opt↓ opt↑ ctrl↑` → `ctrl+opt`; `fn↓ fn↑` → `fn`).
/// - Key repeats and keys with no name are ignored. Nothing changes after a final state.
public struct KeyComboRecorderModel: Sendable, Equatable {
  public private(set) var state: KeyRecorderState = .listening(held: [])
  /// Every modifier down since the last time none were.
  private var chord = Set<KeyCombo.Modifier>()

  public init() {}

  /// Applies one input. Returns the new state when it changed, else `nil`.
  @discardableResult
  public mutating func handle(_ input: KeyRecorderInput) -> KeyRecorderState? {
    guard case .listening(let held) = state else { return nil }
    let next: KeyRecorderState
    switch input {
    case .flagsChanged(let now):
      chord.formUnion(now)
      if now.isEmpty, let combo = KeyCombo(modifiers: chord) {
        next = .recorded(combo)
      } else {
        next = .listening(held: now)
      }
    case .keyDown(let key, let isRepeat):
      guard !isRepeat, let key else { return nil }
      next = key == "escape" && held.isEmpty ? .cancelled : .recorded(KeyCombo(modifiers: held, key: key))
    case .timeout:
      next = .timedOut
    }
    guard next != state else { return nil }
    state = next
    return next
  }
}

/// A "press keys" field's recorder.
public protocol KeyComboRecording: AnyObject, Sendable {
  /// Starts listening (cancelling any recording in progress). The stream yields
  /// `.listening(held: [])` at once, every change after it, and finishes after the first final
  /// state. Keys are listened to only while a recording is open.
  func start(timeout: TimeInterval) -> AsyncStream<KeyRecorderState>
  /// Ends the recording in progress with `.cancelled`. No recording → nothing.
  func cancel()
}

/// Where key events come from while recording. The live one is a listen-only event tap.
protocol KeyEventSource: AnyObject, Sendable {
  /// Starts delivering events to `handler` (from any thread). Throws `OutputError` with a plain
  /// reason when keys can't be listened to.
  func start(_ handler: @escaping @Sendable (KeyRecorderInput) -> Void) throws
  /// Stops listening and drops the handler. Safe to call when not started.
  func stop()
}

/// `KeyComboRecording` over a `KeyEventSource`, with the timeout on an `ActionScheduler`.
final class KeyComboRecorder: KeyComboRecording, @unchecked Sendable {
  static let defaultTimeout: TimeInterval = 10

  private let source: KeyEventSource
  private let scheduler: ActionScheduler
  private let lock = NSRecursiveLock()
  private var model = KeyComboRecorderModel()
  private var continuation: AsyncStream<KeyRecorderState>.Continuation?
  private var timeoutWork: ScheduledWork?
  /// Bumped per recording, so late events from an old one are dropped.
  private var generation = 0

  init(source: KeyEventSource, scheduler: ActionScheduler) {
    self.source = source
    self.scheduler = scheduler
  }

  func start(timeout: TimeInterval) -> AsyncStream<KeyRecorderState> {
    lock.lock()
    defer { lock.unlock() }
    cancel()
    generation += 1
    let current = generation
    model = KeyComboRecorderModel()
    let (stream, continuation) = AsyncStream.makeStream(of: KeyRecorderState.self)
    self.continuation = continuation
    continuation.onTermination = { [weak self] _ in self?.end(generation: current, with: nil) }
    continuation.yield(model.state)
    do {
      try source.start { [weak self] input in self?.receive(input, generation: current) }
    } catch {
      let reason = (error as? OutputError)?.reason ?? String(describing: error)
      end(generation: current, with: .unavailable(reason: reason))
      return stream
    }
    timeoutWork = scheduler.schedule(after: timeout) { [weak self] in
      self?.receive(.timeout, generation: current)
    }
    return stream
  }

  func cancel() {
    lock.lock()
    defer { lock.unlock() }
    end(generation: generation, with: .cancelled)
  }

  private func receive(_ input: KeyRecorderInput, generation: Int) {
    lock.lock()
    defer { lock.unlock() }
    guard generation == self.generation, continuation != nil, let next = model.handle(input) else { return }
    if next.isFinal {
      end(generation: generation, with: next)
    } else {
      continuation?.yield(next)
    }
  }

  /// Stops listening and finishes the stream, after yielding `last` if given. Idempotent.
  private func end(generation: Int, with last: KeyRecorderState?) {
    lock.lock()
    defer { lock.unlock() }
    guard generation == self.generation, let continuation else { return }
    self.continuation = nil
    timeoutWork?.cancel()
    timeoutWork = nil
    source.stop()
    if let last { continuation.yield(last) }
    continuation.finish()
  }
}
