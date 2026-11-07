import CoreGraphics
import EdgyCore
import Foundation
import Testing

@testable import Actions

// v0.4 pickers. Everything runs on in-memory fakes: no folder is read, no process is started, no
// event tap is installed.

// MARK: - Fakes

/// An in-memory folder tree: folder path → entry names; `.app` entries map to bundle info.
final class FakeAppFolders: AppFolderReading, @unchecked Sendable {
  var tree: [String: [String]] = [:]
  var apps: [String: AppBundleInfo] = [:]
  private(set) var listed: [String] = []

  func contents(of folder: URL) -> [URL] {
    listed.append(folder.path)
    return (tree[folder.path] ?? []).map { folder.appendingPathComponent($0) }
  }
  func isDirectory(_ url: URL) -> Bool { tree[url.path] != nil }
  func bundleInfo(at url: URL) -> AppBundleInfo? { apps[url.path] }

  /// Adds an app bundle at `folder/file` with that identity.
  func addApp(_ folder: String, _ file: String, name: String, id: String) {
    tree[folder, default: []].append(file)
    apps[folder + "/" + file] = AppBundleInfo(name: name, bundleID: id, path: folder + "/" + file)
  }
}

final class FakeRunningApps: RunningAppsListing, @unchecked Sendable {
  var apps: [AppBundleInfo] = []
  func runningApps() -> [AppBundleInfo] { apps }
}

final class FakeProcessRunner: ProcessRunning, @unchecked Sendable {
  var outcome: ProcessOutcome
  private(set) var calls: [(path: String, arguments: [String], timeout: TimeInterval)] = []
  init(_ outcome: ProcessOutcome) { self.outcome = outcome }
  func run(_ executable: URL, arguments: [String], timeout: TimeInterval) async -> ProcessOutcome {
    calls.append((executable.path, arguments, timeout))
    return outcome
  }
}

final class FakeKeyEventSource: KeyEventSource, @unchecked Sendable {
  var failure: OutputError?
  private(set) var starts = 0
  private(set) var stops = 0
  private(set) var handler: (@Sendable (KeyRecorderInput) -> Void)?
  var isListening: Bool { handler != nil }

  func start(_ handler: @escaping @Sendable (KeyRecorderInput) -> Void) throws {
    if let failure { throw failure }
    starts += 1
    self.handler = handler
  }
  func stop() {
    stops += 1
    handler = nil
  }
  /// A key event arriving from the keyboard.
  func send(_ input: KeyRecorderInput) { handler?(input) }
}

// MARK: - Installed apps

@Suite struct InstalledAppsTests {
  let folders = FakeAppFolders()
  let running = FakeRunningApps()

  func scanner(_ roots: [String] = ["/Applications", "/System/Applications", "/Users/me/Applications"])
    -> InstalledAppsScanner
  {
    InstalledAppsScanner(folders: roots.map { URL(fileURLWithPath: $0) }, reader: folders, running: running)
  }

  @Test func sortedByNameFinderStyle() async {
    folders.addApp("/Applications", "Zed.app", name: "zebra", id: "z.z")
    folders.addApp("/Applications", "Alpha.app", name: "Alpha", id: "a.a")
    folders.addApp("/Applications", "Ten.app", name: "App 10", id: "t.10")
    folders.addApp("/Applications", "Two.app", name: "App 2", id: "t.2")
    folders.addApp("/System/Applications", "Écran.app", name: "Écran", id: "e.e")
    let apps = await scanner().installedApps()
    #expect(apps.map(\.name) == ["Alpha", "App 2", "App 10", "Écran", "zebra"])
    #expect(apps.allSatisfy { !$0.isRunning })
  }

  @Test func dedupByBundleIDFirstFolderWins() {
    folders.addApp("/Applications", "Notes.app", name: "Notes Copy", id: "com.example.Notes")
    folders.addApp("/System/Applications", "Notes.app", name: "Notes", id: "com.example.notes")
    let apps = scanner().scan()
    #expect(apps.count == 1)
    #expect(apps[0].path == "/Applications/Notes.app")
    #expect(apps[0].name == "Notes Copy")
  }

