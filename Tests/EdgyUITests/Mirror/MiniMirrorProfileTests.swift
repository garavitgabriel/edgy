import EdgyCore
import EdgyRuntime
import Foundation
import SwiftUI
import Testing

@testable import EdgyUI

// MARK: Mini mirror active profile and pad switching

@MainActor @Test func miniMirrorFollowsTheFrontmostAppButNotEdgyItself() {
  let own = "com.example.edgyhost"
  #expect(
    MiniMirrorView.frontmost(afterActivating: PreviewFixtures.wayfare, own: own, previous: nil)
      == PreviewFixtures.wayfare)
  // Opening Edgy's own popover or window keeps the app that was in front.
  #expect(
    MiniMirrorView.frontmost(afterActivating: own, own: own, previous: PreviewFixtures.wayfare)
      == PreviewFixtures.wayfare)
  #expect(
    MiniMirrorView.frontmost(afterActivating: nil, own: own, previous: PreviewFixtures.huddle) == PreviewFixtures.huddle
  )
  let model = PreviewFixtures.model()
  #expect(MiniMirrorView(model: model, frontmostApp: PreviewFixtures.wayfare).activeApp == PreviewFixtures.wayfare)
  #expect(MiniMirrorView(model: model, frontmostApp: nil).activeApp == nil)
  // The following initializer observes; nothing is observed before it appears.
  #expect(MiniMirrorView(model: model).activeApp == nil)
}

@MainActor @Test func miniMirrorDrawsTheActiveProfilesZones() {
  let model = PreviewFixtures.model()
  let wayfare = Dictionary(
    uniqueKeysWithValues: model.mirrorZones(forApp: PreviewFixtures.wayfare).map { ($0.zone, $0) })
  #expect(wayfare[.corner(.bottomRight)]?.style == .mapped)  // the app-only hold
  #expect(wayfare[.edge(.left)]?.style == .offHere)  // turned off in Wayfare: drawn as unmapped
  // An app without a profile gets Default.
  #expect(model.mirrorZones(forApp: "com.example.noprofile") == model.mirrorZones(forApp: nil))
  #expect(model.mirrorState(forApp: PreviewFixtures.huddle).faded)
}

@MainActor @Test func padSwitchCrossFadesIn150ms() {
  #expect(MirrorMotion.padSwitchSeconds == 0.15)
  let model = PreviewFixtures.model()
  model.simulate(
    EngineStatus(running: true, enabled: true, devices: [PreviewFixtures.externalPad, PreviewFixtures.builtInPad]))
  #expect(model.mirroredDevice == PreviewFixtures.externalPad)
  model.simulate(MirrorFixtures.touch(0.5, 0.5, .down, device: PreviewFixtures.builtInPad.id))
  #expect(model.mirroredDevice == PreviewFixtures.builtInPad)
}
