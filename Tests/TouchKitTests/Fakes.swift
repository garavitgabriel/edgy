import EdgyCore
import Foundation

@testable import TouchKit

/// Thread-safe box for collecting values from @Sendable callbacks.
final class Box<T>: @unchecked Sendable {
  private let lock = NSLock()
  private var _value: T
  init(_ value: T) { _value = value }
  var value: T {
    get { lock.withLock { _value } }
    set { lock.withLock { _value = newValue } }
  }
  func mutate(_ f: (inout T) -> Void) { lock.withLock { f(&_value) } }
}

func device(_ id: UInt64, kind: TouchDeviceInfo.Kind = .builtInTrackpad, width: Double = 130) -> TouchDeviceInfo {
  TouchDeviceInfo(id: id, kind: kind, sensorSizeMM: Size2D(width: width, height: 80), familyID: 105)
}

final class FakeBackend: MultitouchBackend, @unchecked Sendable {
  private let lock = NSLock()
  private var _devices: [BackendDevice] = []
  private var _registerLog: [UInt64] = []
  private var _unregisterLog: [UInt64] = []
  private var _active: [UInt64: @Sendable (TouchFrame) -> Void] = [:]
  private var _failing: Set<UInt64> = []

  var devices: [TouchDeviceInfo] {
    get { lock.withLock { _devices.map(\.info) } }
    set { lock.withLock { _devices = newValue.map { BackendDevice(info: $0) } } }
  }
  var failing: Set<UInt64> {
    get { lock.withLock { _failing } }
    set { lock.withLock { _failing = newValue } }
  }
  var registerLog: [UInt64] { lock.withLock { _registerLog } }
  var unregisterLog: [UInt64] { lock.withLock { _unregisterLog } }
  var activeIDs: Set<UInt64> { lock.withLock { Set(_active.keys) } }

  func enumerateDevices() -> [BackendDevice] { lock.withLock { _devices } }

  func register(_ device: BackendDevice, onFrame: @escaping @Sendable (TouchFrame) -> Void) -> Bool {
    lock.withLock {
      _registerLog.append(device.info.id)
      if _failing.contains(device.info.id) { return false }
      precondition(_active[device.info.id] == nil, "double registration of \(device.info.id)")
      _active[device.info.id] = onFrame
      return true
    }
  }

  func unregister(_ device: BackendDevice) {
    lock.withLock {
      _unregisterLog.append(device.info.id)
      _active[device.info.id] = nil
    }
  }

  func emit(_ frame: TouchFrame) {
    let sink = lock.withLock { _active[frame.deviceID] }
    sink?(frame)
  }
}

final class FakeNotifier: DeviceChangeNotifying, @unchecked Sendable {
  private let lock = NSLock()
  private var handler: (@Sendable (DeviceChangeEvent) -> Void)?
  private(set) var startCount = 0
  private(set) var stopCount = 0

  func start(_ handler: @escaping @Sendable (DeviceChangeEvent) -> Void) -> Bool {
    lock.withLock {
      self.handler = handler
      startCount += 1
    }
    return true
  }
  func stop() {
    lock.withLock {
      handler = nil
      stopCount += 1
    }
  }
  func fire(_ event: DeviceChangeEvent) {
    let h = lock.withLock { handler }
    h?(event)
  }
}

final class FakeTap: EventTapping, @unchecked Sendable {
  private let lock = NSLock()
  var installSucceeds = true
  private(set) var installCount = 0
  private(set) var enableCalls: [Bool] = []
  private var handler: (@Sendable (TapEventKind, Point2D?) -> TapVerdict)?

  func install(handler: @escaping @Sendable (TapEventKind, Point2D?) -> TapVerdict) -> Bool {
    lock.withLock {
      installCount += 1
      if installSucceeds { self.handler = handler }
      return installSucceeds
    }
  }
  func setEnabled(_ enabled: Bool) { lock.withLock { enableCalls.append(enabled) } }
  func send(_ kind: TapEventKind, at location: Point2D? = nil) -> TapVerdict? {
    let h = lock.withLock { handler }
    return h?(kind, location)
  }
}

final class FakeCursor: CursorControlling, @unchecked Sendable {
  private let lock = NSLock()
  var current = Point2D(x: 100, y: 200)
  private(set) var warps: [Point2D] = []
  func position() -> Point2D? { lock.withLock { current } }
  func warp(to point: Point2D) {
    lock.withLock {
      warps.append(point)
      current = point
    }
  }
}

final class FakeScheduler: GuardScheduling, @unchecked Sendable {
  final class Job: GuardCancellable, @unchecked Sendable {
    let delay: TimeInterval
    let work: @Sendable () -> Void
    private let lock = NSLock()
    private var _cancelled = false
    var cancelled: Bool { lock.withLock { _cancelled } }
    init(delay: TimeInterval, work: @escaping @Sendable () -> Void) {
      self.delay = delay
      self.work = work
    }
    func cancel() { lock.withLock { _cancelled = true } }
  }

  private let lock = NSLock()
  private var _jobs: [Job] = []
  var jobs: [Job] { lock.withLock { _jobs } }
  var pending: [Job] { jobs.filter { !$0.cancelled } }

  func schedule(after seconds: TimeInterval, _ work: @escaping @Sendable () -> Void) -> any GuardCancellable {
    let job = Job(delay: seconds, work: work)
    lock.withLock { _jobs.append(job) }
    return job
  }

  /// Runs every job, cancelled or not, the way a racing timer might — the guard must ignore stale ones.
  func fireAll(includingCancelled: Bool = false) {
    for job in jobs where includingCancelled || !job.cancelled { job.work() }
  }
}

final class FakeKeyMonitor: KeyMonitorInstalling, @unchecked Sendable {
  private let lock = NSLock()
  private(set) var installCount = 0
  private var handler: (@Sendable () -> Void)?
  func install(onKeyDown: @escaping @Sendable () -> Void) -> Bool {
    lock.withLock {
      installCount += 1
      handler = onKeyDown
    }
    return true
  }
  func press() {
    let h = lock.withLock { handler }
    h?()
  }
}
