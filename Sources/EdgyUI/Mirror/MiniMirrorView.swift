import AppKit
import EdgyCore
import EdgyRuntime
import SwiftUI

/// The popover's mini mirror: zones of the active profile and the last touch where it landed (bone 10).
///
/// Same drawing as `PadMirrorView` at `Tokens.miniMirrorPointsPerMM`, with no labels and no
/// clicks. It keeps the last frame of touches after the finger lifts, so the last touch stays
/// where it was. States: no trackpad (dashed outline at the default proportion with "No trackpad
/// connected", no zones), paused, disabled, off in the frontmost app (faded to 40%; the popover
/// says the words).
///
/// **Active profile.** `MiniMirrorView(model:)` follows `model.frontmostBundleID` (set by the app
/// on activation, never Edgy's own) and draws `effectiveBindings(forApp:)` for it, which is Default
/// for an app without a profile. `MiniMirrorView(model:frontmostApp:)` pins the app instead (tests,
/// previews, or a host that already knows it). It reads `model.revision`, so edits made in
/// Settings show at once.
public struct MiniMirrorView: View {
  @Bindable var model: SettingsModel
  /// `nil` = follow the frontmost app; `.some(app)` = pinned (`.some(nil)` = Default).
  let pinnedApp: String??
  @State private var lastTouches: [LiveTouch] = []
  @State private var hovered: Zone?
  @State private var lastKnownSize: Size2D?
  /// The host already fades the mirror for these states (the popover applies its one 40%), so
  /// the mirror doesn't fade again (one fade only).
  var hostFades = false
  /// The hover line's width, when wider than the mirror (the popover's content width).
  var lineWidth: CGFloat?

  /// The same mirror, leaving the 40% fade to the host (the popover).
  func fadedByHost() -> MiniMirrorView {
    var copy = self
    copy.hostFades = true
    return copy
  }

  /// Follows the frontmost app: the mirror shows the profile in effect right now.
  public init(model: SettingsModel) {
    self.model = model
    pinnedApp = nil
  }

  /// The mini mirror for the profile in effect while `frontmostApp` is in front (`nil` = Default).
  public init(model: SettingsModel, frontmostApp: String?) {
    self.model = model
    pinnedApp = .some(frontmostApp)
  }

  /// Snapshots: open with `zone` hovered (the hover line showing).
  func hovering(_ zone: Zone?) -> MiniMirrorView {
    var copy = self
    copy._hovered = State(initialValue: zone)
    return copy
  }

  /// Bone 10's hover line: the short zone name, a colon, its actions as a comma list ("Bottom:
  /// Previous Track, Next Track, Play/Pause"). Empty with no hover, or over a zone with nothing
  /// mapped. The first form of `hoverLineForms`.
  static func hoverLine(_ zone: MirrorZone?) -> String {
    hoverLineForms(zone).first ?? ""
  }

  /// The line as it fits `width` (critique 22, design answer 1): the full action names, else the
  /// pad-tab short names (bone 3); `HoverLine` fades the last form only when even that overflows.
  static func hoverLine(_ zone: MirrorZone?, width: CGFloat) -> String {
    let forms = hoverLineForms(zone)
    return forms.first { !HoverLine.overflows($0, width: width) } ?? forms.last ?? ""
  }

  /// Every form of the hover line, longest first: full names, then the pad tabs' short names.
  static func hoverLineForms(_ zone: MirrorZone?) -> [String] {
    guard let zone, zone.style == .mapped, !zone.actionNames.isEmpty else { return [] }
    let name = shortZoneName(zone.zone)
    var full: [String] = []
    for name in zone.actionNames where !full.contains(name) { full.append(name) }
    let forms = [
      "\(name): \(full.joined(separator: ", "))", "\(name): \(shortActionNames(zone).joined(separator: ", "))",
    ]
    return forms.enumerated().filter { index, form in !forms[..<index].contains(form) }.map(\.element)
  }

