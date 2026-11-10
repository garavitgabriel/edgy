import CoreGraphics
import EdgyCore
import Foundation
import Testing

@testable import Actions

// v0.2 catalog. Every test runs against recording mocks: no key events, app launches, window
// moves, URL opens or power commands reach the real system.

@Suite struct CatalogShapeTests {
  @Test func availablePinsTheFullIdList() {
    let ids = Harness().registry.available.map(\.id.rawValue)
    #expect(
      ids == [
        "audio.volume", "audio.mute", "display.brightness", "mic.mute", "media.playPause", "media.next",
        "media.previous", "shortcut.run",
        "keyboard.backlight", "keyboard.backlightToggle",
        "keyboard.shortcut", "keyboard.slideSteps", "keyboard.hold",
        "app.open", "app.last", "url.open", "file.open", "apps.switcher",
        "system.missionControl", "system.appWindows", "system.showDesktop", "spaces.left", "spaces.right",
        "system.lockScreen", "system.sleepDisplay", "system.dictation", "edgy.none",
        "window.leftHalf", "window.rightHalf", "window.topHalf", "window.bottomHalf", "window.maximize",
        "window.center", "window.minimize", "window.restore",
      ])
    #expect(Set(ids).count == ids.count)
    #expect(ids.count == 35)
  }

  @Test func shapesAndCategories() {
    let byID = Dictionary(uniqueKeysWithValues: Harness().registry.available.map { ($0.id.rawValue, $0) })
    let continuous = Set(byID.values.filter { $0.shape == .continuous }.map(\.id.rawValue))
    #expect(
      continuous == [
        "audio.volume", "display.brightness", "keyboard.slideSteps", "apps.switcher", "keyboard.backlight",
      ])
    let hold = Set(byID.values.filter { $0.shape == .hold }.map(\.id.rawValue))
    #expect(hold == ["keyboard.hold"])
    let expected: [String: ActionCategory] = [
      "audio.volume": .sound, "audio.mute": .sound, "mic.mute": .sound, "display.brightness": .display,
      "media.playPause": .media, "media.next": .media, "media.previous": .media, "shortcut.run": .shortcuts,
      "keyboard.shortcut": .keyboard, "keyboard.slideSteps": .keyboard, "app.open": .apps, "app.last": .apps,
      "url.open": .apps,
      "file.open": .apps, "system.missionControl": .system, "system.appWindows": .system,
      "system.showDesktop": .system, "spaces.left": .system, "spaces.right": .system,
      "system.lockScreen": .system, "system.sleepDisplay": .system, "window.leftHalf": .windows,
      "window.rightHalf": .windows, "window.topHalf": .windows, "window.bottomHalf": .windows,
      "window.maximize": .windows, "window.center": .windows, "window.minimize": .windows,
      "window.restore": .windows, "apps.switcher": .apps, "keyboard.hold": .keyboard,
      "system.dictation": .system, "keyboard.backlight": .display, "keyboard.backlightToggle": .display,
      "edgy.none": .system,
    ]
    #expect(byID.mapValues(\.category) == expected)
  }

  @Test func parameterSpecs() {
    let byID = Dictionary(uniqueKeysWithValues: Harness().registry.available.map { ($0.id.rawValue, $0) })
    #expect(
      byID["shortcut.run"]?.parameters == [
        ActionParameter(key: "name", kind: .text, required: true, displayName: "Shortcut Name")
      ])
    #expect(
      byID["keyboard.shortcut"]?.parameters == [
        ActionParameter(key: "keys", kind: .keyCombo, required: true, displayName: "Keys")
      ])
    let steps = byID["keyboard.slideSteps"]?.parameters ?? []
    // Batch 20: `stepMM` (millimetres) replaced the fraction `step`, which is still read.
    #expect(steps.map(\.key) == ["upKeys", "downKeys", "stepMM", "speedUp"])
    #expect(steps.map(\.required) == [true, true, false, false])
    #expect(steps.map(\.kind) == [.keyCombo, .keyCombo, .number(4...20), .choice(["on", "off"])])
    #expect(steps[2].defaultValue == "8")
    #expect(steps[3].defaultValue == "off")  // stepped slides: speed-up off by default (BRIEF ruling)
    let app = byID["app.open"]?.parameters ?? []
    #expect(app.map(\.key) == ["bundleID", "whenFrontmost"])
    #expect(app.map(\.kind) == [.appBundleID, .choice(["stay", "hide"])])
    #expect(app.map(\.required) == [true, false])
    #expect(app[1].defaultValue == "hide")
    #expect(byID["url.open"]?.parameters.map(\.kind) == [.url])
    #expect(byID["url.open"]?.parameters.map(\.key) == ["url"])
    #expect(byID["file.open"]?.parameters.map(\.kind) == [.filePath])
    #expect(byID["file.open"]?.parameters.map(\.key) == ["path"])
    #expect(
      byID["keyboard.hold"]?.parameters == [
        ActionParameter(key: "keys", kind: .keyCombo, required: true, displayName: "Keys"),
        ActionParameter(
          key: "maxSeconds", kind: .number(5...600), required: false, defaultValue: "120",
          displayName: "Release after"),
        ActionParameter(
          key: "holdMS", kind: .number(100...1500), required: false, defaultValue: "300",
          displayName: "Hold before it starts", helpText: "How long to press before the keys go down.", unit: "ms"),
      ])
    #expect(byID["apps.switcher"]?.parameters.map(\.key) == ["stepMM", "speedUp", "keepOpenMS"])
    for level in ["audio.volume", "display.brightness", "keyboard.backlight"] {
      #expect(byID[level]?.parameters.map(\.key) == ["speedUp"])
    }
    let parameterless = byID.values.filter {
      ![
        "shortcut.run", "keyboard.shortcut", "keyboard.slideSteps", "app.open", "url.open", "file.open",
        "keyboard.hold", "apps.switcher", "audio.volume", "display.brightness", "keyboard.backlight",
      ]
      .contains($0.id.rawValue)
    }
    #expect(parameterless.allSatisfy { $0.parameters.isEmpty })
  }

  @Test func everyParameterIsWellFormed() {
    for descriptor in Harness().registry.available {
      #expect(!descriptor.displayName.isEmpty)
      for parameter in descriptor.parameters {
        #expect(!parameter.displayName.isEmpty)
        // Required parameters have no default; optional ones always do.
        #expect(parameter.required == (parameter.defaultValue == nil), "\(descriptor.id.rawValue).\(parameter.key)")
        // Cross-cutting parameters are never listed per action.
        #expect(!["haptics", "sensitivity"].contains(parameter.key))
      }
    }
  }
}

