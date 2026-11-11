import EdgyCore
import Foundation
import Testing

@testable import TouchKit

// Batch 35: the guard swallows the system's tap-to-click click for a tap Edgy took, and never a
// physical press. Fakes only: no event tap is created, no event posted, no button state read.

private final class FakeClock: @unchecked Sendable {
  private let lock = NSLock()
  private var _t: TimeInterval = 10
  var t: TimeInterval {
    get { lock.withLock { _t } }
    set { lock.withLock { _t = newValue } }
  }
}

private func contact(_ state: TouchContact.State) -> TouchContact {
  TouchContact(
    id: 1, state: state, position: Point2D(x: 0.95, y: 0.95), velocity: Vector2D(dx: 0, dy: 0), majorAxisMM: 9,
    minorAxisMM: 8, angle: 0, size: 0.5, density: 0.5)
}

private func frame(_ states: [TouchContact.State], deviceID: UInt64 = 1) -> TouchFrame {
  TouchFrame(deviceID: deviceID, timestamp: 0, frameNumber: 0, contacts: states.map(contact))
}

private struct Rig {
  let clock = FakeClock()
  let tap = FakeTap()
  let scheduler = FakeScheduler()
  let pad: PadContacts
  let core: PointerGuardCore

  init(withPad: Bool = true) {
    let clock = self.clock
    pad = PadContacts(now: { clock.t })
    core = PointerGuardCore(
      tap: tap, cursor: FakeCursor(), scheduler: scheduler, safetyTimeout: 3, now: { clock.t },
      padContacts: withPad ? pad : nil)
    // As the live factory does: the tap is in before anything is expected.
    core.prepare()
  }

  /// A finger lands and lifts at `at` (the pads empty then).
  func tapLift(at: TimeInterval) {
    clock.t = at - 0.08
    pad.observe(frame([.starting]))
    pad.observe(frame([.touching]))
    clock.t = at
    pad.observe(frame([.lifting]))
    pad.observe(frame([]))
  }

  func click(at: TimeInterval, clickState: Int = 1) -> [TapVerdict?] {
    clock.t = at
    let down = tap.send(.leftDown(clickState: clickState))
    clock.t = at + 0.01
    return [down, tap.send(.leftUp)]
  }
}

@Suite struct TapClickTests {
  @Test func expectedTapSwallowsOneClickThenTheNextPasses() {
    let rig = Rig()
    rig.tapLift(at: 10)
    rig.clock.t = 10.05
    rig.core.expectTapClick(within: 0.5)
    #expect(rig.click(at: 10.1) == [.swallow, .swallow])
    #expect(rig.click(at: 10.2) == [.pass, .pass])
    #expect(rig.core.tapClicksSwallowed == 1)
    #expect(rig.scheduler.pending.isEmpty, "the up arrived: no safety timer left")
  }

  @Test func clickWithNoExpectationPasses() {
    let rig = Rig()
    rig.tapLift(at: 10)
    #expect(rig.click(at: 10.05) == [.pass, .pass])
    #expect(rig.core.tapClicksSwallowed == 0)
  }

  @Test func physicalPressWithAFingerDownPassesEvenWithAnOpenExpectation() {
    let rig = Rig()
    rig.tapLift(at: 10)
    rig.clock.t = 10.02
    rig.core.expectTapClick(within: 0.5)
    // A finger lands and presses the pad: a physical click.
    rig.clock.t = 10.1
    rig.pad.observe(frame([.starting]))
    rig.pad.observe(frame([.touching]))
    #expect(rig.click(at: 10.2) == [.pass, .pass])
    #expect(rig.core.tapClicksSwallowed == 0)
  }

  @Test func expectationExpiresAndALaterClickPasses() {
    let rig = Rig()
    rig.tapLift(at: 10)
    rig.clock.t = 10.05
    rig.core.expectTapClick(within: 0.5)
    #expect(rig.click(at: 10.6) == [.pass, .pass])
    #expect(rig.core.openTapClickExpectations == 0)
    #expect(rig.scheduler.jobs.isEmpty, "expiry needs no timer")
  }

  @Test func windowIsAnchoredToTheLiftNotToTheCall() {
    let rig = Rig()
    rig.tapLift(at: 10)
    // The runtime hears about the lift 0.4 s late: only 0.1 s of the window is left.
    rig.clock.t = 10.4
    rig.core.expectTapClick(within: 0.5)
    #expect(rig.click(at: 10.55) == [.pass, .pass])

    let again = Rig()
    again.tapLift(at: 10)
    again.clock.t = 10.4
    again.core.expectTapClick(within: 0.5)
    #expect(again.click(at: 10.45) == [.swallow, .swallow])
  }