  @Test func runningAppsMarkedAndAddedWhenNotInAFolder() {
    folders.addApp("/Applications", "Editor.app", name: "Editor", id: "x.editor")
    folders.addApp("/Applications", "Mail.app", name: "Mail", id: "x.mail")
    running.apps = [
      AppBundleInfo(name: "Editor (running)", bundleID: "x.editor", path: "/Volumes/Other/Editor.app"),
      AppBundleInfo(name: "Downloaded", bundleID: "x.dl", path: "/Users/me/Downloads/Downloaded.app"),
    ]
    let apps = scanner().scan()
    #expect(
      apps == [
        InstalledApp(name: "Downloaded", bundleID: "x.dl", path: "/Users/me/Downloads/Downloaded.app", isRunning: true),
        InstalledApp(name: "Editor", bundleID: "x.editor", path: "/Applications/Editor.app", isRunning: true),
        InstalledApp(name: "Mail", bundleID: "x.mail", path: "/Applications/Mail.app", isRunning: false),
      ])
  }

  @Test func searchesOneLevelOfSubfoldersButNotInsideApps() {
    folders.addApp("/Applications/Suite", "Writer.app", name: "Writer", id: "s.writer")
    folders.tree["/Applications", default: []].append("Suite")
    folders.addApp("/Applications/Suite/Deeper", "Hidden.app", name: "Too Deep", id: "s.deep")
    folders.tree["/Applications/Suite", default: []].append("Deeper")
    folders.addApp("/Applications", "Host.app", name: "Host", id: "h.host")
    folders.tree["/Applications/Host.app"] = ["Contents"]
    let apps = scanner().scan()
    #expect(apps.map(\.bundleID) == ["h.host", "s.writer"])
    #expect(!folders.listed.contains("/Applications/Host.app"))
  }

  @Test func skipsBundlesWithoutAnIDAndMissingFolders() {
    folders.tree["/Applications"] = ["Broken.app", "notes.txt"]
    folders.addApp("/Applications", "Good.app", name: "Good", id: "g.g")
    let apps = scanner(["/Applications", "/Nowhere"]).scan()
    #expect(apps.map(\.bundleID) == ["g.g"])
  }

  @Test func standardFoldersCoverSystemUserAndUtilities() {
    let paths = InstalledAppsScanner.standardFolders(home: URL(fileURLWithPath: "/Users/me")).map(\.path)
    #expect(
      paths == [
        "/Applications", "/Applications/Utilities", "/System/Applications", "/System/Applications/Utilities",
        "/Users/me/Applications",
      ])
  }

  @Test func buildingTheScannerReadsNothing() {
    _ = scanner()
    #expect(folders.listed.isEmpty)
  }
}

// MARK: - Shortcuts

@Suite struct ShortcutsListingTests {
  func list(_ outcome: ProcessOutcome) async -> (ShortcutsList, FakeProcessRunner) {
    let runner = FakeProcessRunner(outcome)
    return (await ShortcutsCommandListing(runner: runner, timeout: 7).shortcuts(), runner)
  }

  static func ok(_ text: String) -> ProcessOutcome {
    .exited(status: 0, output: Data(text.utf8), errorOutput: Data())
  }

  @Test func runsShortcutsListWithTheTimeout() async {
    let (_, runner) = await list(Self.ok(""))
    #expect(runner.calls.count == 1)
    #expect(runner.calls.first?.path == "/usr/bin/shortcuts")
    #expect(runner.calls.first?.arguments == ["list"])
    #expect(runner.calls.first?.timeout == 7)
    #expect(ShortcutsCommandListing.defaultTimeout == 10)
  }

  @Test func namesWithSpacesAndUnicodeKeptExactly() async {
    let (result, _) = await list(Self.ok("Morning Routine\n  Indented name\nCafé ☕️ time\n日本語のショートカット\n"))
    #expect(result.failure == nil)
    #expect(Set(result.names) == ["Morning Routine", "  Indented name", "Café ☕️ time", "日本語のショートカット"])
  }

  @Test func sortedDedupedBlankLinesAndCRLFDropped() async {
    let (result, _) = await list(Self.ok("b shortcut\r\n\nA shortcut\n   \nb shortcut\nShortcut 10\nShortcut 9"))
    #expect(result.names == ["A shortcut", "b shortcut", "Shortcut 9", "Shortcut 10"])
  }

  @Test func emptyOutputIsAnEmptyListNotAFailure() async {
    let (result, _) = await list(Self.ok(""))
    #expect(result == ShortcutsList(names: []))
  }

  @Test func nonZeroExitGivesTheReason() async {
    let (result, _) = await list(
      .exited(status: 1, output: Data("Half\n".utf8), errorOutput: Data("Error: not allowed\nmore\n".utf8)))
    #expect(result.names.isEmpty)
    #expect(result.failure == "The shortcuts command failed (status 1): Error: not allowed")
  }

