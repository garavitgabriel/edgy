import EdgyCore
import Foundation
import Testing

@testable import Gestures

// Replays every real recording in `Fixtures/traces/*.json` (see `scripts/record-traces.md`)
// through the shipped pipeline. A known label gets its scenario's assertion; any trace also gets
// the invariants (deterministic, holds paired, nothing left claimed). A label may end in a
// device suffix (`-external`, `-builtin`) so the same scenario can be recorded on each trackpad.
// Traces carry no typing signal, so typing suppression never helps here: the other gates must hold.

enum RecordedTraces {
  enum Expect {
    /// No gesture, no claim.
    case nothing
    /// A slide claimed in the edge, net motion with this sign (+1 toward top/right).
    case slide(Zone.Edge, sign: Double)
    /// Exactly these discrete gestures, in this zone (slide events ignored).
    case discrete(Zone, [GestureKind])
    /// One hold: began, then ended at lift.
    case hold(Zone)
    /// No long-press at all.
    case noHold
    /// A slide may be claimed and let go, but produces no output and nothing else fires.
    case noOutput
    /// With a double-tap bound in this zone (taps wait for the window), exactly these discrete
    /// gestures, in this zone, after flushing at the end of the trace.
    case waitingTaps(Zone, [GestureKind])
  }

  /// Hold scenarios bind a long-press where the preset has none.
  static let holdZones: Set<Zone> = [.corner(.topLeft), .corner(.bottomLeft)]

  static let expectations: [String: Expect] = [
    "deliberate-slide-right-up": .slide(.right, sign: 1),
    "deliberate-slide-left-down": .slide(.left, sign: -1),
    "palm-rest-right": .nothing,
    "palm-rest-left-while-typing": .nothing,
    "two-finger-scroll-near-right-edge": .nothing,
    "system-swipe-in-from-right": .nothing,
    "drift-into-right-edge": .nothing,
    "double-tap-top-right-corner": .discrete(.corner(.topRight), [.tap, .doubleTap]),
    "single-tap-bottom-edge": .discrete(.edge(.bottom), [.tap]),
    "swipe-bottom-edge-left": .discrete(.edge(.bottom), [.swipe(.left)]),
    "long-press-top-left-corner": .hold(.corner(.topLeft)),
    // v0.3 additions (batch 9 adversarial scenarios).
    "thumb-rest-bottom-index-moves": .nothing,
    "thumb-rest-right-index-moves": .noOutput,
    "two-finger-scroll-drift-into-right-edge": .nothing,
    "three-finger-swipe-from-right-edge": .nothing,
    "four-finger-swipe-up-from-bottom": .nothing,
    "three-finger-swipe-sideways-low": .nothing,
    "palm-land-left-while-typing": .nothing,
    "inward-swipe-from-right-one-finger": .nothing,
    "long-press-drift-top-left": .noHold,
    "push-to-talk-hold-bottom-left": .hold(.corner(.bottomLeft)),
    // v0.4 additions (batch 10: physical clicks, taps that wait for a double-tap).
    "click-drag-right-edge": .nothing,
    "click-drag-left-edge": .nothing,
    "click-drag-top-edge": .nothing,
    "click-drag-bottom-edge": .nothing,
    "click-top-right-corner": .nothing,
    "force-click-top-left-corner": .noHold,
    "tap-then-double-tap-top-right": .waitingTaps(.corner(.topRight), [.tap, .doubleTap]),
  ]

  /// Recording-condition suffixes, stripped (in any order, stacked) to find the scenario.
  static let deviceSuffixes = ["-external", "-builtin", "-taptoclick"]

  static func scenario(for label: String) -> String {
    var label = label
    while let suffix = deviceSuffixes.first(where: { label.hasSuffix($0) }) {
      label = String(label.dropLast(suffix.count))
    }
    return label
  }