  @Test func expectationThatArrivesAfterTheClickPassedIsDropped() {
    let rig = Rig()
    rig.tapLift(at: 10)
    // The tap's click arrives before the runtime's call: it passes (nothing expected yet).
    #expect(rig.click(at: 10.02) == [.pass, .pass])
    rig.clock.t = 10.05
    rig.core.expectTapClick(within: 0.5)
    #expect(rig.core.lateTapClickExpectations == 1)
    #expect(rig.core.openTapClickExpectations == 0)
    // The user's next real tap-click elsewhere is not eaten.
    #expect(rig.click(at: 10.2) == [.pass, .pass])
  }

  @Test func doubleTapSwallowsBothClicksAndAThirdPasses() {
    let rig = Rig()
    rig.tapLift(at: 10)
    rig.clock.t = 10.02
    rig.core.expectTapClick(within: 0.5)
    #expect(rig.click(at: 10.04) == [.swallow, .swallow])
    rig.tapLift(at: 10.2)
    rig.clock.t = 10.22
    rig.core.expectTapClick(within: 0.5)
    // The system's second click of a double-click: clickState 2 is still one pair.
    #expect(rig.click(at: 10.24, clickState: 2) == [.swallow, .swallow])
    #expect(rig.click(at: 10.3, clickState: 3) == [.pass, .pass])
    #expect(rig.core.tapClicksSwallowed == 2)
  }

  @Test func bothExpectationsOpenBeforeEitherClickStillSpendOnePairEach() {
    let rig = Rig()
    rig.tapLift(at: 10)
    rig.clock.t = 10.02
    rig.core.expectTapClick(within: 0.5)
    rig.tapLift(at: 10.2)
    rig.clock.t = 10.22
    rig.core.expectTapClick(within: 0.5)
    #expect(rig.core.openTapClickExpectations == 2)
    #expect(rig.click(at: 10.24) == [.swallow, .swallow])
    #expect(rig.click(at: 10.26, clickState: 2) == [.swallow, .swallow])
    #expect(rig.click(at: 10.3) == [.pass, .pass])
  }

  @Test func sameLiftExpectedTwiceIsOneClick() {
    let rig = Rig()
    rig.tapLift(at: 10)
    rig.clock.t = 10.02
    rig.core.expectTapClick(within: 0.5)
    rig.core.expectTapClick(within: 0.5)
    #expect(rig.click(at: 10.04) == [.swallow, .swallow])
    #expect(rig.click(at: 10.1) == [.pass, .pass])
  }

  @Test func swallowedDownWithNoUpIsReleasedByTheSafetyTimeoutAndLoggedOnce() {
    let rig = Rig()
    rig.tapLift(at: 10)
    rig.clock.t = 10.02
    rig.core.expectTapClick(within: 0.5)
    rig.clock.t = 10.04
    #expect(rig.tap.send(.leftDown(clickState: 1)) == .swallow)
    #expect(rig.scheduler.pending.count == 1)
    #expect(rig.scheduler.pending.first?.delay == 3)
    rig.scheduler.fireAll()
    rig.scheduler.fireAll(includingCancelled: true)
    #expect(rig.core.tapClickUpTimeouts == 1)
    // A late up was not swallowed-with-its-down any more: it passes.
    #expect(rig.tap.send(.leftUp) == .pass)
  }

  @Test func newDownWhileWaitingForAnUpEndsTheWait() {
    let rig = Rig()
    rig.tapLift(at: 10)
    rig.clock.t = 10.02
    rig.core.expectTapClick(within: 0.5)
    rig.clock.t = 10.04
    #expect(rig.tap.send(.leftDown(clickState: 1)) == .swallow)
    // The up was lost; the next click is the user's and its up must reach the system.
    #expect(rig.click(at: 10.3) == [.pass, .pass])
    #expect(rig.scheduler.pending.isEmpty, "the stale safety timer is cancelled")
    rig.scheduler.fireAll(includingCancelled: true)
    #expect(rig.core.tapClickUpTimeouts == 0)
  }