  @Test func timeoutGivesAReason() async {
    let (result, _) = await list(.timedOut)
    #expect(result.names.isEmpty)
    #expect(result.failure == "The shortcuts command didn't answer within 7 seconds.")
  }

  @Test func launchFailureGivesAReason() async {
    let (result, _) = await list(.failedToLaunch("no such file"))
    #expect(result.names.isEmpty)
    #expect(result.failure?.contains("no such file") == true)
  }

  @Test func unreadableOutputIsAFailure() async {
    let (result, _) = await list(.exited(status: 0, output: Data([0xFF, 0xFE, 0x00]), errorOutput: Data()))
    #expect(result.names.isEmpty)
    #expect(result.failure != nil)
  }
}

// MARK: - Recorder state machine

@Suite struct KeyComboRecorderModelTests {
  @Test func comboWhenAKeyGoesDownWithModifiers() {
    var model = KeyComboRecorderModel()
    #expect(model.handle(.flagsChanged([.cmd])) == .listening(held: [.cmd]))
    #expect(model.handle(.flagsChanged([.cmd, .shift])) == .listening(held: [.cmd, .shift]))
    #expect(model.handle(.keyDown(key: "4", isRepeat: false)) == .recorded(KeyCombo("cmd+shift+4")!))
  }

  @Test func bareKeyRecords() {
    var model = KeyComboRecorderModel()
    model.handle(.keyDown(key: "left", isRepeat: false))
    #expect(model.state == .recorded(KeyCombo("left")!))
  }

  @Test func modifierOnlyOnReleaseFn() {
    var model = KeyComboRecorderModel()
    model.handle(.flagsChanged([.fn]))
    #expect(model.handle(.flagsChanged([])) == .recorded(KeyCombo(modifiers: [.fn])!))
    #expect(model.state.isFinal)
  }

  @Test func modifierOnlyKeepsEveryModifierOfTheChord() {
    var model = KeyComboRecorderModel()
    model.handle(.flagsChanged([.ctrl]))
    model.handle(.flagsChanged([.ctrl, .opt]))
    #expect(model.handle(.flagsChanged([.ctrl])) == .listening(held: [.ctrl]))
    model.handle(.flagsChanged([]))
    #expect(model.state == .recorded(KeyCombo("ctrl+opt")!))
  }

  @Test func escapeAloneCancelsEscapeWithModifiersRecords() {
    var alone = KeyComboRecorderModel()
    #expect(alone.handle(.keyDown(key: "escape", isRepeat: false)) == .cancelled)
    var withCmd = KeyComboRecorderModel()
    withCmd.handle(.flagsChanged([.cmd]))
    #expect(withCmd.handle(.keyDown(key: "escape", isRepeat: false)) == .recorded(KeyCombo("cmd+escape")!))
  }

  @Test func timeoutEndsAListeningRecording() {
    var model = KeyComboRecorderModel()
    model.handle(.flagsChanged([.shift]))
    #expect(model.handle(.timeout) == .timedOut)
  }

  @Test func ignoresKeyRepeatAndUnnamedKeys() {
    var model = KeyComboRecorderModel()
    #expect(model.handle(.keyDown(key: "a", isRepeat: true)) == nil)
    #expect(model.handle(.keyDown(key: nil, isRepeat: false)) == nil)
    #expect(model.state == .listening(held: []))
  }

  @Test func nothingChangesAfterAFinalState() {
    var model = KeyComboRecorderModel()
    model.handle(.keyDown(key: "f5", isRepeat: false))
    #expect(model.handle(.keyDown(key: "a", isRepeat: false)) == nil)
    #expect(model.handle(.flagsChanged([.cmd])) == nil)
    #expect(model.handle(.timeout) == nil)
    #expect(model.state == .recorded(KeyCombo("f5")!))
  }

  @Test func modifiersComeFromTrackedStateNotTheKeysImplicitFlags() {
    // An arrow key's raw event carries the fn and numeric-pad flags; recording it must not.
    let raw = KeyRecorderInput.from(
      type: .keyDown, keyCode: 0x7B, flags: [.maskSecondaryFn, .maskNumericPad, .maskControl], isRepeat: false)
    #expect(raw == .keyDown(key: "left", isRepeat: false))
    var model = KeyComboRecorderModel()
    model.handle(.flagsChanged([.ctrl]))
    model.handle(raw!)
    #expect(model.state == .recorded(KeyCombo("ctrl+left")!))
  }