@Suite struct KeyboardShortcutTests {
  @Test func postsTheCombo() throws {
    let h = Harness()
    try h.trigger("keyboard.shortcut", ["keys": "Shift+CMD+4"])
    #expect(h.keyboard.posted == ["shift+cmd+4"])
  }

  @Test func missingKeysIsMissingParameter() {
    let h = Harness()
    #expect(throws: ActionError.missingParameter("keyboard.shortcut", name: "keys")) {
      try h.trigger("keyboard.shortcut")
    }
    #expect(throws: ActionError.missingParameter("keyboard.shortcut", name: "keys")) {
      try h.trigger("keyboard.shortcut", ["keys": "  "])
    }
    #expect(h.keyboard.posted.isEmpty)
  }

  @Test func unparseableComboIsUnavailableWithReason() {
    let h = Harness()
    #expect(
      throws: ActionError.unavailable("keyboard.shortcut", reason: "keys: \"cmd+banana\" is not a key combination")
    ) {
      try h.trigger("keyboard.shortcut", ["keys": "cmd+banana"])
    }
    #expect(h.keyboard.posted.isEmpty)
  }

  @Test func keyboardFailureIsUnavailable() {
    let h = Harness()
    h.keyboard.failure = OutputError("no event source")
    #expect(throws: ActionError.unavailable("keyboard.shortcut", reason: "no event source")) {
      try h.trigger("keyboard.shortcut", ["keys": "cmd+b"])
    }
  }
}

@Suite struct SlideStepsTests {
  static let zoom = ["upKeys": "cmd+=", "downKeys": "cmd+-"]
  static func zoom(step: String) -> [String: String] { zoom.merging(["step": step]) { $1 } }

  @Test func onePressPerDefaultStepUp() throws {
    let h = Harness()
    try h.slide("keyboard.slideSteps", 0.25, phase: .began, Self.zoom)  // 4 × 0.0625
    #expect(h.keyboard.posted == Array(repeating: "cmd+equal", count: 4))
  }

