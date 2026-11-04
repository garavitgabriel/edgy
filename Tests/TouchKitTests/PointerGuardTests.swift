import EdgyCore
import Foundation
import Testing

@testable import TouchKit

@Suite struct PointerGuardTests {
  func make(timeout: TimeInterval = 3) -> (PointerGuardCore, FakeTap, FakeCursor, FakeScheduler) {
    let tap = FakeTap()
    let cursor = FakeCursor()
    let scheduler = FakeScheduler()
    return (
      PointerGuardCore(tap: tap, cursor: cursor, scheduler: scheduler, safetyTimeout: timeout), tap, cursor, scheduler
    )
  }

  @Test func engageSwallowsMotionAndReleaseWarpsBack() {
    let (guard_, tap, cursor, _) = make()
    guard_.engage()
    #expect(guard_.isEngaged && guard_.isTapInstalled)
    cursor.current = Point2D(x: 500, y: 500)
    #expect(tap.send(.pointerMotion) == .swallow)
    guard_.release()
    #expect(!guard_.isEngaged)
    #expect(cursor.warps == [Point2D(x: 100, y: 200)])
    #expect(tap.send(.pointerMotion) == .pass)
  }

  @Test func engageIsIdempotentAndKeepsOriginalPoint() {
    let (guard_, tap, cursor, _) = make()
    guard_.engage()
    cursor.current = Point2D(x: 1, y: 1)
    guard_.engage()
    guard_.release()
    #expect(cursor.warps == [Point2D(x: 100, y: 200)])
    #expect(tap.installCount == 1)
  }

  @Test func releaseIsIdempotentAndNoOpWhenIdle() {
    let (guard_, _, cursor, _) = make()
    guard_.release()
    #expect(cursor.warps.isEmpty)
    guard_.engage()
    guard_.release()
    guard_.release()
    #expect(cursor.warps.count == 1)
  }

  @Test func safetyTimeoutReleasesAStrandedGuard() {
    let (guard_, _, cursor, scheduler) = make(timeout: 3)
    guard_.engage()
    #expect(scheduler.pending.count == 1 && scheduler.pending.first?.delay == 3)
    scheduler.fireAll()
    #expect(!guard_.isEngaged)
    #expect(cursor.warps == [Point2D(x: 100, y: 200)])
    #expect(guard_.timeoutReleaseCount == 1)
  }

  @Test func releaseCancelsTimeoutAndStaleTimerCannotReleaseANewEngage() {
    let (guard_, _, _, scheduler) = make()
    guard_.engage()
    guard_.release()
    #expect(scheduler.pending.isEmpty)
    guard_.engage()
    // The first (cancelled) timer fires late anyway — it must not end the second engagement.
    scheduler.jobs.first?.work()
    #expect(guard_.isEngaged)
    #expect(guard_.timeoutReleaseCount == 0)
  }

  @Test func repeatedEngageReArmsTimeout() {
    let (guard_, _, _, scheduler) = make()
    guard_.engage()
    guard_.engage()
    #expect(scheduler.jobs.count == 2 && scheduler.pending.count == 1)
    scheduler.jobs[0].work()
    #expect(guard_.isEngaged)
    scheduler.jobs[1].work()
    #expect(!guard_.isEngaged)
  }

  @Test func reEnablesTapWhenSystemDisablesIt() {
    let (guard_, tap, _, _) = make()
    guard_.engage()
    #expect(tap.send(.disabledByTimeout) == .pass)
    #expect(tap.send(.disabledByUserInput) == .pass)
    #expect(tap.enableCalls == [true, true])
    #expect(guard_.reEnableCount == 2)
    #expect(guard_.isEngaged)
  }

  @Test func tapInstallFailureDegradesAndRetries() {
    let (guard_, tap, cursor, _) = make()
    tap.installSucceeds = false
    guard_.engage()
    #expect(!guard_.isTapInstalled && guard_.isEngaged)
    guard_.release()
    #expect(cursor.warps.count == 1)
    tap.installSucceeds = true
    guard_.engage()
    #expect(guard_.isTapInstalled && tap.installCount == 2)
  }

  @Test func otherEventsAlwaysPass() {
    let (guard_, tap, _, _) = make()
    guard_.engage()
    #expect(tap.send(.other) == .pass)
    #expect(guard_.swallowedCount == 0)
  }
}

@Suite struct TypingActivityTests {
  @Test func nilWithoutPermissionAndNoMonitorInstalled() {
    let monitor = FakeKeyMonitor()
    let core = TypingActivityCore(monitor: monitor, isPermitted: { false }, now: { 10 })
    #expect(core.secondsSinceLastKeyPress == nil)
    #expect(monitor.installCount == 0)
  }

  @Test func reportsSecondsSinceLastKeyPress() {
    let clock = Box<TimeInterval>(100)
    let monitor = FakeKeyMonitor()
    let core = TypingActivityCore(monitor: monitor, isPermitted: { true }, now: { clock.value })
    #expect(core.secondsSinceLastKeyPress == nil)
    monitor.press()
    clock.value = 100.25
    #expect(core.secondsSinceLastKeyPress == 0.25)
    #expect(monitor.installCount == 1)
  }

  @Test func permissionIsCachedThenRechecked() {
    let clock = Box<TimeInterval>(0)
    let permitted = Box(false)
    let checks = Box(0)
    let monitor = FakeKeyMonitor()
    let core = TypingActivityCore(
      monitor: monitor,
      isPermitted: {
        checks.mutate { $0 += 1 }
        return permitted.value
      }, now: { clock.value }, permissionRecheckInterval: 2)
    permitted.value = true
    #expect(core.secondsSinceLastKeyPress == nil)
    #expect(checks.value == 1 && monitor.installCount == 0)
    clock.value = 3
    _ = core.secondsSinceLastKeyPress
    #expect(checks.value == 2 && monitor.installCount == 1)
    monitor.press()
    clock.value = 4
    #expect(core.secondsSinceLastKeyPress == 1)
    #expect(checks.value == 2)
  }
}
