import EdgyCore
import EdgyRuntime
import Foundation
import Gestures
import SwiftUI
import Testing

@testable import EdgyUI

// MARK: Fixtures

/// The two preview pad sizes, nonisolated so they can be `@Test` arguments.
let externalPadMM = Size2D(width: 160, height: 115)
let builtInPadMM = Size2D(width: 134, height: 87)

@MainActor
enum MirrorFixtures {
  static let pad = PreviewFixtures.externalPad

  /// Default, with the bottom edge split into 2 and the right edge into 3.
  static var splitConfig: EdgyConfig {
    var config = EdgyConfig.defaults
    config.defaultProfile.bindings.removeAll {
      if case .edge(let edge, _, _) = $0.zone { return edge == .bottom || edge == .right }
      return false
    }
    config.defaultProfile.bindings += [
      Binding(zone: .edge(.bottom, segment: 0, segments: 2), gesture: .swipe(.left), action: "media.previous"),
      Binding(zone: .edge(.bottom, segment: 0, segments: 2), gesture: .swipe(.right), action: "media.next"),
      Binding(zone: .edge(.bottom, segment: 1, segments: 2), gesture: .doubleTap, action: "media.playPause"),
      Binding(zone: .edge(.right, segment: 0, segments: 3), gesture: .slide, action: "audio.volume"),
      Binding(zone: .edge(.right, segment: 2, segments: 3), gesture: .doubleTap, action: "system.showDesktop"),
    ]
    return config
  }

  static func touch(_ x: Double, _ y: Double, _ state: LiveTouch.State, device: UInt64 = pad.id) -> LiveFeedUpdate {
    LiveFeedUpdate(
      touches: LiveTouchFrame(
        deviceID: device, timestamp: 1, touches: [LiveTouch(id: 1, position: Point2D(x: x, y: y), state: state)]),
      decisions: [])
  }

  static func noTrackpad(_ model: SettingsModel) {
    model.simulate(EngineStatus(running: true, enabled: true, devices: []))
  }

  static func paused(_ model: SettingsModel, device: TouchDeviceInfo = pad) {
    model.simulate(
      EngineStatus(
        running: true, paused: true, pausedUntil: Date().addingTimeInterval(47 * 60 - 5), enabled: true,
        devices: [device]))
  }

  static func disabledConfig() -> EdgyConfig {
    var config = PreviewFixtures.demoConfig
    config.app.enabled = false
    return config
  }

  static func allZones(segments: Int) -> [Zone] {
    Zone.Edge.allCases.flatMap { edge in (0..<segments).map { Zone.edge(edge, segment: $0, segments: segments) } }
      + Zone.Corner.allCases.map { Zone.corner($0) }
  }
}

// MARK: Geometry agrees with PadLayout

@MainActor @Test(arguments: [externalPadMM, builtInPadMM], [1, 2, 3, 4])
func zoneFramesArePadLayoutScaledAndFlipped(sizeMM: Size2D, segments: Int) {
  let settings = GestureSettings.defaults
  let ppm = Tokens.mirrorPointsPerMM
  let geometry = MirrorGeometry(sensorSizeMM: sizeMM, settings: settings, pointsPerMM: ppm)
  let layout = PadLayout(sensorSizeMM: sizeMM, settings: settings)
  let height = layout.sensorSizeMM.height
  for zone in MirrorFixtures.allZones(segments: segments) {
    let mm = layout.rect(for: zone)
    let frame = geometry.frame(for: zone)
    #expect(abs(frame.minX - mm.x * ppm) < 0.001)
    #expect(abs(frame.minY - (height - mm.y - mm.height) * ppm) < 0.001)
    #expect(abs(frame.width - mm.width * ppm) < 0.001)
    #expect(abs(frame.height - mm.height * ppm) < 0.001)
  }
}

@MainActor @Test(arguments: [externalPadMM, builtInPadMM])
func mirrorIsToScale(sizeMM: Size2D) {
  let geometry = MirrorGeometry(sensorSizeMM: sizeMM, settings: .defaults, pointsPerMM: Tokens.mirrorPointsPerMM)
  #expect(abs(geometry.size.width - sizeMM.width * Tokens.mirrorPointsPerMM) < 0.001)
  #expect(abs(geometry.size.height - sizeMM.height * Tokens.mirrorPointsPerMM) < 0.001)
  let mini = MirrorGeometry(
    sensorSizeMM: sizeMM, settings: .defaults, pointsPerMM: Tokens.miniMirrorPointsPerMM)
  #expect(abs(mini.size.width / mini.size.height - geometry.size.width / geometry.size.height) < 0.0001)
}