  @Test func downPressesDownKeys() throws {
    let h = Harness()
    try h.slide("keyboard.slideSteps", -0.1, phase: .began, Self.zoom(step: "0.05"))
    #expect(h.keyboard.posted == ["cmd+minus", "cmd+minus"])
  }

  @Test func partialStepsCarryAcrossChangedEvents() throws {
    let h = Harness()
    let p = Self.zoom(step: "0.1")
    try h.slide("keyboard.slideSteps", 0.06, phase: .began, p)
    #expect(h.keyboard.posted.isEmpty)
    try h.slide("keyboard.slideSteps", 0.06, p)  // 0.12 → one press, 0.02 carried
    #expect(h.keyboard.posted.count == 1)
    try h.slide("keyboard.slideSteps", 0.05, p)  // 0.07
    #expect(h.keyboard.posted.count == 1)
    try h.slide("keyboard.slideSteps", 0.03, p)  // 0.10 → second press
    #expect(h.keyboard.posted == ["cmd+equal", "cmd+equal"])
  }

  @Test func reversingPaysOffTheCarryFirst() throws {
    let h = Harness()
    let p = Self.zoom(step: "0.1")
    try h.slide("keyboard.slideSteps", 0.08, phase: .began, p)
    try h.slide("keyboard.slideSteps", -0.15, p)  // 0.08 - 0.15 = -0.07: no press yet
    #expect(h.keyboard.posted.isEmpty)
    try h.slide("keyboard.slideSteps", -0.04, p)  // -0.11 → one down press
    #expect(h.keyboard.posted == ["cmd+minus"])
  }

  @Test func beganResetsTheCarry() throws {
    let h = Harness()
    let p = Self.zoom(step: "0.1")
    try h.slide("keyboard.slideSteps", 0.09, phase: .began, p)
    try h.slide("keyboard.slideSteps", 0.09, phase: .began, p)  // a new slide: carry was dropped
    #expect(h.keyboard.posted.isEmpty)
    try h.slide("keyboard.slideSteps", 0.0, phase: .ended, p)
    try h.slide("keyboard.slideSteps", 0.02, phase: .changed, p)  // after .ended the carry is gone too
    #expect(h.keyboard.posted.isEmpty)
  }

  @Test func sensitivityScalesTravel() throws {
    let h = Harness()
    var p = Self.zoom(step: "0.1")
    p["sensitivity"] = "2"
    try h.slide("keyboard.slideSteps", 0.15, phase: .began, p)  // 0.3 of travel
    #expect(h.keyboard.posted.count == 3)
  }

  @Test func oneTickPerPressWhenAllowed() throws {
    let h = Harness()
    try h.slide("keyboard.slideSteps", -0.1875, phase: .began, Self.zoom)  // 3 presses
    #expect(h.haptics.ticks == 3)
    #expect(h.haptics.strongTicks == 0)
    let quiet = Harness()
    try quiet.slide("keyboard.slideSteps", 0.1875, phase: .began, Self.zoom.merging(["haptics": "off"]) { $1 })
    #expect(quiet.keyboard.posted.count == 3)
    #expect(quiet.haptics.ticks == 0)
  }

  @Test func missingKeysIsMissingParameter() {
    let h = Harness()
    #expect(throws: ActionError.missingParameter("keyboard.slideSteps", name: "upKeys")) {
      try h.slide("keyboard.slideSteps", 0.5, phase: .began, ["downKeys": "left"])
    }
    #expect(throws: ActionError.missingParameter("keyboard.slideSteps", name: "downKeys")) {
      try h.slide("keyboard.slideSteps", 0.5, phase: .began, ["upKeys": "right"])
    }
    #expect(h.keyboard.posted.isEmpty)
  }

  @Test func badComboIsUnavailableEvenBeforeAPress() {
    let h = Harness()
    #expect(
      throws: ActionError.unavailable("keyboard.slideSteps", reason: "downKeys: \"cmd+\" is not a key combination")
    ) {
      try h.slide("keyboard.slideSteps", 0.0, phase: .began, ["upKeys": "right", "downKeys": "cmd+"])
    }
  }

  @Test func invalidStepIsMissingParameter() {
    let h = Harness()
    for bad in ["fast", "0.01", "0.9", "-0.1"] {
      #expect(throws: ActionError.missingParameter("keyboard.slideSteps", name: "step")) {
        try h.slide("keyboard.slideSteps", 0.5, phase: .began, Self.zoom(step: bad))
      }
    }
    #expect(h.keyboard.posted.isEmpty)
  }

  @Test func doesNotTouchLevelsOrTheDisplay() throws {
    let h = Harness()
    h.display.isAvailable = false
    try h.slide("keyboard.slideSteps", 0.0625, phase: .began, Self.zoom)
    #expect(h.keyboard.posted.count == 1)
    #expect(h.audio.setVolumeCalls.isEmpty && h.display.setCalls.isEmpty && h.hud.shown.isEmpty)
  }

  @Test func triggerIsWrongInputShape() {
    let h = Harness()
    #expect(throws: ActionError.wrongInputShape("keyboard.slideSteps")) {
      try h.trigger("keyboard.slideSteps", Self.zoom)
    }
  }

  @Test func keyStepsRule() {
    #expect(KeySteps.apply(travel: 0.3, step: 0.1, carry: 0) == KeySteps(presses: 3, carry: 0))
    #expect(KeySteps.apply(travel: -0.3, step: 0.1, carry: 0) == KeySteps(presses: -3, carry: 0))
    #expect(KeySteps.apply(travel: 0.05, step: 0.1, carry: 0.04).presses == 0)
    #expect(KeySteps.apply(travel: 100, step: 0.02, carry: 0).presses == KeySteps.maxPressesPerUpdate)
  }
}

