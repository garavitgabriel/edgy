import Actions
import EdgyCore
import EdgyRuntime
import Foundation
import Observation
import Testing

@testable import EdgyUI

/// Batch 28: the mirror's data is computed once per revision, never per body evaluation, and a
/// resting finger (identical frames) tells no observing view anything changed.
@MainActor @Suite struct Batch28MirrorTests {
  @Test func mirrorDataIsComputedOnceForManyBodyEvaluationsAtOneRevision() throws {
    let model = PreviewFixtures.model()
    let first = model.mirrorZones(forApp: nil)
    let cache = model.mirrorData
    let catalogBuilds = cache.catalogComputations
    let zoneBuilds = cache.zoneComputations
    for _ in 0..<50 {
      #expect(model.mirrorZones(forApp: nil) == first)
      _ = model.mirrorCatalog
      _ = model.mirrorGroups
      _ = model.mirrorAvailability(of: BuiltInAction.brightness)
    }
    #expect(cache.catalogComputations == catalogBuilds)
    #expect(cache.zoneComputations == zoneBuilds)

    // A real change (a new revision) computes again, once.
    try model.editor.setProfileDisabled(true, for: .app(PreviewFixtures.wayfare))
    _ = model.mirrorZones(forApp: nil)
    _ = model.mirrorZones(forApp: nil)
    #expect(cache.catalogComputations == catalogBuilds + 1)
    #expect(cache.zoneComputations == zoneBuilds + 1)
  }

  @Test func cachedMirrorDataMatchesTheEditor() {
    let model = PreviewFixtures.model()
    #expect(model.mirrorGroups == model.editor.catalogByCategory)
    for id in model.mirrorCatalog.keys {
      #expect(model.mirrorAvailability(of: id) == model.editor.availability(of: id))
    }
  }

  @Test func identicalFramesProduceNoObservationChange() {
    let model = PreviewFixtures.model()
    let device = model.mirroredDevice?.id ?? 0
    let touch = LiveTouch(id: 1, position: Point2D(x: 0.5, y: 0.5), state: .down)
    let frame = LiveTouchFrame(deviceID: device, timestamp: 1, touches: [touch])
    model.simulate(LiveFeedUpdate(touches: frame, decisions: []))
    let changed = ChangeFlag()
    withObservationTracking {
      _ = model.liveTouches
      _ = model.pendingDecisions
      _ = model.mirrorZones(forApp: nil)
    } onChange: {
      changed.set()
    }
    for step in 2..<20 {
      var same = frame
      same.timestamp = TimeInterval(step)
      model.simulate(LiveFeedUpdate(touches: same, decisions: []))
      _ = model.takeDecisions()
    }
    #expect(!changed.value)
  }
}

final class ChangeFlag: @unchecked Sendable {
  private let lock = NSLock()
  private var flag = false
  var value: Bool { lock.withLock { flag } }
  func set() { lock.withLock { flag = true } }
}
