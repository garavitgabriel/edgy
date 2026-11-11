import EdgyCore
import Foundation
import Testing

@testable import EdgyRuntime

// Batch 35: when a finger lifts as a tap that a tap or double-tap binding may take, the engine asks
// the pointer guard to swallow the system's tap-to-click click. Fakes only.

private let tapZone = Zone.corner(.topRight)
private let doubleTapZone = Zone.corner(.topLeft)
private let slideZone = Zone.edge(.right)
private let unboundZone = Zone.corner(.bottomLeft)

private func config() -> EdgyConfig {
  var config = EdgyConfig.defaults
  config.defaultProfile = Profile(bindings: [
    Binding(zone: tapZone, gesture: .tap, action: "media.playPause"),
    Binding(zone: doubleTapZone, gesture: .doubleTap, action: "audio.mute"),
    Binding(zone: slideZone, gesture: .slide, action: "audio.volume"),
  ])
  return config
}

private func lift(_ zones: [Zone], events: [GestureEvent] = []) -> GestureOutput {
  GestureOutput(events: events, tapLifts: zones)
}

@Suite struct TapClickEngineTests {
  @Test func tapLiftInATapBoundZoneExpectsTheClick() throws {
    let h = try EngineHarness(config: config())
    h.step(lift([tapZone], events: [Sample.event(tapZone, .tap)]))
    #expect(h.pointerGuard.tapClicks.value == [Engine.tapClickWindowS])
    #expect(Engine.tapClickWindowS == 0.5)
    #expect(h.guardCalls.isEmpty, "pointer motion handling is untouched")
  }

  @Test func heldFirstTapAndSecondTapOfADoubleTapEachExpectAClick() throws {
    let h = try EngineHarness(config: config())
    // The first tap is held back: no event yet, but the lift is reported.
    h.step(lift([doubleTapZone]))
    h.step()
    h.step(lift([doubleTapZone], events: [Sample.event(doubleTapZone, .doubleTap)]))
    #expect(h.pointerGuard.tapClicks.value.count == 2)
  }

  @Test func severalZonesLiftingInOneStepExpectOneClick() throws {
    let h = try EngineHarness(config: config())
    h.step(lift([tapZone, doubleTapZone]))
    #expect(h.pointerGuard.tapClicks.value.count == 1)
  }

  @Test func zoneWithoutATapOrDoubleTapBindingExpectsNothing() throws {
    let h = try EngineHarness(config: config())
    h.step(lift([slideZone], events: [Sample.event(slideZone, .tap)]))
    h.step(lift([unboundZone]))
    #expect(h.pointerGuard.tapClicks.value.isEmpty)
  }

  @Test func rejectedLiftsExpectNothing() throws {
    // Palm, typing, moved and physical-click lifts carry no tap lift (the pipeline's tests prove
    // each); the engine opens nothing for a rejection on its own.
    let h = try EngineHarness(config: config())
    for reason in [RejectionReason.palm, .typing, .offAxisMotion, .physicalClick, .disabledZone] {
      h.step(GestureOutput(rejections: [(contactID: 1, reason: reason)]))
    }
    #expect(h.pointerGuard.tapClicks.value.isEmpty)
  }

  @Test func edgyOffInThisAppExpectsNothing() throws {
    var c = config()
    c.appProfiles["com.example.off"] = Profile(bindings: c.defaultProfile.bindings, disabled: true)
    let h = try EngineHarness(config: c)
    h.frontmost.bundleID.value = "com.example.off"
    h.step(lift([tapZone]))
    #expect(h.pointerGuard.tapClicks.value.isEmpty)
    h.frontmost.bundleID.value = "com.example.other"
    h.step(lift([tapZone]))
    #expect(h.pointerGuard.tapClicks.value.count == 1)
  }

  @Test func enabledOffExpectsNothing() throws {
    var c = config()
    c.app.enabled = false
    let h = try EngineHarness(config: c)
    h.step(lift([tapZone]))
    #expect(h.pointerGuard.tapClicks.value.isEmpty)
  }

  @Test func pausedExpectsNothing() throws {
    let h = try EngineHarness(config: config())
    h.engine.pause()
    h.step(lift([tapZone]))
    #expect(h.pointerGuard.tapClicks.value.isEmpty)
  }

  @Test func testModeStillExpectsTheClick() throws {
    let h = try EngineHarness(config: config())
    h.engine.setTestMode(true)
    h.step(lift([tapZone], events: [Sample.event(tapZone, .tap)]))
    #expect(h.actions.performed.isEmpty, "the gesture runs nothing")
    #expect(h.pointerGuard.tapClicks.value.count == 1, "but the tap was Edgy's")
  }

  @Test func aHeldTapReleasedByFlushIsNotANewLift() throws {
    let queue = DispatchQueue(label: "tap-click-flush")
    let touch = FakeTouchSource(devices: [Sample.device])
    let recognizer = FakeFlushingRecognizer()
    let fakeGuard = FakePointerGuard()
    let timer = FakeEngineTimer()
    let engine = Engine(
      touchSource: touch, recognizer: recognizer, actions: FakeActions(), pointerGuard: fakeGuard, typing: FakeTyping(),
      frontmost: FakeFrontmost(), config: config(), logger: RecordingLogger(), queue: queue, timer: timer)
    try engine.start()
    queue.sync {
      recognizer.held = [Sample.event(tapZone, .tap)]
      recognizer.script.append((lift([tapZone]), 1.0 / 120 + 0.3))
    }
    touch.emit(TouchFrame(deviceID: Sample.device.id, timestamp: 1.0 / 120, frameNumber: 1, contacts: []))
    queue.sync {}
    #expect(fakeGuard.tapClicks.value.count == 1)
    timer.clock.value += 0.4
    let wake = try #require(timer.live.last)
    wake.cancelled = true
    wake.work()
    queue.sync {}
    #expect(recognizer.flushes.count == 1)
    #expect(fakeGuard.tapClicks.value.count == 1)
  }
}