@Suite struct OpenTests {
  @Test func openAppActivatesWhenNotFrontmost() throws {
    let h = Harness()
    h.workspace.installed = ["com.example.notes"]
    h.workspace.frontmost = "com.example.other"
    try h.trigger("app.open", ["bundleID": "com.example.notes"])
    #expect(h.workspace.calls == [.activate("com.example.notes")])
  }

  @Test func openAppHidesWhenFrontmostByDefault() throws {
    let h = Harness()
    h.workspace.installed = ["com.example.notes"]
    h.workspace.frontmost = "com.example.notes"
    try h.trigger("app.open", ["bundleID": "com.example.notes"])
    try h.trigger("app.open", ["bundleID": "com.example.notes", "whenFrontmost": "hide"])
    #expect(h.workspace.calls == [.hide("com.example.notes"), .hide("com.example.notes")])
  }

  @Test func openAppStaysWhenAsked() throws {
    let h = Harness()
    h.workspace.installed = ["com.example.notes"]
    h.workspace.frontmost = "com.example.notes"
    try h.trigger("app.open", ["bundleID": "com.example.notes", "whenFrontmost": "stay"])
    #expect(h.workspace.calls == [.activate("com.example.notes")])
  }

  @Test func openAppErrors() {
    let h = Harness()
    #expect(throws: ActionError.missingParameter("app.open", name: "bundleID")) { try h.trigger("app.open") }
    #expect(throws: ActionError.missingParameter("app.open", name: "whenFrontmost")) {
      try h.trigger("app.open", ["bundleID": "com.example.notes", "whenFrontmost": "sometimes"])
    }
    #expect(
      throws: ActionError.unavailable("app.open", reason: "no app installed with bundle ID com.example.missing")
    ) {
      try h.trigger("app.open", ["bundleID": "com.example.missing"])
    }
    #expect(h.workspace.calls.isEmpty)
  }

  @Test func openURL() throws {
    let h = Harness()
    try h.trigger("url.open", ["url": "https://example.com/a?b=c"])
    try h.trigger("url.open", ["url": "mailto:someone@example.com"])
    #expect(
      h.workspace.calls == [
        .openURL(URL(string: "https://example.com/a?b=c")!), .openURL(URL(string: "mailto:someone@example.com")!),
      ])
  }

  @Test func openURLNeedsAUsableURL() {
    let h = Harness()
    for bad: [String: String] in [[:], ["url": ""], ["url": "example dot com"], ["url": "no-scheme"]] {
      #expect(throws: ActionError.missingParameter("url.open", name: "url")) { try h.trigger("url.open", bad) }
    }
    #expect(h.workspace.calls.isEmpty)
  }

  @Test func openFileExpandsTilde() throws {
    let h = Harness()
    let home = NSHomeDirectory()
    h.workspace.existingFiles = ["/tmp/report.pdf", home + "/Notes"]
    try h.trigger("file.open", ["path": "/tmp/report.pdf"])
    try h.trigger("file.open", ["path": "~/Notes"])
    #expect(
      h.workspace.calls == [
        .openFile(URL(fileURLWithPath: "/tmp/report.pdf")), .openFile(URL(fileURLWithPath: home + "/Notes")),
      ])
  }

  @Test func openFileErrors() {
    let h = Harness()
    #expect(throws: ActionError.missingParameter("file.open", name: "path")) { try h.trigger("file.open") }
    #expect(throws: ActionError.missingParameter("file.open", name: "path")) {
      try h.trigger("file.open", ["path": "relative/path.txt"])
    }
    #expect(throws: ActionError.unavailable("file.open", reason: "nothing at /nope/missing.txt")) {
      try h.trigger("file.open", ["path": "/nope/missing.txt"])
    }
    #expect(h.workspace.calls.isEmpty)
  }
}

