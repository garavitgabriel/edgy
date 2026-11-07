import AppKit
import EdgyCore
import EdgyRuntime
import Foundation
import SwiftUI
import Testing

@testable import EdgyUI

/// Batch 21: label shortening (bone 3), tab + zone as one shape, one fade.
@MainActor
struct Batch21MirrorTests {
  func pad(_ model: SettingsModel, ppm: CGFloat = Tokens.mirrorPointsPerMM) -> MirrorPad {
    MirrorPad(
      geometry: MirrorGeometry(
        sensorSizeMM: PreviewFixtures.externalPad.sensorSizeMM, settings: model.editor.config.gestures,
        pointsPerMM: ppm), zones: model.mirrorZones(forApp: nil), selected: nil)
  }

  // MARK: Label shortening

  @Test func shorterFormsGoParameterValueThenShortNameAndNeverEllipsis() {
    let catalog = PreviewFixtures.model().mirrorCatalog
    let zone = Zone.edge(.bottom, segment: 1, segments: 4)
    let shortcut = Binding(
      zone: zone, gesture: .doubleTap, action: "keyboard.shortcut", parameters: ["keys": "ctrl+opt+space"])
    #expect(ZoneLabel.text(for: [shortcut], catalog: catalog) == "Keyboard Shortcut")
    // (a) the parameter's short value, (b) is not needed when (a) exists.
    #expect(ZoneLabel.shorterForms(for: [shortcut], catalog: catalog) == ["⌃⌥ Space"])
    // No value yet: the short name keeps the "needs a parameter" ellipsis, nothing else gets one.
    let empty = Binding(zone: zone, gesture: .doubleTap, action: "keyboard.shortcut")
    #expect(ZoneLabel.shorterForms(for: [empty], catalog: catalog) == ["Shortcut…"])
    let app = Binding(zone: zone, gesture: .tap, action: "app.open", parameters: ["bundleID": "com.example.quillpad"])
    #expect(ZoneLabel.shorterForms(for: [app], catalog: catalog) == ["Quillpad"])
    let file = Binding(zone: zone, gesture: .tap, action: "file.open", parameters: ["path": "~/Notes/Plans.md"])
    if catalog["file.open"] != nil {
      #expect(ZoneLabel.shorterForms(for: [file], catalog: catalog).first == "Plans.md")
    }
    let mic = Binding(zone: .corner(.topLeft), gesture: .doubleTap, action: "mic.mute")
    #expect(ZoneLabel.shorterForms(for: [mic], catalog: catalog) == ["Mic off"])
  }

  @Test func fitPicksTheFirstFormThatFitsElseClipsTheLastWithoutEllipsis() {
    let forms = ["Keyboard Shortcut, Next Track and Play / Pause", "⌘ Left, Next Track and Play / Pause"]
    let wide = MirrorPad.fit(forms, room: 1000)
    #expect(wide == MirrorPad.FittedLabel(text: forms[0], clipWidth: nil))
    let middle = MirrorPad.fit(forms, room: MirrorPad.textWidth(forms[1]) + 1)
    #expect(middle == MirrorPad.FittedLabel(text: forms[1], clipWidth: nil))
    let narrow = MirrorPad.fit(forms, room: 60)
    #expect(narrow.text == forms[1])
    #expect(narrow.clipWidth == 60)
    #expect(!narrow.text.hasSuffix("…"))
    #expect(MirrorPad.labelFade == 12)
  }

  @Test func aQuarterBarClipsItsLongLabelInsteadOfEndingInAnEllipsis() {
    var config = EdgyConfig.defaults
    config.defaultProfile.bindings.removeAll { $0.zone == .edge(.bottom) }
    let part = Zone.edge(.bottom, segment: 1, segments: 4)
    config.defaultProfile.bindings += [
      Binding(zone: part, gesture: .swipe(.left), action: "keyboard.shortcut", parameters: ["keys": "cmd+left"]),
      Binding(zone: part, gesture: .swipe(.right), action: "media.next"),
      Binding(zone: part, gesture: .doubleTap, action: "media.playPause"),
    ]
    let model = PreviewFixtures.model(config: config)
    let mirror = pad(model)
    let zone = try! #require(model.mirrorZones(forApp: nil).first { $0.zone == part })
    let fitted = mirror.fittedLabel(zone, placement: mirror.labelPlacement(zone))
    #expect(fitted.clipWidth != nil)
    #expect(!fitted.text.contains("…"))
    #expect(fitted.text.hasPrefix("⌘ Left"))
  }

