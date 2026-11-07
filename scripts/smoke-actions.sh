#!/usr/bin/env bash
# Manual smoke test for the live action outputs. HUMAN-RUN ONLY — never from CI or an agent.
#
# It changes real volume, mute, brightness, media playback, the HUD and haptics, then drives the
# v0.2 catalog: opens a TextEdit document, sends it shortcuts, snaps its window, opens a URL,
# shows Mission Control and switches Spaces. v0.3 steps (17+): measures the fine level-key step,
# checks the native volume HUD with headphones, drives the app switcher, holds a key, toggles
# Dictation, the keyboard backlight, and snaps a full-screen window. v0.4 steps (24+): fn-only
# push-to-talk, the hold watchdog, the key recorder (needs Input Monitoring for your terminal
# app), and the installed-apps and Shortcuts listings. It asks before each step and
# restores prior values at the end (levels also on Ctrl-C); it closes the document it opened.
#
# Media keys, key shortcuts and window snapping need Accessibility for your terminal app (System Settings → Privacy & Security →
# Accessibility). Haptics need a Force Touch trackpad; keep a finger resting on it to feel them.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d -t edgy-smoke-actions)"
trap 'rm -rf "$WORK"' EXIT

echo "Edgy actions smoke test"
echo "This will change real system state (and put it back). Build in $WORK."
read -r -p "Continue? [y/N] " answer
[[ "$answer" == [yY]* ]] || exit 0