@Suite struct SystemTests {
  @Test func eachSystemActionSendsItsCommand() throws {
    let h = Harness()
    let pairs: [(String, SystemCommand)] = [
      ("system.missionControl", .missionControl), ("system.appWindows", .appWindows),
      ("system.showDesktop", .showDesktop), ("spaces.left", .spaceLeft), ("spaces.right", .spaceRight),
      ("system.lockScreen", .lockScreen), ("system.sleepDisplay", .sleepDisplay),
    ]
    for (id, _) in pairs { try h.trigger(ActionID(rawValue: id)) }
    #expect(h.system.commands == pairs.map(\.1))
    #expect(Set(pairs.map(\.1)) == Set(SystemCommand.allCases))
    #expect(h.keyboard.posted.isEmpty)
  }

  @Test func systemActionsRejectSlides() {
    let h = Harness()
    #expect(throws: ActionError.wrongInputShape("spaces.left")) { try h.slide("spaces.left", 0.2) }
    #expect(h.system.commands.isEmpty)
  }
}

@Suite struct WindowActionTests {
  static let visible = CGRect(x: 0, y: 25, width: 1440, height: 875)

  @Test func snapsDispatchGeometry() throws {
    let h = Harness()
    try h.trigger("window.leftHalf")
    try h.trigger("window.rightHalf")
    try h.trigger("window.topHalf")
    try h.trigger("window.bottomHalf")
    try h.trigger("window.maximize")
    #expect(
      h.windows.setFrames == [
        CGRect(x: 0, y: 25, width: 720, height: 875), CGRect(x: 720, y: 25, width: 720, height: 875),
        CGRect(x: 0, y: 25, width: 1440, height: 437), CGRect(x: 0, y: 462, width: 1440, height: 438),
        Self.visible,
      ])
  }

  @Test func centerKeepsSize() throws {
    let h = Harness()
    try h.trigger("window.center")
    #expect(h.windows.setFrames == [CGRect(x: 320, y: 162, width: 800, height: 600)])
  }

  @Test func minimizeTargetsTheFocusedWindow() throws {
    let h = Harness()
    try h.trigger("window.minimize")
    #expect(h.windows.minimized == [WindowID(pid: 42, token: 1)])
    #expect(h.windows.setFrames.isEmpty)
    #expect(h.registry.snapMemory.isEmpty)
  }

  @Test func noWindowIsUnavailable() {
    let h = Harness()
    h.windows.window = nil
    for id: ActionID in ["window.leftHalf", "window.minimize", "window.center"] {
      #expect(throws: ActionError.unavailable(id, reason: "the frontmost app has no focused window")) {
        try h.trigger(id)
      }
    }
  }

  @Test func restoreWithoutASnapIsANoOp() throws {
    let h = Harness()
    try h.trigger("window.restore")
    #expect(h.windows.setFrames.isEmpty)
    // Even with no window at all.
    h.windows.window = nil
    try h.trigger("window.restore")
  }

  @Test func restoreReturnsToThePreSnapFrame() throws {
    let h = Harness()
    let original = h.windows.window!.frame
    try h.trigger("window.leftHalf")
    try h.trigger("window.restore")
    #expect(h.windows.setFrames.last == original)
    // Restoring forgets the memory: a second restore does nothing.
    let count = h.windows.setFrames.count
    try h.trigger("window.restore")
    #expect(h.windows.setFrames.count == count)
  }

  @Test func chainedSnapsRestoreToBeforeTheChain() throws {
    let h = Harness()
    let original = h.windows.window!.frame
    try h.trigger("window.leftHalf")
    try h.trigger("window.maximize")
    try h.trigger("window.rightHalf")
    try h.trigger("window.restore")
    #expect(h.windows.setFrames.last == original)
  }

  @Test func movingTheWindowStartsANewChain() throws {
    let h = Harness()
    try h.trigger("window.leftHalf")
    let moved = CGRect(x: 300, y: 300, width: 500, height: 400)
    h.windows.window?.frame = moved  // the user drags it somewhere else
    try h.trigger("window.maximize")
    try h.trigger("window.restore")
    #expect(h.windows.setFrames.last == moved)
  }

  @Test func memoryIsPerWindow() throws {
    let h = Harness()
    let first = h.windows.window!
    try h.trigger("window.leftHalf")
    let other = WindowSnapshot(
      id: WindowID(pid: 7, token: 9), frame: CGRect(x: 50, y: 60, width: 400, height: 300),
      visibleFrame: Self.visible)
    h.windows.window = other
    try h.trigger("window.restore")  // never snapped: no-op
    #expect(h.windows.setFrames.count == 1)
    h.windows.window = first
    h.windows.window?.frame = h.windows.setFrames[0]
    try h.trigger("window.restore")
    #expect(h.windows.setFrames.last == first.frame)
  }

  @Test func snapMemoryIsBounded() throws {
    let h = Harness()
    for token in 0..<(ActionRegistry.snapMemoryLimit + 5) {
      h.windows.window = WindowSnapshot(
        id: WindowID(pid: 1, token: token), frame: CGRect(x: 10, y: 40, width: 300, height: 200),
        visibleFrame: Self.visible)
      try h.trigger("window.maximize")
    }
    #expect(h.registry.snapMemory.count == ActionRegistry.snapMemoryLimit)
    #expect(h.registry.snapMemory[WindowID(pid: 1, token: 0)] == nil)
  }
}