  // MARK: Tab and zone as one shape

  @Test func cornerTabStartsInsideTheTileAndSitsFlushUnderIt() {
    let model = PreviewFixtures.model()
    let mirror = pad(model)
    for corner in Zone.Corner.allCases {
      let zone = MirrorZone(zone: .corner(corner), style: .mapped, label: "Mute", overridden: false, symbol: nil)
      let tile = mirror.geometry.shapeFrame(for: zone.zone)
      let placement = mirror.labelPlacement(zone)
      #expect(!placement.inBar)
      // The tab's start is inside the tile's x span, past its rounded corner.
      #expect(placement.point.x > tile.minX + mirror.tileRadius(tile) - 0.01)
      #expect(placement.point.x < tile.maxX - mirror.tileRadius(tile) + 0.01)
      // The tab's top (or bottom) edge overlaps the tile's edge: no gap, no corner-only touch.
      switch corner {
      case .topLeft, .topRight: #expect(placement.point.y < tile.maxY && placement.point.y > tile.maxY - 4)
      case .bottomLeft, .bottomRight: #expect(placement.point.y > tile.minY && placement.point.y < tile.minY + 4)
      }
      // The tab clears the side strip's bar.
      let side = mirror.geometry.shapeFrame(for: .edge(corner == .topLeft || corner == .bottomLeft ? .left : .right))
      if corner == .topLeft || corner == .bottomLeft {
        #expect(placement.point.x >= side.maxX)
      } else {
        #expect(placement.point.x <= side.minX)
      }
    }
  }

  @Test func tabUnionIsOneOutlineCoveringTabAndZone() {
    // A corner tile and a tab overlapping it by 2 pt (as `labelPlacement` lays them out).
    let tile = CGRect(x: 0, y: -30, width: 31, height: 31)
    let tab = CGRect(x: 20, y: 0, width: 70, height: 24)
    let union = TabUnion(zone: tile.offsetBy(dx: -tab.minX, dy: 0), zoneRadius: 7, tabRadius: 7)
    let path = union.cgPath(tab: CGRect(origin: .zero, size: tab.size))
    // Covers the tile's middle, the tab's middle, and the joint between them (no notch).
    #expect(path.contains(CGPoint(x: tile.midX - tab.minX, y: tile.midY)))
    #expect(path.contains(CGPoint(x: tab.width / 2, y: tab.height / 2)))
    #expect(path.contains(CGPoint(x: tile.maxX - tab.minX - 2, y: 0.5)))
    // One closed outline: the ring around it is one band, outside both shapes.
    let ring = TabUnionRing(union: union, gap: 1.5, width: 2).path(in: CGRect(origin: .zero, size: tab.size))
    #expect(!ring.contains(CGPoint(x: tab.width / 2, y: tab.height / 2)))
    #expect(ring.contains(CGPoint(x: tab.width / 2, y: tab.height + 2.5)))
  }

  @Test func sideTabsAndCornersAreDrawnWithTheirTabTopAndBottomInTheBar() {
    let model = PreviewFixtures.model()
    let mirror = pad(model)
    let zones = Dictionary(uniqueKeysWithValues: model.mirrorZones(forApp: nil).map { ($0.zone, $0) })
    #expect(mirror.isTabbed(zones[.edge(.right)]!))
    #expect(mirror.isTabbed(zones[.corner(.topLeft)]!))
    #expect(!mirror.isTabbed(zones[.edge(.bottom)]!))
    // An unmapped zone has no label, so no tab.
    #expect(!mirror.isTabbed(zones[.edge(.top)]!))
    // "Off here" is a tab too (hairline outline, no fill).
    let wayfare = Dictionary(
      uniqueKeysWithValues: model.mirrorZones(forApp: PreviewFixtures.wayfare).map { ($0.zone, $0) })
    #expect(mirror.isTabbed(wayfare[.edge(.left)]!))
    // Mirrors without labels draw every tile themselves.
    var mini = mirror
    mini.showsLabels = false
    #expect(!mini.isTabbed(zones[.corner(.topLeft)]!))
  }