  @Test func upWithoutASwallowedDownPasses() {
    let rig = Rig()
    rig.tapLift(at: 10)
    rig.clock.t = 10.02
    rig.core.expectTapClick(within: 0.5)
    rig.clock.t = 10.03
    #expect(rig.tap.send(.leftUp) == .pass)
    #expect(rig.core.openTapClickExpectations == 1)
  }

  @Test func idleCostsNoTimer() {
    let rig = Rig()
    rig.tapLift(at: 10)
    rig.clock.t = 10.02
    rig.core.expectTapClick(within: 0.5)
    #expect(rig.scheduler.jobs.isEmpty)
    _ = rig.click(at: 10.6)
    #expect(rig.scheduler.jobs.isEmpty)
  }

  @Test func pointerMotionIsUnchangedWhileAClickIsExpected() {
    let rig = Rig()
    rig.tapLift(at: 10)
    rig.clock.t = 10.02
    rig.core.expectTapClick(within: 0.5)
    #expect(rig.tap.send(.pointerMotion) == .pass)
    rig.core.engage()
    #expect(rig.tap.send(.pointerMotion) == .swallow)
    rig.core.release()
    #expect(rig.tap.send(.pointerMotion) == .pass)
    #expect(rig.click(at: 10.1) == [.swallow, .swallow])
  }

  @Test func tapDisabledWhileAClickIsExpectedIsTurnedBackOn() {
    let rig = Rig()
    rig.tapLift(at: 10)
    rig.clock.t = 10.02
    rig.core.expectTapClick(within: 0.5)
    #expect(rig.tap.send(.disabledByTimeout) == .pass)
    #expect(rig.tap.send(.disabledByUserInput) == .pass)
    #expect(rig.tap.enableCalls == [true, true])
    #expect(rig.click(at: 10.1) == [.swallow, .swallow])
  }

  @Test func withoutPadStateTheWindowStartsAtTheCall() {
    let rig = Rig(withPad: false)
    rig.clock.t = 20
    rig.core.expectTapClick(within: 0.5)
    #expect(rig.click(at: 20.4) == [.swallow, .swallow])
    rig.clock.t = 30
    rig.core.expectTapClick(within: 0.5)
    #expect(rig.click(at: 30.6) == [.pass, .pass])
  }
}

@Suite struct PadContactsTests {
  @Test func liftingAndHoveringFingersAreUpAndEachEmptyingBumpsTheEpochOnce() {
    let clock = FakeClock()
    let pad = PadContacts(now: { clock.t })
    #expect(pad.snapshot == PadContactSnapshot(fingersDown: false, emptyEpoch: 0, emptiedAt: nil))
    pad.observe(frame([.starting]))
    #expect(pad.snapshot.fingersDown)
    clock.t = 11
    pad.observe(frame([.lifting]))
    pad.observe(frame([]))
    pad.observe(frame([.hovering]))
    #expect(pad.snapshot == PadContactSnapshot(fingersDown: false, emptyEpoch: 1, emptiedAt: 11))
  }

  @Test func aFingerOnAnyDeviceCountsAndAGoneDeviceIsForgotten() {
    let clock = FakeClock()
    let pad = PadContacts(now: { clock.t })
    pad.observe(frame([.touching], deviceID: 1))
    pad.observe(frame([.touching], deviceID: 2))
    pad.observe(frame([], deviceID: 1))
    #expect(pad.snapshot.fingersDown, "device 2 still has a finger down")
    clock.t = 12
    pad.forget(deviceIDs: [2])
    #expect(pad.snapshot == PadContactSnapshot(fingersDown: false, emptyEpoch: 1, emptiedAt: 12))
  }

  @Test func deviceManagerTellsThePadAboutEveryFrameAndEveryGoneDevice() {
    let backend = FakeBackend()
    backend.devices = [device(1), device(2)]
    let pad = PadContacts(now: { 5 })
    let manager = DeviceManager(backend: backend, notifier: FakeNotifier(), padContacts: pad)
    let seen = Box<[Bool]>([])
    manager.start(onFrame: { _ in seen.mutate { $0.append(pad.snapshot.fingersDown) } }, onDevicesChanged: { _ in })
    backend.emit(frame([.touching], deviceID: 2))
    #expect(seen.value == [true], "the pad is updated before the frame is handed on")
    backend.devices = [device(1)]
    manager.handle(.detached)
    #expect(!pad.snapshot.fingersDown)
    manager.stop()
  }
}