  @Test func rawEventTranslation() {
    let fnDown = KeyRecorderInput.from(
      type: .flagsChanged, keyCode: 0x3F, flags: CGEventFlags(rawValue: 0x2080_0000), isRepeat: false)
    #expect(fnDown == .flagsChanged([.fn]))
    let ctrlOpt = KeyRecorderInput.from(
      type: .flagsChanged, keyCode: 0x3A, flags: CGEventFlags(rawValue: 0x200C_0021), isRepeat: false)
    #expect(ctrlOpt == .flagsChanged([.ctrl, .opt]))
    #expect(
      KeyRecorderInput.from(type: .keyDown, keyCode: 0x00, flags: [], isRepeat: true)
        == .keyDown(key: "a", isRepeat: true))
    #expect(
      KeyRecorderInput.from(type: .keyDown, keyCode: 0x3FF, flags: [], isRepeat: false)
        == .keyDown(key: nil, isRepeat: false))
    #expect(KeyRecorderInput.from(type: .keyUp, keyCode: 0x00, flags: [], isRepeat: false) == nil)
  }
}

// MARK: - Recorder session

@Suite struct KeyComboRecorderTests {
  let source = FakeKeyEventSource()
  let scheduler = MockScheduler()
  var recorder: KeyComboRecorder { KeyComboRecorder(source: source, scheduler: scheduler) }

  func collect(_ stream: AsyncStream<KeyRecorderState>) async -> [KeyRecorderState] {
    var states: [KeyRecorderState] = []
    for await state in stream { states.append(state) }
    return states
  }

  @Test func buildingDoesNotListen() {
    _ = recorder
    #expect(source.starts == 0)
  }

  @Test func recordsAComboAndStopsListening() async {
    let recorder = self.recorder
    let stream = recorder.start(timeout: 10)
    #expect(source.isListening)
    source.send(.flagsChanged([.cmd]))
    source.send(.keyDown(key: "k", isRepeat: false))
    #expect(!source.isListening)
    #expect(await collect(stream) == [.listening(held: []), .listening(held: [.cmd]), .recorded(KeyCombo("cmd+k")!)])
    #expect(scheduler.pending.isEmpty)
  }

  @Test func fnPressAndReleaseRecordsModifierOnly() async {
    let recorder = self.recorder
    let stream = recorder.start(timeout: 10)
    source.send(.flagsChanged([.fn]))
    source.send(.flagsChanged([]))
    #expect(await collect(stream).last == .recorded(KeyCombo(modifiers: [.fn])!))
  }

  @Test func timesOutOnTheScheduler() async {
    let recorder = self.recorder
    let stream = recorder.start(timeout: 10)
    #expect(scheduler.pending.map(\.delay) == [10])
    scheduler.advance(by: 10)
    #expect(await collect(stream) == [.listening(held: []), .timedOut])
    #expect(!source.isListening)
  }

  @Test func cancelEndsWithCancelled() async {
    let recorder = self.recorder
    let stream = recorder.start(timeout: 10)
    recorder.cancel()
    #expect(await collect(stream) == [.listening(held: []), .cancelled])
    #expect(!source.isListening && scheduler.pending.isEmpty)
    recorder.cancel()  // no recording: nothing happens
  }

  @Test func restartCancelsThePreviousRecordingAndIgnoresItsLateEvents() async {
    let recorder = self.recorder
    let first = recorder.start(timeout: 10)
    let second = recorder.start(timeout: 10)
    #expect(await collect(first) == [.listening(held: []), .cancelled])
    scheduler.fireLate(scheduler.scheduled[0])  // the first recording's timer, racing its cancel
    source.send(.keyDown(key: "x", isRepeat: false))
    #expect(await collect(second) == [.listening(held: []), .recorded(KeyCombo("x")!)])
  }

  @Test func noPermissionEndsUnavailable() async {
    source.failure = OutputError("Edgy needs Input Monitoring permission to record keys.")
    let recorder = self.recorder
    let states = await collect(recorder.start(timeout: 10))
    #expect(
      states == [.listening(held: []), .unavailable(reason: "Edgy needs Input Monitoring permission to record keys.")])
    #expect(scheduler.scheduled.isEmpty)
  }

  @Test func keyRepeatDoesNotFinish() async {
    let recorder = self.recorder
    let stream = recorder.start(timeout: 10)
    source.send(.keyDown(key: "a", isRepeat: true))
    #expect(source.isListening)
    recorder.cancel()
    #expect(await collect(stream) == [.listening(held: []), .cancelled])
  }
}