# The package exposes no library product, so compile the modules straight from source.
swiftc -swift-version 6 -parse-as-library -emit-library -static -module-name EdgyCore \
  -emit-module -emit-module-path "$WORK/EdgyCore.swiftmodule" \
  -o "$WORK/libEdgyCore.a" "$ROOT"/Sources/EdgyCore/*.swift
swiftc -swift-version 6 -parse-as-library -emit-library -static -module-name Displays \
  -emit-module -emit-module-path "$WORK/Displays.swiftmodule" \
  -o "$WORK/libDisplays.a" "$ROOT"/Sources/Displays/*.swift
swiftc -swift-version 6 -parse-as-library -emit-library -static -module-name Actions -enable-testing \
  -I "$WORK" -emit-module -emit-module-path "$WORK/Actions.swiftmodule" \
  -o "$WORK/libActions.a" "$ROOT"/Sources/Actions/*.swift

cat >"$WORK/main.swift" <<'SWIFT'
import AppKit
import Displays
import EdgyCore
import Foundation

@testable import Actions

func ask(_ question: String) -> Bool {
  print("\n\(question) [y/N] ", terminator: "")
  return (readLine() ?? "").lowercased().hasPrefix("y")
}

/// Lets main-queue work (haptics, media keys) run, and the HUD stay up long enough to see.
func settle(_ seconds: Double = 0.6) { RunLoop.main.run(until: Date().addingTimeInterval(seconds)) }

func check(_ label: String, _ body: () throws -> Void) {
  do {
    try body()
    print("  ok: \(label)")
  } catch {
    print("  FAILED: \(label): \(error)")
  }
}

let audio = LiveAudioOutput()
let display = LiveBrightnessOutput()
let hud = LiveHUDOutput()
let haptics = LiveHapticOutput()
let keyboard = LiveKeyboardOutput()
let workspace = LiveWorkspaceOutput()
let windows = LiveWindowOutput()
let levelKeys = LiveLevelKeyOutput()
let backlight = LiveKeyboardBacklightOutput()
let registry = ActionRegistry(
  settings: .defaults, audio: audio, display: display, media: LiveMediaKeyOutput(), hud: hud,
  haptics: haptics, shortcuts: LiveShortcutRunner(), keyboard: keyboard, workspace: workspace,
  windows: windows, system: LiveSystemOutput(keyboard: keyboard), levelKeys: levelKeys,
  displays: makeLiveDisplayBrightness(), backlight: backlight, dictation: LiveDictationOutput(),
  waiter: LiveTransitionWaiter(), scheduler: LiveActionScheduler())
let priorBacklight = backlight.isAvailable ? try? backlight.level() : nil

// Snapshot everything we might touch.
let priorVolume = try? audio.outputVolume()
let priorMuted = try? audio.isOutputMuted()
let priorMicMuted = try? audio.isInputMuted()
let priorBrightness = display.isAvailable ? try? display.brightness() : nil
print("Before: volume \(priorVolume.map { String($0) } ?? "n/a"), muted \(priorMuted.map { String($0) } ?? "n/a"), "
  + "mic muted \(priorMicMuted.map { String($0) } ?? "n/a"), brightness \(priorBrightness.map { String($0) } ?? "n/a"), "
  + "headphones \(audio.outputIsHeadphones())")

@MainActor func restore() {
  if let priorVolume { try? audio.setOutputVolume(priorVolume) }
  if let priorMuted { try? audio.setOutputMuted(priorMuted) }
  if let priorMicMuted { try? audio.setInputMuted(priorMicMuted) }
  if let priorBrightness { try? display.setBrightness(priorBrightness) }
  if let priorBacklight { try? backlight.setLevel(priorBacklight) }
  print("\nRestored prior values.")
}

signal(SIGINT, SIG_IGN)
let sigint = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
sigint.setEventHandler { @MainActor in
  restore()
  exit(130)
}
sigint.resume()

let ctx = ActionContext(frontmostBundleID: nil, parameters: [:])
@MainActor func slide(_ id: ActionID, _ deltas: [Double]) throws {
  for (i, d) in deltas.enumerated() {
    let phase: GestureEvent.Phase = i == 0 ? .began : (i == deltas.count - 1 ? .ended : .changed)
    try registry.perform(id, input: .delta(d, phase: phase), context: ctx)
    settle(0.12)
  }
}
let up = [Double](repeating: 1.0 / 16, count: 3)
let down = [Double](repeating: -1.0 / 16, count: 3)

if ask("1. Nudge volume up 3 steps then back down (expect HUD + 6 haptic ticks)?") {
  check("volume slide") { try slide("audio.volume", up + down) }
  settle()
}
if ask("2. Toggle output mute twice (expect muted HUD, then unmuted)?") {
  check("mute on") { try registry.perform("audio.mute", input: .trigger, context: ctx) }
  settle(1.2)
  check("mute off") { try registry.perform("audio.mute", input: .trigger, context: ctx) }
  settle()
}
if ask("3. Toggle microphone mute twice?") {
  check("mic mute on") { try registry.perform("mic.mute", input: .trigger, context: ctx) }
  print("  mic muted now: \((try? audio.isInputMuted()).map { String($0) } ?? "n/a")")
  check("mic mute off") { try registry.perform("mic.mute", input: .trigger, context: ctx) }
}
if ask("4. Nudge brightness down 3 steps then back up (expect brightness HUD + ticks)?") {
  check("brightness slide") { try slide("display.brightness", down + up) }
  settle()
}
if ask("5. Send play/pause (start something playing first; you will be offered a second press)?") {
  check("play/pause") { try registry.perform("media.playPause", input: .trigger, context: ctx) }
  settle()
  if ask("   Did playback toggle? Press play/pause again to restore?") {
    check("play/pause") { try registry.perform("media.playPause", input: .trigger, context: ctx) }
    settle()
  }
}
if ask("6. Send next then previous track?") {
  check("next") { try registry.perform("media.next", input: .trigger, context: ctx) }
  settle(1.5)
  check("previous") { try registry.perform("media.previous", input: .trigger, context: ctx) }
  settle()
}
if ask("7. Show each HUD image directly (volume half, muted, brightness half)?") {
  hud.show(.volume(muted: false, headphones: false), level: 0.5)
  settle(1.5)
  hud.show(.volume(muted: true, headphones: false), level: 0)
  settle(1.5)
  hud.show(.brightness, level: 0.5)
  settle(1.5)
  print("  Did all three show the right icon? If not, note which (the image IDs live in LiveHUDOutput).")
}
if ask("8. Feel haptics: 8 ticks then one strong tick (rest a finger on the trackpad)?") {
  for _ in 0..<8 {
    haptics.tick(strength: 6)
    settle(0.15)
  }
  haptics.strongTick(strength: 6)
  settle()
}

@MainActor func fire(_ id: ActionID, _ parameters: [String: String] = [:]) {
  check(id.rawValue) {
    try registry.perform(id, input: .trigger, context: ActionContext(frontmostBundleID: nil, parameters: parameters))
  }
}

let textEdit = "com.apple.TextEdit"
let textEditWasRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: textEdit).isEmpty
var openedDocument = false
if ask("9. Open a fresh TextEdit document (app.open, then keyboard.shortcut cmd+n)?") {
  fire("app.open", ["bundleID": textEdit, "whenFrontmost": "stay"])
  settle(2.0)
  fire("keyboard.shortcut", ["keys": "cmd+n"])
  settle(1.0)
  openedDocument = true
  print("  Is a new, empty TextEdit window in front?")
}
if openedDocument, ask("10. Send cmd+b to it (bold toggles on; type a letter to see it)?") {
  fire("keyboard.shortcut", ["keys": "cmd+b"])
  settle(2.0)
  fire("keyboard.shortcut", ["keys": "cmd+b"])
  print("  Sent cmd+b twice (on, then off again).")
}
if ask("11. Snap the front window left, then right, then restore (needs Accessibility)?") {
  fire("window.leftHalf")
  settle(1.2)
  fire("window.rightHalf")
  settle(1.2)
  fire("window.restore")
  settle()
  print("  Did it fill the left half, the right half, then go back where it started?")
}
if ask("12. Slide-to-repeat: 4 presses of cmd+= then 4 of cmd+- in the front window (zoom in/out)?") {
  let zoom = ["upKeys": "cmd+=", "downKeys": "cmd+-"]
  for (i, d) in ([Double](repeating: 0.0625, count: 4) + [Double](repeating: -0.0625, count: 4)).enumerated() {
    let phase: GestureEvent.Phase = i == 0 ? .began : .changed
    check("slideSteps") {
      try registry.perform(
        "keyboard.slideSteps", input: .delta(d, phase: phase),
        context: ActionContext(frontmostBundleID: nil, parameters: zoom))
    }
    settle(0.25)
  }
}
if openedDocument, ask("13. Close the TextEdit document without saving (asks for Automation permission once)?") {
  let close = Process()
  close.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
  close.arguments = ["-e", "tell application id \"\(textEdit)\" to close front document saving no"]
  try? close.run()
  close.waitUntilExit()
  if !textEditWasRunning {
    for app in NSRunningApplication.runningApplications(withBundleIdentifier: textEdit) { app.terminate() }
  }
}
if ask("14. Open https://example.com in the default browser (close the tab yourself afterwards)?") {
  fire("url.open", ["url": "https://example.com"])
  settle(1.0)
}
if ask("15. Mission Control, App Windows and Show Desktop (each toggled on, then off again)?") {
  for id: ActionID in ["system.missionControl", "system.appWindows", "system.showDesktop"] {
    fire(id)
    settle(1.8)
    fire(id)
    settle(1.2)
  }
  print("  Did each one appear and then go away?")
}
if ask("16. Spaces: move one Space left, then back right (needs at least two Spaces and the system shortcuts on)?") {
  fire("spaces.left")
  settle(1.5)
  fire("spaces.right")
  settle(1.5)
  print("  If nothing moved, check Keyboard Shortcuts → Mission Control → Move left/right a space.")
}

// v0.3. Steps 1, 2 and 4 above already went through the native level keys (current system HUD);
// the steps below check the parts tests can't.
print("\n--- v0.3 ---")
if ask("17. Level keys: measure one fine volume step (4 fine presses up, read CoreAudio, 4 back down)?") {
  let before = (try? audio.outputVolume()) ?? -1
  check("4 fine volume-up presses") { try levelKeys.press(.volumeUp, count: 4, fine: true) }
  settle(0.8)
  let after = (try? audio.outputVolume()) ?? -1
  check("4 fine volume-down presses") { try levelKeys.press(.volumeDown, count: 4, fine: true) }
  settle(0.8)
  print(String(format: "  volume %.4f → %.4f: %.4f per fine press (expect ≈ 0.0156 = 1/64)", before, after, (after - before) / 4))
  print("  If it moved 0.0625 per press, the fine-step modifiers (shift+option) were ignored: note it in the done report.")
}
if ask("18. Volume HUD: slide volume up 3/16 and back with headphones or earbuds connected (expect the device's own HUD)?") {
  check("volume slide") { try slide("audio.volume", up + down) }
  settle()
  print("  Was it the current system HUD (device icon, smooth bar), not the old square overlay?")
}
if ask("19. App switcher: open it, move 2 apps right, 1 back, then select (cmd stays down until the end)?") {
  let switcher: ActionID = "apps.switcher"
  // The one-stroke switcher (keep-open off); step 29 tries the batch 20 session across strokes.
  // Batch 26: the first step of travel opens it, so it takes one more step than before.
  let ctx = ActionContext(frontmostBundleID: nil, parameters: ["keepOpenMS": "0", "step": "0.1"])
  check("switcher") {
    let strokes: [(Double, GestureEvent.Phase)] = [
      (0.0, .began), (0.1, .changed), (0.1, .changed), (0.1, .changed), (-0.1, .changed),
    ]
    for (delta, phase) in strokes {
      try registry.perform(switcher, input: .delta(delta, phase: phase), context: ctx)
      settle(0.5)
    }
    try registry.perform(switcher, input: .delta(0, phase: .ended), context: ctx)
  }
  settle()
  print("  Did the switcher open on the next app, step right twice, back once, and select on release?")
  print("  Then press any modifier key: nothing should feel stuck (command must be up).")
  if ask("   Now try a cancelled switch (opens, then escapes back without switching)?") {
    check("switcher cancel") {
      try registry.perform(switcher, input: .delta(0, phase: .began), context: ctx)
      try registry.perform(switcher, input: .delta(0.1, phase: .changed), context: ctx)
      settle(0.8)
      try registry.perform(switcher, input: .delta(0, phase: .cancelled), context: ctx)
    }
    settle()
  }
}
if ask("20. Hold a key for 3 s (push-to-talk). Set your dictation app's hold key first; enter it here:") {
  print("  Keys to hold (e.g. f13, ctrl+opt+space) [f13]: ", terminator: "")
  let typed = (readLine() ?? "").trimmingCharacters(in: .whitespaces)
  let keys = ["keys": typed.isEmpty ? "f13" : typed]
  let holdContext = ActionContext(frontmostBundleID: nil, parameters: keys)
  check("hold down") { try registry.perform("keyboard.hold", input: .press(down: true), context: holdContext) }
  settle(3.0)
  check("hold up") { try registry.perform("keyboard.hold", input: .press(down: false), context: holdContext) }
  settle()
  print("  Did the dictation app listen for 3 s and stop on release? Nothing should feel stuck afterwards.")
}
if ask("21. macOS Dictation: start, wait 4 s, stop (needs Dictation on, shortcut = microphone key)?") {
  fire("system.dictation")
  settle(4.0)
  fire("system.dictation")
  settle()
  print("  Did the Dictation microphone appear and then go away? If not, note the Dictation shortcut setting.")
}
if backlight.isAvailable, ask("22. Keyboard backlight: slide down to off and back up, then toggle off and on?") {
  print("  backlight now: \((try? backlight.level()).map { String(format: "%.2f", $0) } ?? "n/a")")
  check("backlight slide") { try slide("keyboard.backlight", [Double](repeating: -0.25, count: 4) + up) }
  settle()
  fire("keyboard.backlightToggle")
  settle(1.2)
  fire("keyboard.backlightToggle")
  settle()
  print("  Did it dim to off, come back up, go off, then return to the same level?")
} else if !backlight.isAvailable {
  print("\n22. Skipped: no backlit keyboard found (expected on a desktop Mac).")
}
if ask("23. Full-screen snap: put a window in full screen within 6 s; it should leave full screen, snap left, then restore?") {
  settle(6.0)
  fire("window.leftHalf")
  settle(3.0)
  fire("window.restore")
  settle()
  print("  Did it leave full screen, land on the left half, then go back to its normal (not full-screen) frame?")
}
// v0.4: modifier-only hold, the hold watchdog, and the picker models.

/// Result of async work, filled from a background task while the main run loop keeps spinning
/// (the key recorder's event tap is on the main run loop).
final class Box<T>: @unchecked Sendable {
  private let lock = NSLock()
  private var stored: T?
  var value: T? {
    get { lock.lock(); defer { lock.unlock() }; return stored }
    set { lock.lock(); stored = newValue; lock.unlock() }
  }
}

@MainActor func waitFor<T: Sendable>(_ seconds: Double, _ work: @escaping @Sendable () async -> T) -> T? {
  let box = Box<T>()
  Task.detached { box.value = await work() }
  let deadline = Date().addingTimeInterval(seconds)
  while box.value == nil, Date() < deadline { settle(0.05) }
  return box.value
}

if ask("24. fn-only push-to-talk: hold fn for 3 s (set your dictation app's hold key to fn first)?") {
  let fnOnly = ActionContext(frontmostBundleID: nil, parameters: ["keys": "fn"])
  check("fn down") { try registry.perform("keyboard.hold", input: .press(down: true), context: fnOnly) }
  settle(3.0)
  check("fn up") { try registry.perform("keyboard.hold", input: .press(down: false), context: fnOnly) }
  settle()
  print("  Did the dictation app listen for 3 s and stop on release? If it did nothing, it may read fn")
  print("  from the hardware layer (below synthetic events): note the app and its setting in the done report.")
  print("  Also try ctrl+opt here if your app offers it: re-run step 20 with ctrl+opt.")
}
if ask("25. Hold watchdog: hold fn with maxSeconds 5 and never release (expect release after 5 s)?") {
  let watched = ActionContext(frontmostBundleID: nil, parameters: ["keys": "fn", "maxSeconds": "5"])
  check("fn down (no up will be sent)") {
    try registry.perform("keyboard.hold", input: .press(down: true), context: watched)
  }
  settle(7.0)
  print("  Did the dictation app stop by itself after ~5 s? Edgy logs \"hold: no release after 5.0 s\":")
  print("  /usr/bin/log show --last 1m --predicate 'subsystem == \"com.garavit.edgy\"' --info")
  check("late up is harmless") {
    try registry.perform("keyboard.hold", input: .press(down: false), context: watched)
  }
}
if ask("26. Key recorder: press a combo, a bare key, or press and release fn alone (15 s; escape cancels)?") {
  let recorder = makeLiveKeyComboRecorder()
  let states = waitFor(16) { () async -> [KeyRecorderState] in
    var seen: [KeyRecorderState] = []
    for await state in recorder.start(timeout: 15) {
      print("  state: \(state)")
      seen.append(state)
    }
    return seen
  }
  switch states?.last {
  case .recorded(let combo)?: print("  Recorded: \(combo)  (does it match what you pressed?)")
  case .unavailable(let reason)?: print("  Unavailable: \(reason) (grant Input Monitoring to your terminal app)")
  case let other?: print("  Ended: \(other)")
  case nil: print("  FAILED: the recorder never finished")
  }
}
if ask("27. Installed apps: list them (count, first 10, running ones)?") {
  let provider = makeLiveInstalledAppsProvider()
  let started = Date()
  if let apps = waitFor(30, { await provider.installedApps() }) {
    print("  \(apps.count) apps in \(String(format: "%.2f", Date().timeIntervalSince(started))) s")
    for app in apps.prefix(10) { print("    \(app.name)  \(app.bundleID)  \(app.isRunning ? "running" : "")") }
    print("  running: \(apps.filter(\.isRunning).map(\.name).joined(separator: ", "))")
    print("  Any app missing or listed twice?")
  } else {
    print("  FAILED: no answer within 30 s")
  }
}
if ask("28. Shortcuts: list your Shortcuts through the shortcuts command?") {
  let listing = makeLiveShortcutsListing()
  if let list = waitFor(15, { await listing.shortcuts() }) {
    if let failure = list.failure { print("  failure: \(failure)") }
    print("  \(list.names.count) shortcuts: \(list.names.prefix(15).joined(separator: " | "))")
    print("  Do names with spaces or emoji look right?")
  } else {
    print("  FAILED: no answer within 15 s")
  }
}
// Batch 20: the shared slide feel. Motions are synthesized at 120 Hz on a 100 mm zone.
@MainActor func stroke(
  _ id: ActionID, mm: Double, speed: Double, _ parameters: [String: String], restAtEnd: Double = 0
) throws {
  let frame = 1.0 / 120.0
  var time = Date().timeIntervalSinceReferenceDate
  func send(_ deltaMM: Double, _ phase: GestureEvent.Phase, atEnd: Int = 0) throws {
    let context = ActionContext(
      frontmostBundleID: nil, parameters: parameters,
      motion: SlideMotion(deltaMM: deltaMM, timestamp: time, atEnd: atEnd))
    try registry.perform(id, input: .delta(deltaMM / 100, phase: phase), context: context)
  }
  try send(0, .began)
  let perFrame = speed * frame * (mm < 0 ? -1 : 1)
  for _ in 0..<Int(abs(mm) / abs(perFrame)) {
    time += frame
    try send(perFrame, .changed)
    settle(frame)
  }
  for _ in 0..<Int(restAtEnd / frame) {
    time += frame
    try send(0, .changed, atEnd: mm < 0 ? -1 : 1)
    settle(frame)
  }
  try send(0, .ended)
}
if ask("29. Short-stroke switching: open 8+ apps first. Five short 6 mm strokes, 0.25 s apart (keep-open 400 ms)?") {
  check("short strokes") {
    for index in 0..<5 {
      // Batch 26: the first stroke also travels the 8 mm that open the switcher.
      try stroke("apps.switcher", mm: index == 0 ? 14 : 6, speed: 60, ["speedUp": "off"])
      settle(0.25)
    }
  }
  settle(1.0)
  print("  Did one switcher stay open across all five strokes (no flicker) and move about 3-4 apps,")
  print("  then pick the app about 0.4 s after the last stroke? Command must be up afterwards.")
  if ask("   Again, but click the mouse during the pause after the 3rd stroke (it should pick at once)?") {
    check("click selects") {
      for index in 0..<3 {
        try stroke("apps.switcher", mm: 9, speed: 60, ["speedUp": "off", "keepOpenMS": "1000"])
        if index < 2 { settle(0.25) }
      }
      print("  Click now (you have 1 s)…")
      settle(1.2)
    }
    print("  Did it pick the app on the click, not later? Same check moving the pointer instead of clicking.")
  }
}
if ask("30. Flick speed: the same 24 mm slowly (40 mm/s), then as a quick flick (400 mm/s)?") {
  check("slow") { try stroke("apps.switcher", mm: 24, speed: 40, ["keepOpenMS": "0"]) }
  settle(1.0)
  check("flick") { try stroke("apps.switcher", mm: 24, speed: 400, ["keepOpenMS": "0"]) }
  settle(1.0)
  print("  Slow should open on the next app and move 2 more; the flick clearly more (up to 9). Did the flick feel proportionate?")
}
if ask("31. End stepping: slide 9 mm then rest at the end for 2 s (expect a click, then ~10 more apps)?") {
  check("end stepping") { try stroke("apps.switcher", mm: 9, speed: 60, ["keepOpenMS": "0"], restAtEnd: 2) }
  settle(1.0)
  print("  Did it pause briefly, then step faster and steadily (about 6 apps/s), with a stronger click at the start?")
  print("  On the real pad: slide to the very end of the edge and stop; it should keep going until you move or lift.")
}
if ask("32. Push-to-talk while pointing (by hand): bind Hold Keys to a corner, hold it, then move the pointer with another finger?") {
  print("  Run Edgy with Hold Keys on a corner (holdMS 300). Hold the corner with your thumb; after it starts,")
  print("  move the pointer with your index finger for a few seconds. Expect: the keys stay down, the pointer")
  print("  moves freely, and the keys come up only when the thumb lifts. A click while holding still lets go.")
}
if ask("33. Does fn reach your dictation app? Hold fn through Hold Keys for 3 s with the app set to fn?") {
  let fnContext = ActionContext(frontmostBundleID: nil, parameters: ["keys": "fn"])
  check("fn down") { try registry.perform("keyboard.hold", input: .press(down: true), context: fnContext) }
  settle(3.0)
  check("fn up") { try registry.perform("keyboard.hold", input: .press(down: false), context: fnContext) }
  settle()
  print("  Did the app listen while fn was held? If not, set the app to a non-fn key (e.g. right option or")
  print("  ctrl+opt+space) and note it in the done report: synthetic fn may not reach every app.")
}
if ask("34. Switch Apps opens on travel, never on contact: rest, tap, a short nudge (nothing), then one step (opens)?") {
  // Batch 26. Each part waits so you can see that nothing flashes.
  check("rest") {
    var time = Date().timeIntervalSinceReferenceDate
    func send(_ phase: GestureEvent.Phase) throws {
      let context = ActionContext(
        frontmostBundleID: nil, parameters: ["speedUp": "off"],
        motion: SlideMotion(deltaMM: 0, timestamp: time, atEnd: 0))
      try registry.perform("apps.switcher", input: .delta(0, phase: phase), context: context)
    }
    try send(.began)
    settle(1.5)
    time += 1.5
    try send(.ended)
  }
  settle(1.0)
  check("tap") {
    let context = ActionContext(frontmostBundleID: nil, parameters: ["speedUp": "off"])
    try registry.perform("apps.switcher", input: .delta(0, phase: .began), context: context)
    settle(0.04)
    try registry.perform("apps.switcher", input: .delta(0, phase: .cancelled), context: context)
  }
  settle(1.0)
  check("short nudge") { try stroke("apps.switcher", mm: 5, speed: 60, ["speedUp": "off"]) }
  settle(1.0)
  print("  So far: did NOTHING open or flash (rest 1.5 s, a tap, a 5 mm nudge)?")
  check("one step") { try stroke("apps.switcher", mm: 8, speed: 60, ["speedUp": "off"]) }
  settle(1.0)
  print("  Did the switcher open on the next app with the one 8 mm step, and pick it about 0.4 s later?")
  print("  On the real pad: rest a finger on the switcher edge, tap it, nudge it; only a real slide opens it.")
}
print("\nNot run here: system.lockScreen and system.sleepDisplay (they end the session). Bind them and try by hand.")

restore()
SWIFT

swiftc -swift-version 6 -I "$WORK" -L "$WORK" -lActions -lDisplays -lEdgyCore \
  -o "$WORK/smoke-actions" "$WORK/main.swift"
"$WORK/smoke-actions"