@MainActor @Test(arguments: [1, 2, 3, 4])
func drawnBarsSitInsideTheirZoneAndClearTheCornerTiles(segments: Int) {
  let geometry = MirrorGeometry(
    sensorSizeMM: PreviewFixtures.externalPad.sensorSizeMM, settings: .defaults, pointsPerMM: Tokens.mirrorPointsPerMM)
  for zone in MirrorFixtures.allZones(segments: segments) {
    let shape = geometry.shapeFrame(for: zone)
    #expect(geometry.frame(for: zone).insetBy(dx: -0.001, dy: -0.001).contains(shape))
    #expect(shape.width > 0 && shape.height > 0)
    if case .edge = zone {
      for corner in Zone.Corner.allCases {
        #expect(!shape.intersects(geometry.shapeFrame(for: .corner(corner))))
      }
    }
  }
}

@MainActor @Test func touchMappingFlipsNormalizedOriginBottomLeftToPoints() {
  let geometry = MirrorGeometry(
    sensorSizeMM: PreviewFixtures.externalPad.sensorSizeMM, settings: .defaults, pointsPerMM: Tokens.mirrorPointsPerMM)
  let size = geometry.size
  #expect(geometry.point(forNormalized: Point2D(x: 0, y: 0)) == CGPoint(x: 0, y: size.height))
  #expect(geometry.point(forNormalized: Point2D(x: 1, y: 1)) == CGPoint(x: size.width, y: 0))
  let p = geometry.point(forNormalized: Point2D(x: 0.5, y: 0.25))
  #expect(abs(p.x - size.width / 2) < 0.001 && abs(p.y - size.height * 0.75) < 0.001)
  // A touch high on the right edge lands inside the right edge's drawn frame, near its top.
  let right = geometry.frame(for: .edge(.right))
  let high = geometry.point(forNormalized: Point2D(x: 0.98, y: 0.8))
  #expect(right.contains(high) && high.y < right.midY)
}

@MainActor @Test func liveZoneIsTheRecognizersAnswer() {
  let device = PreviewFixtures.builtInPad
  let geometry = MirrorGeometry(
    sensorSizeMM: device.sensorSizeMM, settings: .defaults, pointsPerMM: Tokens.mirrorPointsPerMM)
  let layout = PadLayout(sensorSizeMM: device.sensorSizeMM, settings: .defaults)
  let mapped: Set<Zone> = [.edge(.right), .corner(.topLeft), .edge(.bottom, segment: 1, segments: 2)]
  for (x, y) in [(0.98, 0.5), (0.01, 0.99), (0.75, 0.02), (0.25, 0.02), (0.5, 0.5)] {
    let mm = Point2D(x: x * device.sensorSizeMM.width, y: y * device.sensorSizeMM.height)
    #expect(geometry.zone(atNormalized: Point2D(x: x, y: y), mapped: mapped) == layout.zone(atMM: mm, mapped: mapped))
  }
  #expect(geometry.zone(atNormalized: Point2D(x: 0.98, y: 0.5), mapped: mapped) == .edge(.right))
}

// MARK: Label rule

@MainActor @Test func previewPadSizesMatchTheFixtures() {
  #expect(externalPadMM == PreviewFixtures.externalPad.sensorSizeMM)
  #expect(builtInPadMM == PreviewFixtures.builtInPad.sensorSizeMM)
}

/// The catalog's own spelling of Play/Pause (the UI follows it, whatever it is).
@MainActor func playPause(_ model: SettingsModel) -> String {
  model.mirrorCatalog["media.playPause"]?.displayName ?? "?"
}

@MainActor @Test func defaultLabelsReadAsInTheRender() throws {
  let model = PreviewFixtures.model()
  let zones = Dictionary(uniqueKeysWithValues: model.mirrorZones(forApp: nil).map { ($0.zone, $0) })
  // Names are the catalog's, never re-spelled (batch-14 ruling 6).
  #expect(zones[.edge(.bottom)]?.label == "Tracks and \(playPause(model))")
  #expect(zones[.edge(.right)]?.label == "Volume")
  #expect(zones[.edge(.left)]?.label == "Brightness")
  // The full name, and on the pad's corner tab its short name, as in render A (bone 3 rule (b)).
  #expect(zones[.corner(.topLeft)]?.label == "Microphone Mute")
  let pad = MirrorPad(
    geometry: MirrorGeometry(
      sensorSizeMM: PreviewFixtures.externalPad.sensorSizeMM, settings: .defaults,
      pointsPerMM: Tokens.mirrorPointsPerMM), zones: Array(zones.values), selected: nil)
  let micOff = try #require(zones[.corner(.topLeft)])
  #expect(pad.fittedLabel(micOff, placement: pad.labelPlacement(micOff)).text == "Mic off")
  #expect(zones[.corner(.topRight)]?.label == "Mute")
  #expect(zones[.corner(.topRight)]?.symbol == ActionID("audio.mute"))
  #expect(zones[.edge(.top)]?.style == .unmapped)
  #expect(zones[.corner(.bottomLeft)]?.style == .unmapped)
}

