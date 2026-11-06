import EdgyCore
import Foundation
import Testing

@testable import EdgyRuntime

@MainActor
@Suite struct PermissionMonitorTests {
  final class Reports {
    var states: [PermissionState] = []
  }

  func make(_ initial: PermissionState) -> (PermissionMonitor, FakePermissionChecker, FakeScheduler, Reports) {
    let checker = FakePermissionChecker(initial)
    let scheduler = FakeScheduler()
    let reports = Reports()
    let monitor = PermissionMonitor(checker: checker, scheduler: scheduler, interval: 2) { reports.states.append($0) }
    return (monitor, checker, scheduler, reports)
  }

  @Test func pollsWhileDeniedAndStopsOnceGranted() {
    let (monitor, checker, scheduler, reports) = make(.denied)
    monitor.start()
    #expect(reports.states == [.denied])
    #expect(monitor.isPolling)
    #expect(scheduler.pendingCount == 1)

    scheduler.advance(by: 2)
    scheduler.advance(by: 2)
    #expect(checker.checks == 3)
    #expect(reports.states == [.denied])

    checker.state = .granted
    scheduler.advance(by: 2)
    #expect(reports.states == [.denied, .granted])
    #expect(monitor.accessibility == .granted)
    #expect(!monitor.isPolling)
    #expect(scheduler.pendingCount == 0)

    scheduler.advance(by: 20)
    #expect(checker.checks == 4)
  }

  @Test func grantedFromTheStartNeverPolls() {
    let (monitor, _, scheduler, reports) = make(.granted)
    monitor.start()
    #expect(reports.states == [.granted])
    #expect(scheduler.pendingCount == 0)
  }

  @Test func unknownIsPolledAndRevocationSeenOnRefresh() {
    let (monitor, checker, scheduler, reports) = make(.unknown)
    monitor.start()
    #expect(reports.states.isEmpty)
    #expect(monitor.isPolling)
    checker.state = .granted
    scheduler.advance(by: 2)
    #expect(reports.states == [.granted])

    checker.state = .denied
    monitor.refresh()
    #expect(reports.states == [.granted, .denied])
    #expect(monitor.isPolling)
    // A refresh while polling doesn't stack a second timer.
    monitor.refresh()
    #expect(scheduler.pendingCount == 1)

    monitor.stop()
    #expect(scheduler.pendingCount == 0)
  }
}

@Suite struct EngineStatusTests {
  struct StartFailed: Error {}

  @Test func statusFollowsStartPauseResumeAndStop() throws {
    let h = try EngineHarness()
    let seen = Locked<[EngineStatus]>([])
    h.engine.onStatusChange { status in seen.value.append(status) }
    #expect(h.engine.status.running)
    #expect(h.engine.status.isActive)
    #expect(h.engine.status.devices == [Sample.device])

    let until = Date(timeIntervalSince1970: 1_000_000)
    h.engine.pause(until: until)
    #expect(h.engine.status.paused)
    #expect(h.engine.status.pausedUntil == until)
    #expect(!h.engine.status.isActive)

    h.engine.resume()
    #expect(!h.engine.status.paused)
    #expect(h.engine.status.pausedUntil == nil)

    var off = EdgyConfig.defaults
    off.app.enabled = false
    h.engine.apply(off)
    #expect(!h.engine.status.enabled)

    h.engine.stop()
    #expect(!h.engine.status.running)

    #expect(seen.value.map(\.paused) == [true, false, false, false])
    #expect(seen.value.map(\.enabled) == [true, true, false, false])
    #expect(seen.value.last?.running == false)
  }

  @Test func statusTracksDeviceHotPlug() throws {
    let h = try EngineHarness()
    let seen = Locked<[EngineStatus]>([])
    h.engine.onStatusChange { status in seen.value.append(status) }
    #expect(h.engine.status.hasTrackpad)
    #expect(h.engine.status.deviceKinds == [.builtInTrackpad])

    let mouse = TouchDeviceInfo(id: 3, kind: .mouse, sensorSizeMM: Size2D(width: 50, height: 90), familyID: 0)
    h.touch.changeDevices([mouse])
    h.queue.sync {}
    #expect(h.engine.status.deviceCount == 1)
    #expect(!h.engine.status.hasTrackpad)

    h.touch.changeDevices([])
    h.queue.sync {}
    #expect(h.engine.status.deviceCount == 0)

    // A device list that didn't change is not a status change.
    h.touch.changeDevices([])
    h.queue.sync {}
    #expect(seen.value.map(\.deviceCount) == [1, 0])
  }

  @Test func startFailureIsRecordedAndClearedByASuccessfulStart() throws {
    let queue = DispatchQueue(label: "engine-status-tests")
    let touch = FakeTouchSource(devices: [])
    touch.startError.value = StartFailed()
    let engine = Engine(
      touchSource: touch, recognizer: FakeRecognizer(), actions: FakeActions(), pointerGuard: FakePointerGuard(),
      typing: FakeTyping(), frontmost: FakeFrontmost(), config: .defaults, logger: RecordingLogger(), queue: queue)

    #expect(throws: StartFailed.self) { try engine.start() }
    #expect(!engine.status.running)
    #expect(engine.status.lastStartError?.contains("StartFailed") == true)
    #expect(!engine.status.hasTrackpad)

    touch.startError.value = nil
    try engine.start()
    #expect(engine.status.running)
    #expect(engine.status.lastStartError == nil)
  }
}