  @Test func presetCornerRadiusIsCappedSoTilesStaySquare() {
    let model = PreviewFixtures.model()
    let preset = pad(model, ppm: 120 / 160)
    let tile = preset.geometry.shapeFrame(for: .corner(.topLeft))
    #expect(preset.tileRadius(tile) <= tile.width * 0.3 + 0.001)
    #expect(pad(model).tileRadius(pad(model).geometry.shapeFrame(for: .corner(.topLeft))) == Tokens.radiusControl)
  }

  @Test func shadowFallsBelowTheSlabOnly() {
    for full in [true, false] {
      let layers = MirrorPad.shadowLayers(full: full)
      #expect(!layers.isEmpty)
      #expect(layers.allSatisfy { $0.offset > 0 && $0.inset > 0 && $0.opacity < 0.1 })
    }
  }

  // MARK: Unavailable actions

  @Test func unavailableActionMarksTheTabAndTheMiniMirrorDrawsItUnmapped() {
    var config = PreviewFixtures.demoConfig
    config.defaultProfile.bindings.append(
      Binding(zone: .corner(.bottomLeft), gesture: .doubleTap, action: "keyboard.backlightToggle"))
    let model = InspectorFixtures.model(config: config)
    let full = model.mirrorZones(forApp: nil).first { $0.zone == .corner(.bottomLeft) }
    #expect(full?.style == .mapped)
    #expect(full?.unavailable == true)
    let mini = model.mirrorZones(forApp: nil, unavailableAsUnmapped: true).first { $0.zone == .corner(.bottomLeft) }
    #expect(mini?.style == .unmapped)
    #expect(mini?.label == nil)
  }

  // MARK: One fade

  @Test func miniMirrorLeavesTheFadeToItsHost() {
    let model = PreviewFixtures.model()
    let plain = MiniMirrorView(model: model, frontmostApp: nil)
    #expect(!plain.hostFades)
    #expect(plain.fadedByHost().hostFades)
  }

  @Test func popoverFadesOnceForDisabledPausedAndOffInFront() {
    var config = PreviewFixtures.demoConfig
    config.app.enabled = false
    let state = MenuBarState()
    #expect(PopoverMirror.resolve(state: state, model: PreviewFixtures.model(config: config)).faded)
    let paused = PreviewFixtures.model()
    paused.simulate(
      EngineStatus(
        running: true, paused: true, pausedUntil: Date().addingTimeInterval(600), enabled: true,
        devices: [PreviewFixtures.externalPad]))
    #expect(PopoverMirror.resolve(state: state, model: paused).faded)
    state.frontmostBundleID = PreviewFixtures.huddle
    #expect(PopoverMirror.resolve(state: state, model: PreviewFixtures.model()).faded)
    state.frontmostBundleID = PreviewFixtures.wayfare
    #expect(!PopoverMirror.resolve(state: state, model: PreviewFixtures.model()).faded)
  }

  @Test func windowStatesFadeTheMountedMirrorAndDrawTheLine() {
    let model = PreviewFixtures.model()
    let paused = WindowStatus.resolve(
      conditions: .normal,
      engine: EngineStatus(
        running: true, paused: true, pausedUntil: nil, enabled: true, devices: [PreviewFixtures.externalPad]),
      config: model.editor.config, tab: .default)
    #expect(paused.fadesMirror)
    #expect(paused.padLine == .paused(until: nil))
    // App off and Disabled: the mirror fades itself (one fade), the window adds none.
    #expect(model.mirrorState(forApp: PreviewFixtures.huddle, includesPaused: false).faded)
    var config = PreviewFixtures.demoConfig
    config.app.enabled = false
    #expect(PreviewFixtures.model(config: config).mirrorState(forApp: nil, includesPaused: false) == .disabled)
    #expect(MirrorPad.fadedOpacity == 0.4)
  }
}