@MainActor @Test func labelRuleOrdersPairsDedupesJoinsAndMarksMissingParameters() {
  let catalog = PreviewFixtures.model().mirrorCatalog
  let zone = Zone.edge(.top)
  let text = ZoneLabel.text(
    for: [
      Binding(zone: zone, gesture: .doubleTap, action: "system.missionControl"),
      Binding(zone: zone, gesture: .swipe(.right), action: "spaces.right"),
      Binding(zone: zone, gesture: .tap, action: "system.missionControl"),
      Binding(zone: zone, gesture: .swipe(.left), action: "spaces.left"),
      Binding(zone: zone, gesture: .longPress, action: "keyboard.shortcut"),
    ], catalog: catalog)
  #expect(text == "Spaces, Mission Control and Keyboard Shortcut…")
  #expect(ZoneLabel.joined(["A"]) == "A")
  #expect(ZoneLabel.joined(["A", "B"]) == "A and B")
  // A lone member of a pair keeps its own name.
  #expect(
    ZoneLabel.text(for: [Binding(zone: zone, gesture: .swipe(.right), action: "media.next")], catalog: catalog)
      == "Next Track")
}

// MARK: Selection

@MainActor @Test func clickingAZoneSelectsItAndLeavesThePickerAlone() {
  let model = PreviewFixtures.model()
  model.selectZone(.edge(.right))
  #expect(model.selectedZone == .edge(.right))
  #expect(model.picking == nil)
  model.selectZone(.corner(.bottomLeft))
  #expect(model.selectedZone == .corner(.bottomLeft))
}

// MARK: App profiles and system states

@MainActor @Test func appTabShowsEffectiveBindingsWithSourceMarks() {
  let model = PreviewFixtures.model()
  let zones = Dictionary(
    uniqueKeysWithValues: model.mirrorZones(forApp: PreviewFixtures.wayfare).map { ($0.zone, $0) })
  let bottom = zones[.edge(.bottom)]
  #expect(bottom?.overridden == true)
  // Before the target ruling (BRIEF § Bindings that name their target, batch 29: the target is the primary text):
  // #expect(bottom?.label == "Keyboard Shortcut, Next Track and \(playPause(model))")
  #expect(bottom?.label == "⇧⌘ [, Next Track and \(playPause(model))")
  #expect(zones[.edge(.left)]?.style == .offHere)
  #expect(zones[.edge(.left)]?.label == "Off here")
  #expect(zones[.edge(.right)]?.overridden == false)
  #expect(zones[.corner(.bottomRight)]?.style == .mapped)
  #expect(zones[.corner(.bottomRight)]?.overridden == false)
  // Before the target ruling: #expect(zones[.corner(.bottomRight)]?.label == "Hold Keys")
  #expect(zones[.corner(.bottomRight)]?.label == "fn")
  // Default shows no marks.
  #expect(!model.mirrorZones(forApp: nil).contains { $0.overridden || $0.style == .offHere })
}

@MainActor @Test func appOffDrawsEveryZoneAsAHairlineAndLeavesTheLineToTheWindow() {
  let model = PreviewFixtures.model()
  let huddle = PreviewFixtures.huddle
  #expect(model.mirrorZones(forApp: huddle).allSatisfy { $0.style == .unmapped && $0.label == nil })
  #expect(model.mirrorState(forApp: huddle) == .appOff("Huddle"))
  #expect(MirrorState.appOff("Huddle").faded)
  // The window writes "Edgy is off in Huddle · Turn on" around the mirror; the mirror doesn't repeat it.
  #expect(PadMirrorView.message(for: .appOff("Huddle")) == nil)
  try? model.editor.setProfileDisabled(false, for: .app(huddle))
  #expect(model.mirrorState(forApp: huddle) == .normal)
  #expect(model.mirrorZones(forApp: huddle).contains { $0.style == .mapped })
}

