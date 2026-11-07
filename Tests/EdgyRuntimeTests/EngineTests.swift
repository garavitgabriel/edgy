import EdgyCore
import Foundation
import Testing

@testable import EdgyRuntime

/// Engine tests drive a private serial queue and flush it after every emit, so they stay synchronous.
final class EngineHarness {
  let queue = DispatchQueue(label: "engine-tests")
  let touch = FakeTouchSource(devices: [Sample.device])
  let recognizer = FakeRecognizer()
  let actions = FakeActions()
  let pointerGuard = FakePointerGuard()
  let typing = FakeTyping()
  let frontmost = FakeFrontmost()
  let logger = RecordingLogger()
  let engine: Engine
  private var frameNumber: Int32 = 0

  init(config: EdgyConfig = .defaults, catalog: [ActionDescriptor] = []) throws {
    actions.available = catalog
    engine = Engine(
      touchSource: touch, recognizer: recognizer, actions: actions, pointerGuard: pointerGuard, typing: typing,
      frontmost: frontmost, config: config, logger: logger, queue: queue)
    try engine.start()
  }

  /// Script the recognizer's next output, emit one frame, and wait for the engine to process it.
  func step(_ output: GestureOutput = GestureOutput(), deviceID: UInt64 = Sample.device.id) {
    queue.sync { recognizer.script.append(output) }
    frameNumber += 1
    touch.emit(Sample.frame(frameNumber, deviceID: deviceID))
    queue.sync {}
  }

  var guardCalls: [String] { pointerGuard.calls.value }
}

@Suite struct EngineTests {
  static let slide = Sample.event(.edge(.right), .slide, phase: .changed, delta: 0.1)

  @Test func pointerGuardEngagesOnClaimAndReleasesOnUnclaim() throws {
    let h = try EngineHarness()

    h.step(GestureOutput(claimedContactIDs: [1]))
    h.step(GestureOutput(events: [Self.slide], claimedContactIDs: [1]))
    h.step(GestureOutput(events: [Self.slide], claimedContactIDs: [1, 2]))
    #expect(h.guardCalls == ["engage"])

    h.step(GestureOutput())
    h.step(GestureOutput())
    #expect(h.guardCalls == ["engage", "release"])
    #expect(h.actions.performed.count == 2)
  }

  @Test func longClaimKeepsGuardAliveAboutOncePerSecond() throws {
    let h = try EngineHarness()
    // 250 frames at 120 Hz ≈ 2.08 s of one continuous claim.
    for _ in 0..<250 { h.step(GestureOutput(claimedContactIDs: [1])) }
    #expect(h.guardCalls == ["engage", "engage", "engage"])
    h.step(GestureOutput())
    #expect(h.guardCalls == ["engage", "engage", "engage", "release"])
  }

  @Test func contextCarriesSlideAndLongPressZonesFromTheProfile() throws {
    let h = try EngineHarness()
    h.step()
    // Defaults bind slides on the left and right edges and no long-press anywhere.
    #expect(h.recognizer.contexts.last?.slideZones == [.edge(.left), .edge(.right)])
    #expect(h.recognizer.contexts.last?.longPressZones == [])
  }

  @Test func configApplyPushesAppSettingsToActionsInPlace() throws {
    let h = try EngineHarness()
    var config = EdgyConfig.defaults
    config.app.haptics = false
    config.app.hud = .none
    h.engine.apply(config)
    h.queue.sync {}
    #expect(h.actions.appliedSettings.last?.haptics == false)
    #expect(h.actions.appliedSettings.last?.hud == HUDMode.none)
  }

  @Test func pauseReleasesGuardAndStopsRouting() throws {
    let h = try EngineHarness()
    h.step(GestureOutput(events: [Self.slide], claimedContactIDs: [1]))
    #expect(h.guardCalls == ["engage"])

    h.engine.pause()
    #expect(h.engine.isPaused)
    #expect(h.guardCalls == ["engage", "release"])

    h.step(GestureOutput(events: [Self.slide], claimedContactIDs: [1]))
    #expect(h.actions.performed.count == 1)
    #expect(h.guardCalls == ["engage", "release"])

    h.engine.resume()
    h.step(GestureOutput(events: [Self.slide], claimedContactIDs: [1]))
    #expect(h.actions.performed.count == 2)
    #expect(h.guardCalls == ["engage", "release", "engage"])
  }

