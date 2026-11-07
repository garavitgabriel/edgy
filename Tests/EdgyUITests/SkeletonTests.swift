import EdgyCore
import EdgyRuntime
import SwiftUI
import Testing

@testable import EdgyUI

@MainActor @Test func previewModelBuildsWithTheRealCatalog() {
  let model = PreviewFixtures.model()
  #expect(model.editor.catalogByCategory.flatMap(\.actions).count >= 33)
  #expect(model.mirroredDevice == PreviewFixtures.externalPad)
  #expect(model.editor.config.appProfiles.count == 2)
}

@MainActor @Test func snapshotHarnessWritesLightAndDark() throws {
  let urls = try Snapshot.write(
    PlateView(mark: .recognized, title: "Volume 64%", detail: "Right edge, slide").padding(20),
    folder: "skeleton", name: "plate")
  #expect(urls.count == 2)
  for url in urls { #expect(FileManager.default.fileExists(atPath: url.path)) }
}

@MainActor @Test func modelFollowsThePadTouchedLast() {
  let model = PreviewFixtures.model()
  model.simulate(
    EngineStatus(
      running: true, enabled: true, devices: [PreviewFixtures.externalPad, PreviewFixtures.builtInPad]))
  model.simulate(
    LiveFeedUpdate(
      touches: LiveTouchFrame(
        deviceID: PreviewFixtures.builtInPad.id, timestamp: 1,
        touches: [LiveTouch(id: 1, position: Point2D(x: 0.9, y: 0.5), state: .claimed)]),
      decisions: []))
  #expect(model.mirroredDevice == PreviewFixtures.builtInPad)
  #expect(model.liveTouches.count == 1)
}