@Suite struct WindowGeometryTests {
  static let screen = CGRect(x: 0, y: 25, width: 1440, height: 875)
  static let window = CGRect(x: 100, y: 100, width: 800, height: 600)

  @Test func halvesCoverTheScreen() {
    let left = WindowGeometry.target(for: .leftHalf, window: Self.window, visible: Self.screen)
    let right = WindowGeometry.target(for: .rightHalf, window: Self.window, visible: Self.screen)
    #expect(left == CGRect(x: 0, y: 25, width: 720, height: 875))
    #expect(right == CGRect(x: 720, y: 25, width: 720, height: 875))
    let top = WindowGeometry.target(for: .topHalf, window: Self.window, visible: Self.screen)
    let bottom = WindowGeometry.target(for: .bottomHalf, window: Self.window, visible: Self.screen)
    // In top-left coordinates the top half starts at the screen's minY.
    #expect(top == CGRect(x: 0, y: 25, width: 1440, height: 437))
    #expect(bottom == CGRect(x: 0, y: 462, width: 1440, height: 438))
    #expect(top.union(bottom) == Self.screen && left.union(right) == Self.screen)
  }

  @Test func oddSizesSplitWithoutGapOrOverlap() {
    let odd = CGRect(x: 0, y: 0, width: 1001, height: 777)
    let left = WindowGeometry.target(for: .leftHalf, window: Self.window, visible: odd)
    let right = WindowGeometry.target(for: .rightHalf, window: Self.window, visible: odd)
    #expect(left.width == 500 && right.width == 501)
    #expect(left.maxX == right.minX)
    let top = WindowGeometry.target(for: .topHalf, window: Self.window, visible: odd)
    let bottom = WindowGeometry.target(for: .bottomHalf, window: Self.window, visible: odd)
    #expect(top.height == 388 && bottom.height == 389 && top.maxY == bottom.minY)
  }

  @Test func fractionalVisibleFrameIsRoundedOutward() {
    let frac = CGRect(x: 0.5, y: 24.5, width: 1439.2, height: 875.3)
    let max = WindowGeometry.target(for: .maximize, window: Self.window, visible: frac)
    #expect(max == frac.integral)
    #expect([max.minX, max.minY, max.width, max.height].allSatisfy { $0 == $0.rounded() })
  }