  @Test func stopReleasesGuardAndStopsSource() throws {
    let h = try EngineHarness()
    h.step(GestureOutput(claimedContactIDs: [3]))

    h.engine.stop()

    #expect(h.guardCalls == ["engage", "release"])
    #expect(h.touch.stopCount.value == 1)
    h.step(GestureOutput(events: [Self.slide]))
    #expect(h.actions.performed.isEmpty)
  }

  @Test func configReloadRebuildsContext() throws {
    let h = try EngineHarness()
    h.step()
    #expect(h.recognizer.contexts.last?.settings.edgeWidthMM == GestureSettings.defaults.edgeWidthMM)
    #expect(h.recognizer.contexts.last?.enabledZones.contains(.edge(.left)) == true)

    var edited = EdgyConfig.defaults
    edited.gestures.edgeWidthMM = 12
    edited.defaultProfile = Profile(bindings: [Binding(zone: .edge(.top), gesture: .slide, action: "audio.volume")])
    let resetsBefore = h.recognizer.resetCount
    h.engine.apply(edited)
    h.step(GestureOutput(events: [Sample.event(.edge(.top), .slide, phase: .changed, delta: 0.2)]))

    #expect(h.recognizer.resetCount == resetsBefore + 1)
    #expect(h.recognizer.contexts.last?.settings.edgeWidthMM == 12)
    #expect(h.recognizer.contexts.last?.enabledZones == [.edge(.top)])
    #expect(h.actions.performed.map(\.id) == ["audio.volume"])
  }

  @Test func configReloadReleasesEngagedGuard() throws {
    let h = try EngineHarness()
    h.step(GestureOutput(claimedContactIDs: [1]))

    h.engine.apply(.defaults)

    #expect(h.guardCalls == ["engage", "release"])
  }

  @Test func contextFollowsFrontmostAppAndTyping() throws {
    var config = EdgyConfig.defaults
    config.appProfiles["com.example.player"] = Profile(bindings: [
      Binding(zone: .corner(.bottomRight), gesture: .tap, action: "media.playPause")
    ])
    config.appProfiles["com.example.game"] = Profile(bindings: config.defaultProfile.bindings, disabled: true)
    let h = try EngineHarness(config: config)

    h.typing.seconds.value = 0.2
    h.frontmost.bundleID.value = "com.example.player"
    h.step()
    #expect(h.recognizer.contexts.last?.enabledZones == [.corner(.bottomRight)])
    #expect(h.recognizer.contexts.last?.secondsSinceLastKeyPress == 0.2)

    h.frontmost.bundleID.value = "com.example.game"
    h.step()
    #expect(h.recognizer.contexts.last?.enabledZones.isEmpty == true)
  }

  @Test func disabledAppSettingStopsProcessing() throws {
    var config = EdgyConfig.defaults
    config.app.enabled = false
    let h = try EngineHarness(config: config)

    h.step(GestureOutput(events: [Self.slide], claimedContactIDs: [1]))

    #expect(h.recognizer.contexts.isEmpty)
    #expect(h.actions.performed.isEmpty)
    #expect(h.guardCalls.isEmpty)
  }

  @Test func framesFromUnknownDevicesAreDroppedUntilConnected() throws {
    let h = try EngineHarness()
    let other = TouchDeviceInfo(
      id: 42, kind: .externalTrackpad, sensorSizeMM: Size2D(width: 130, height: 110), familyID: 0)

    h.step(GestureOutput(events: [Self.slide]), deviceID: other.id)
    #expect(h.recognizer.contexts.isEmpty)

    h.touch.changeDevices([Sample.device, other])
    h.queue.sync {}
    h.step(GestureOutput(events: [Self.slide]), deviceID: other.id)
    #expect(h.recognizer.contexts.count == 1)
    #expect(h.actions.performed.count == 1)
  }
}