@MainActor @Test func systemStatesFollowThePrecedence() {
  let model = PreviewFixtures.model(config: MirrorFixtures.disabledConfig())
  #expect(model.mirrorState(forApp: nil) == .disabled)
  #expect(model.mirrorState(forApp: PreviewFixtures.huddle) == .appOff("Huddle"))
  MirrorFixtures.paused(model)
  #expect(model.mirrorState(forApp: PreviewFixtures.huddle) == .paused("Paused, 47 min left"))
  // The settings window draws paused itself, so the big mirror skips it.
  #expect(model.mirrorState(forApp: nil, includesPaused: false) == .disabled)
  #expect(PadMirrorView.message(for: .paused("Paused, 47 min left")) == nil)
  #expect(PadMirrorView.message(for: .noTrackpad) == MirrorMessage(text: "Connect a trackpad to see it here."))
  MirrorFixtures.noTrackpad(model)
  #expect(model.mirroredDevice == nil)
  #expect(model.mirrorState(forApp: nil) == .noTrackpad)
  #expect(!MirrorState.noTrackpad.faded && MirrorState.disabled.faded)
}

@MainActor @Test func pausedCopyCountsWholeMinutes() {
  let now = Date()
  #expect(MirrorCopy.paused(until: now.addingTimeInterval(47 * 60), now: now) == "Paused, 47 min left")
  #expect(MirrorCopy.paused(until: now.addingTimeInterval(46 * 60 + 1), now: now) == "Paused, 47 min left")
  #expect(MirrorCopy.paused(until: now.addingTimeInterval(59), now: now) == "Paused, less than a minute left")
  #expect(MirrorCopy.paused(until: nil, now: now) == "Paused")
}

@MainActor @Test func splitEdgesDrawAsSeparateSegments() {
  let model = PreviewFixtures.model(config: MirrorFixtures.splitConfig)
  let zones = Dictionary(uniqueKeysWithValues: model.mirrorZones(forApp: nil).map { ($0.zone, $0) })
  #expect(zones[.edge(.bottom, segment: 0, segments: 2)]?.label == "Tracks")
  #expect(zones[.edge(.bottom, segment: 1, segments: 2)]?.label == playPause(model))
  #expect(zones[.edge(.right, segment: 0, segments: 3)]?.label == "Volume")
  #expect(zones[.edge(.right, segment: 1, segments: 3)]?.style == .unmapped)
  #expect(zones[.edge(.right, segment: 2, segments: 3)]?.label == "Show Desktop")
  #expect(zones[.edge(.bottom)] == nil && zones[.edge(.right)] == nil)
  #expect(zones.count == 4 + 2 + 3 + 2)
}

@MainActor @Test func contactMarksFollowTouchState() {
  #expect(ContactMark(.claimed) == .recognized)
  #expect(ContactMark(.rejected) == .rejected)
  #expect(ContactMark(.down) == .down)
}

@MainActor @Test func labelsAreJoinedToTheirZone() {
  let geometry = MirrorGeometry(
    sensorSizeMM: PreviewFixtures.externalPad.sensorSizeMM, settings: .defaults, pointsPerMM: Tokens.mirrorPointsPerMM)
  let pad = MirrorPad(geometry: geometry, zones: [], selected: nil)
  func zone(_ z: Zone) -> MirrorZone { MirrorZone(zone: z, style: .mapped, label: "x", overridden: false, symbol: nil) }
  // Side tabs start inside the bar (overlap, no gap) on its inner side.
  let left = pad.labelPlacement(zone(.edge(.left)))
  #expect(left.anchor == .leading && left.point.x < geometry.shapeFrame(for: .edge(.left)).maxX)
  let right = pad.labelPlacement(zone(.edge(.right)))
  #expect(right.anchor == .trailing && right.point.x > geometry.shapeFrame(for: .edge(.right)).minX)
  // Top/bottom labels sit inside the bar.
  let bottom = pad.labelPlacement(zone(.edge(.bottom)))
  #expect(bottom.inBar && geometry.shapeFrame(for: .edge(.bottom)).contains(bottom.point))
  // Corner tabs touch their tile.
  let tile = geometry.shapeFrame(for: .corner(.topLeft))
  let corner = pad.labelPlacement(zone(.corner(.topLeft)))
  #expect(corner.point.y < tile.maxY && corner.point.x < tile.maxX)
}