  @Test func screenNotAtOrigin() {
    // A second display to the left of and above the primary one.
    let second = CGRect(x: -1920, y: -1080, width: 1920, height: 1055)
    #expect(
      WindowGeometry.target(for: .rightHalf, window: Self.window, visible: second)
        == CGRect(x: -960, y: -1080, width: 960, height: 1055))
    #expect(
      WindowGeometry.target(for: .bottomHalf, window: Self.window, visible: second)
        == CGRect(x: -1920, y: -553, width: 1920, height: 528))
    #expect(
      WindowGeometry.target(for: .center, window: Self.window, visible: second)
        == CGRect(x: -1360, y: -853, width: 800, height: 600))
  }

  @Test func maximizeFillsTheVisibleFrame() {
    #expect(WindowGeometry.target(for: .maximize, window: Self.window, visible: Self.screen) == Self.screen)
  }

  @Test func centerKeepsSizeAndCentres() {
    let c = WindowGeometry.target(
      for: .center, window: CGRect(x: 0, y: 0, width: 801, height: 601), visible: Self.screen)
    #expect(c.size == CGSize(width: 801, height: 601))
    #expect(c.origin == CGPoint(x: 319, y: 162))
  }

  @Test func centerShrinksAndClampsAnOversizeWindow() {
    let huge = CGRect(x: -500, y: -500, width: 3000, height: 2000)
    let c = WindowGeometry.target(for: .center, window: huge, visible: Self.screen)
    #expect(c == Self.screen)
    let wide = CGRect(x: 0, y: 0, width: 2000, height: 300)
    let w = WindowGeometry.target(for: .center, window: wide, visible: Self.screen)
    #expect(w.minX == Self.screen.minX && w.width == Self.screen.width && w.height == 300)
    #expect(Self.screen.contains(w))
  }

  @Test func flipBetweenAppKitAndTopLeft() {
    // Primary display 900 high. AppKit's visible frame sits above a 70 pt Dock, below a 25 pt menu bar.
    let appKit = CGRect(x: 0, y: 70, width: 1440, height: 805)
    let topLeft = WindowGeometry.flip(appKit, primaryHeight: 900)
    #expect(topLeft == CGRect(x: 0, y: 25, width: 1440, height: 805))
    #expect(WindowGeometry.flip(topLeft, primaryHeight: 900) == appKit)
    // A display stacked above the primary has negative top-left y.
    let above = CGRect(x: 200, y: 900, width: 1920, height: 1080)
    #expect(WindowGeometry.flip(above, primaryHeight: 900) == CGRect(x: 200, y: -1080, width: 1920, height: 1080))
    // A top-left "top half" flips to the upper half in AppKit (higher y).
    let top = WindowGeometry.target(for: .topHalf, window: Self.window, visible: topLeft)
    let topInAppKit = WindowGeometry.flip(top, primaryHeight: 900)
    #expect(topInAppKit.maxY == appKit.maxY)
    #expect(topInAppKit.minY > appKit.minY)
  }
}

@Suite struct KeyCodeTableTests {
  @Test func coversTheWholeVocabulary() {
    let missing = KeyCombo.keyNames.filter { KeyCodes.byName[$0] == nil }
    #expect(missing.isEmpty, "no key code for \(missing)")
    #expect(Set(KeyCodes.byName.keys) == Set(KeyCombo.keyNames))
  }

  @Test func codesAreDistinct() {
    let codes = Array(KeyCodes.byName.values) + KeyCombo.Modifier.allCases.compactMap { KeyCodes.modifiers[$0]?.code }
    #expect(Set(codes).count == codes.count)
    #expect(KeyCombo.Modifier.allCases.allSatisfy { KeyCodes.modifiers[$0] != nil })
  }

  @Test func wellKnownCodes() {
    #expect(KeyCodes.byName["a"] == 0x00)
    #expect(KeyCodes.byName["b"] == 0x0B)
    #expect(KeyCodes.byName["4"] == 0x15)
    #expect(KeyCodes.byName["equal"] == 0x18)
    #expect(KeyCodes.byName["left"] == 0x7B)
    #expect(KeyCodes.byName["space"] == 0x31)
    #expect(KeyCodes.byName["f1"] == 0x7A)
  }

  @Test func flagsIncludeModifiersAndImplicitKeyFlags() {
    let spaces = KeyCodes.flags(for: KeyCombo("ctrl+left")!)
    #expect(spaces.contains(.maskControl) && spaces.contains(.maskNumericPad) && spaces.contains(.maskSecondaryFn))
    let bold = KeyCodes.flags(for: KeyCombo("cmd+b")!)
    #expect(bold == .maskCommand)
    #expect(KeyCodes.flags(for: KeyCombo("f5")!) == .maskSecondaryFn)
    #expect(KeyCodes.flags(for: KeyCombo("f")!) == [])
  }
}