  static var directory: URL {
    URL(fileURLWithPath: #filePath).deletingLastPathComponent()  // Tests/GesturesTests
      .deletingLastPathComponent().deletingLastPathComponent()  // repo root
      .appendingPathComponent("Fixtures/traces")
  }

  static func files() -> [URL] {
    let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
    return urls.filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
  }

  static func run(_ trace: TraceFile) -> Replay {
    replay(
      trace.frames, device: trace.device, zones: Preset.zones.union(holdZones), slideZones: Preset.slideZones,
      longPressZones: holdZones)
  }

  /// Checks one trace, recording an issue for each way it misbehaves.
  static func check(_ trace: TraceFile, sourceLocation: SourceLocation = #_sourceLocation) {
    let run = Self.run(trace)
    let again = Self.run(trace)
    let name = trace.label
    #expect(run.events == again.events, "\(name): not deterministic", sourceLocation: sourceLocation)
    #expect(run.endsUnclaimed, "\(name): still claimed at the end", sourceLocation: sourceLocation)
    expectHoldsArePaired(run, sourceLocation: sourceLocation)
    guard let expect = expectations[scenario(for: name)] else { return }
    switch expect {
    case .nothing:
      #expect(run.events.isEmpty, "\(name): \(run.events.map(\.kind))", sourceLocation: sourceLocation)
      #expect(run.neverClaimed, "\(name): claimed", sourceLocation: sourceLocation)
    case .slide(let edge, let sign):
      let slide = run.slideEvents.filter { if case .edge(edge, _, _) = $0.zone { true } else { false } }
      #expect(slide.first?.phase == .began, "\(name): no slide began", sourceLocation: sourceLocation)
      let net = slide.map(\.delta).reduce(0, +)
      #expect(net * sign > 0.05, "\(name): net slide \(net)", sourceLocation: sourceLocation)
    case .discrete(let zone, let kinds):
      let discrete = run.events.filter { $0.kind != .slide }
      #expect(discrete.map(\.kind) == kinds, "\(name): \(discrete.map(\.kind))", sourceLocation: sourceLocation)
      #expect(discrete.allSatisfy { $0.zone == zone }, "\(name): wrong zone", sourceLocation: sourceLocation)
    case .hold(let zone):
      let holds = run.events.filter { $0.kind == .longPress }
      #expect(holds.map(\.phase) == [.began, .ended], "\(name): \(holds.map(\.phase))", sourceLocation: sourceLocation)
      #expect(holds.allSatisfy { $0.zone == zone }, "\(name): wrong zone", sourceLocation: sourceLocation)
    case .noOutput:
      #expect(run.changed.isEmpty, "\(name): slide output", sourceLocation: sourceLocation)
      #expect(run.events.allSatisfy { $0.kind == .slide }, "\(name): fired", sourceLocation: sourceLocation)
    case .noHold:
      #expect(!run.events.contains { $0.kind == .longPress }, "\(name): held", sourceLocation: sourceLocation)
    case .waitingTaps(let zone, let kinds):
      let recognizer = makeGestureRecognizer()
      let waiting = replay(
        trace.frames, device: trace.device, zones: Preset.zones.union(holdZones).union([zone]),
        slideZones: Preset.slideZones, longPressZones: holdZones, doubleTapZones: [zone], recognizer: recognizer)
      // A recording stops getting frames after the last lift: wake the recognizer as the engine would.
      let end = (trace.frames.last?.timestamp ?? 0) + 1
      let tail = (recognizer as? DeferredGestureFlushing)?.flush(now: end).events ?? []
      let discrete = (waiting.events + tail).filter { $0.kind != .slide }
      #expect(discrete.map(\.kind) == kinds, "\(name): \(discrete.map(\.kind))", sourceLocation: sourceLocation)
      #expect(discrete.allSatisfy { $0.zone == zone }, "\(name): wrong zone", sourceLocation: sourceLocation)
    }
  }
}

@Test func recordedTracesReplayAsExpected() throws {
  for url in RecordedTraces.files() {
    RecordedTraces.check(try TraceFile.load(from: url))
  }
}

/// The checker itself, against synthetic stand-ins for a few recording labels, so a broken table
/// can't pass silently while `Fixtures/traces/` is empty.
@Test func recordedTraceCheckerAcceptsSyntheticStandIns() {
  func trace(_ label: String, _ strokes: [Stroke], buttons: [ClosedRange<Double>] = []) -> TraceFile {
    var builder = TraceBuilder(strokes)
    builder.buttonDown = buttons
    return builder.trace(label: label, expectation: "synthetic stand-in")
  }
  let standIns = [
    trace("deliberate-slide-right-up", [Stroke(id: 1, [(0, 146, 30), (0.15, 146, 30), (0.75, 146, 60)])]),
    trace("deliberate-slide-left-down-external", [Stroke(id: 1, [(0, 4, 70), (0.15, 4, 70), (0.75, 4, 40)])]),
    trace("drift-into-right-edge", [Stroke(id: 1, [(0, 100, 50), (0.4, 147, 55)])]),
    trace(
      "double-tap-top-right-corner",
      [Stroke(id: 1, [(0, 146, 90), (0.08, 146, 90)]), Stroke(id: 2, [(0.2, 146.3, 89.8), (0.28, 146.3, 89.8)])]),
    trace("swipe-bottom-edge-left", [Stroke(id: 1, [(0, 90, 3), (0.08, 60, 3)])]),
    trace("long-press-top-left-corner", [Stroke(id: 1, [(0, 4, 91), (1.5, 4, 91)])]),
    trace("push-to-talk-hold-bottom-left-builtin", [Stroke(id: 1, [(0, 4, 4), (1.5, 4, 4)])]),
    trace("long-press-drift-top-left", [Stroke(id: 1, [(0, 5, 90), (0.9, 7.2, 89)])]),
    trace(
      "thumb-rest-right-index-moves",
      [Stroke(id: 1, [(0, 146, 20), (1.4, 146, 20)]), Stroke(id: 2, [(0.4, 80, 50), (0.5, 80, 50), (1.2, 110, 65)])]),
    trace(
      "click-drag-right-edge", [Stroke(id: 1, [(0, 146, 30), (0.15, 146, 30), (0.75, 146, 60)])],
      buttons: [0.05...0.75]),
    trace(
      "click-top-right-corner-taptoclick-external", [Stroke(id: 1, [(0, 146, 90), (0.15, 146, 90)])],
      buttons: [0.04...0.1]),
    trace("force-click-top-left-corner", [Stroke(id: 1, [(0, 4, 91), (1.2, 4, 91)])], buttons: [0.3...1.2]),
    trace(
      "tap-then-double-tap-top-right",
      [
        Stroke(id: 1, [(0, 146, 90), (0.08, 146, 90)]),
        Stroke(id: 2, [(1.0, 146, 90), (1.08, 146, 90)]),
        Stroke(id: 3, [(1.2, 146, 90), (1.28, 146, 90)]),
      ]),
  ]
  for standIn in standIns {
    #expect(RecordedTraces.expectations[RecordedTraces.scenario(for: standIn.label)] != nil, "\(standIn.label)")
    RecordedTraces.check(standIn)
  }
}
