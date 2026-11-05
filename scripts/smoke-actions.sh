#!/usr/bin/env bash
# Manual smoke test for the live action outputs. HUMAN-RUN ONLY — never from CI or an agent.
#
# It changes real volume, mute, brightness, media playback, the HUD and haptics, asking before
# each step and restoring prior values at the end (also on Ctrl-C).
#
# Media keys need Accessibility for your terminal app (System Settings → Privacy & Security →
# Accessibility). Haptics need a Force Touch trackpad; keep a finger resting on it to feel them.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d -t edgy-smoke-actions)"
trap 'rm -rf "$WORK"' EXIT

echo "Edgy actions smoke test"
echo "This will change real system state (and put it back). Build in $WORK."
read -r -p "Continue? [y/N] " answer
[[ "$answer" == [yY]* ]] || exit 0

# The package exposes no library product, so compile the two modules straight from source.
swiftc -swift-version 6 -parse-as-library -emit-library -static -module-name EdgyCore \
  -emit-module -emit-module-path "$WORK/EdgyCore.swiftmodule" \
  -o "$WORK/libEdgyCore.a" "$ROOT"/Sources/EdgyCore/*.swift
swiftc -swift-version 6 -parse-as-library -emit-library -static -module-name Actions -enable-testing \
  -I "$WORK" -emit-module -emit-module-path "$WORK/Actions.swiftmodule" \
  -o "$WORK/libActions.a" "$ROOT"/Sources/Actions/*.swift

cat >"$WORK/main.swift" <<'SWIFT'
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
let registry = ActionRegistry(
  settings: .defaults, audio: audio, display: display, media: LiveMediaKeyOutput(), hud: hud,
  haptics: haptics, shortcuts: LiveShortcutRunner())

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
    haptics.tick()
    settle(0.15)
  }
  haptics.strongTick()
  settle()
}

restore()
SWIFT

swiftc -swift-version 6 -I "$WORK" -L "$WORK" -lActions -lEdgyCore \
  -o "$WORK/smoke-actions" "$WORK/main.swift"
"$WORK/smoke-actions"