  /// The hover line's zone name (design answer 1): "Bottom", "Left", "Top-left", "Right, upper",
  /// "Bottom, left", "Right, quarter 2".
  static func shortZoneName(_ zone: Zone) -> String {
    switch zone {
    case .corner(let corner):
      let title = ZoneNaming.cornerName(corner)
      return title.hasSuffix(" corner") ? String(title.dropLast(" corner".count)) : title
    case .edge(let edge, let segment, let segments):
      let base = ZoneNaming.edgeName(edge)
      guard segments > 1 else { return base }
      let part = ZoneNaming.part(edge: edge, segment: segment, segments: segments)
      let short =
        segments == 4
        ? part.components(separatedBy: " of ").first ?? part : part.components(separatedBy: " ").first ?? part
      return "\(base), \(short)"
    }
  }

  /// The zone's actions by the pad tabs' short names: a pair reads as one word ("Tracks"), and
  /// the bone-3 short names stand in ("Mic off", "Shortcut").
  static func shortActionNames(_ zone: MirrorZone) -> [String] {
    let ids = Set(zone.actions)
    var names: [String] = []
    var consumed = Set<ActionID>()
    for (id, name) in zip(zone.actions, zone.actionNames) where !consumed.contains(id) {
      var word = ZoneLabel.shortNames[id] ?? name
      if let pair = ZoneLabel.pairs.first(where: { $0.0 == id || $0.1 == id }), ids.contains(pair.0),
        ids.contains(pair.1)
      {
        consumed.formUnion([pair.0, pair.1])
        word = pair.2
      }
      if !names.contains(word) { names.append(word) }
    }
    return names
  }

  /// The popover sets the hover line to its full content width (design answer 1); elsewhere the
  /// line is as wide as the mirror.
  func hoverLineWidth(_ width: CGFloat) -> MiniMirrorView {
    var copy = self
    copy.lineWidth = width
    return copy
  }

  /// The last touch where it landed (bone 10): the frame kept after a lift is the last non-empty one.
  static func remembered(after frame: [LiveTouch], previous: [LiveTouch]) -> [LiveTouch] {
    frame.isEmpty ? previous : frame
  }

  /// What the mirror draws: the live fingers, or, once they lift, the last frame where they landed.
  static func shown(live: [LiveTouch], last: [LiveTouch]) -> [LiveTouch] {
    live.isEmpty ? last : live
  }

  /// The app whose profile the mirror draws.
  /// Unpinned, it is `model.frontmostBundleID` (set by the app on activation, never Edgy itself), the
  /// same source the popover chips read, so the mirror and the chips always agree.
  var activeApp: String? { pinnedApp ?? model.frontmostBundleID }

  /// The frontmost app after an activation: Edgy's own activation (opening its window or
  /// popover) keeps the app that was in front before.
  static func frontmost(afterActivating activated: String?, own: String?, previous: String?) -> String? {
    guard let activated, activated != own else { return previous }
    return activated
  }

  public var body: some View {
    let _ = model.revision  // redraw on every settings change, wherever it was made
    let frontmostApp = activeApp
    let state = model.mirrorState(forApp: frontmostApp)
    let device = model.mirroredDevice
    let sizeMM =
      state == .noTrackpad
      ? MirrorGeometry.defaultSensorSizeMM
      : device?.sensorSizeMM ?? model.lastKnownPadSizeMM ?? lastKnownSize ?? MirrorGeometry.defaultSensorSizeMM
    let geometry = MirrorGeometry(
      sensorSizeMM: sizeMM, settings: model.editor.config.gestures, pointsPerMM: Tokens.miniMirrorPointsPerMM)
    let zones = model.mirrorZones(forApp: frontmostApp, unavailableAsUnmapped: true)
    let mapped = Set(zones.filter { $0.style == .mapped }.map(\.zone))
    let hoverWidth = max(lineWidth ?? 0, geometry.size.width)
    let hoveredZone = hovered.flatMap { zone in zones.first { $0.zone == zone } }
    // Centred: the mirror sits in the middle of the popover, so a line as wide as the popover's
    // content lines up with its edges.
    VStack(alignment: .center, spacing: 6) {
      ZStack {
        MirrorPad(
          geometry: geometry, zones: zones, selected: nil,
          touches: device == nil ? [] : Self.shown(live: model.liveTouches, last: lastTouches),
          faded: state.faded && !hostFades, dashedOutline: state == .noTrackpad, showsLabels: false,
          message: state == .noTrackpad ? MirrorMessage(text: MirrorCopy.noTrackpadMini) : nil,
          zoneIcons: true, onHoverZone: { hovered = $0 }
        )
        .id(device?.id)
        .transition(.opacity)
      }
      .animation(MirrorMotion.padSwitch, value: device?.id)
      HoverLine(text: Self.hoverLine(hoveredZone, width: hoverWidth), width: hoverWidth)
    }
    .onChange(of: model.liveTouches, initial: true) { _, new in
      // Remember only frames with a zone touch: a lifted pointer touch never lingers (bone 2).
      let drawn = MirrorPad.drawnTouches(new, geometry: geometry, mapped: mapped)
      lastTouches = Self.remembered(after: drawn, previous: lastTouches)
    }
    .onChange(of: device, initial: true) { old, new in
      if let new { lastKnownSize = new.sensorSizeMM }
      if old?.id != new?.id { lastTouches = [] }
    }
  }
}

/// One line under the mini mirror (13, `ink2`). Its height is always reserved, so the popover never
/// jumps; a line too long for the width clips with the 12 pt fade (bone 10).
struct HoverLine: View {
  var text: String
  /// The mirror's width, or the popover's content width: the line never runs past it.
  var width: CGFloat

  static let height: CGFloat = 16

  /// Whether `text` is wider than `width` at 13 pt (then its end fades over 12 pt).
  static func overflows(_ text: String, width: CGFloat) -> Bool {
    let font = NSFont.systemFont(ofSize: Tokens.typeBody)
    return (text as NSString).size(withAttributes: [.font: font]).width > width
  }

  var body: some View {
    let fade = Self.overflows(text, width: width)
    Text(text.isEmpty ? " " : text)
      .font(Tokens.font(Tokens.typeBody)).foregroundStyle(Tokens.ink2)
      .lineLimit(1).fixedSize()
      .frame(width: width, height: Self.height, alignment: .leading)
      .clipped()
      .mask(
        LinearGradient(
          stops: [
            .init(color: .black, location: 0),
            .init(color: .black, location: fade ? max(0, 1 - MirrorPad.labelFade / max(width, 1)) : 1),
            .init(color: fade ? .clear : .black, location: 1),
          ], startPoint: .leading, endPoint: .trailing)
      )
      .accessibilityHidden(text.isEmpty)
  }
}

/// A static mini mirror of a config's Default profile, for onboarding's preset cards (render S7,
/// "a 120 pt mini mirror showing that preset's zones"). Normal zone shapes; no labels, icons,
/// touches or clicks.
public struct PresetMirrorView: View {
  let config: EdgyConfig
  let sensorSizeMM: Size2D
  let width: CGFloat

  public init(config: EdgyConfig, sensorSizeMM: Size2D? = nil, width: CGFloat = 120) {
    self.config = config
    self.sensorSizeMM = sensorSizeMM ?? MirrorGeometry.defaultSensorSizeMM
    self.width = width
  }

  public var body: some View {
    let rows = config.defaultProfile.bindings.filter { $0.action != .doNothing }.map {
      EffectiveBinding(binding: $0, source: .inherited, defaultBinding: $0)
    }
    MirrorPad(
      geometry: MirrorGeometry(
        sensorSizeMM: sensorSizeMM, settings: config.gestures, pointsPerMM: width / sensorSizeMM.width),
      zones: MirrorContent.zones(rows: rows, catalog: [:]), selected: nil, showsLabels: false, showsIcons: false)
  }
}
