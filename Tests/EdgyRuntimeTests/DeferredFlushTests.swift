import EdgyCore
import Foundation
import Testing

@testable import EdgyRuntime

/// A recognizer that holds a tap: `process` returns scripted outputs and sets `deadline`; `flush`
/// releases `held` once `now` reaches the deadline. Pure; nothing real.
final class FakeFlushingRecognizer: GestureRecognizing, GestureFlushing {
  var script: [(output: GestureOutput, deadline: Double?)] = []
  var held: [GestureEvent] = []
  private(set) var deadline: Double?
  private(set) var flushes: [Double] = []
  private(set) var resetCount = 0

  func process(_ frame: TouchFrame, device: TouchDeviceInfo, context: GestureContext) -> GestureOutput {
    guard !script.isEmpty else { return GestureOutput() }
    let next = script.removeFirst()
    deadline = next.deadline
    return next.output
  }

  var nextFlushDeadline: Double? { deadline }

  func flush(now: Double) -> GestureOutput {
    flushes.append(now)
    guard let deadline, now >= deadline else { return GestureOutput() }
    self.deadline = nil
    defer { held = [] }
    return GestureOutput(events: held)
  }

  func reset() {
    resetCount += 1
    deadline = nil
    held = []
  }
}

/// Manual monotonic clock; scheduled work runs only when the test fires it.
final class FakeEngineTimer: EngineTimer, @unchecked Sendable {
  final class Item: ScheduledWork {
    let after: Double
    let work: @Sendable () -> Void
    var cancelled = false
    init(after: Double, work: @escaping @Sendable () -> Void) {
      self.after = after
      self.work = work
    }
    func cancel() { cancelled = true }
  }

  let clock = Locked<Double>(100)
  let items = Locked<[Item]>([])
  var now: Double { clock.value }
  var live: [Item] { items.value.filter { !$0.cancelled } }

  func schedule(after seconds: Double, _ work: @escaping @Sendable () -> Void) -> ScheduledWork {
    let item = Item(after: seconds, work: work)
    items.value.append(item)
    return item
  }
}

final class FlushHarness {
  let queue = DispatchQueue(label: "flush-tests")
  let touch = FakeTouchSource(devices: [Sample.device])
  let recognizer = FakeFlushingRecognizer()
  let actions = FakeActions()
  let frontmost = FakeFrontmost()
  let timer = FakeEngineTimer()
  let engine: Engine
  private var n: Int32 = 0

  static let tapZone = Zone.edge(.bottom)

  init() throws {
    var config = EdgyConfig.defaults
    config.defaultProfile.bindings.append(Binding(zone: Self.tapZone, gesture: .tap, action: "audio.mute"))
    engine = Engine(
      touchSource: touch, recognizer: recognizer, actions: actions, pointerGuard: FakePointerGuard(),
      typing: FakeTyping(), frontmost: frontmost, config: config, logger: RecordingLogger(), queue: queue,
      timer: timer)
    try engine.start()
  }

  /// One frame at `n / 120` s; the recognizer returns `output` and then waits for `deadline`.
  func frame(_ output: GestureOutput = GestureOutput(), deadline: Double? = nil) {
    queue.sync { recognizer.script.append((output, deadline)) }
    n += 1
    touch.emit(TouchFrame(deviceID: Sample.device.id, timestamp: Double(n) / 120, frameNumber: n, contacts: []))
    queue.sync {}
  }

  /// Advances the clock by `seconds` and fires the live wake-up, if any.
  func wait(_ seconds: Double) {
    timer.clock.value += seconds
    guard let item = timer.live.last else { return }
    item.cancelled = true  // fired: no longer pending
    item.work()
    queue.sync {}
  }
}

@Suite struct DeferredFlushTests {
  static let tap = Sample.event(FlushHarness.tapZone, .tap)
  static let doubleTap = Sample.event(FlushHarness.tapZone, .doubleTap)

  @Test func heldTapIsRoutedOnceAfterTheWindowWithNoFurtherFrames() throws {
    let f = try FlushHarness()
    f.queue.sync { f.recognizer.held = [Self.tap] }
    f.frame(deadline: 1.0 / 120 + 0.3)
    // One wake-up, scheduled for the remaining window.
    #expect(f.timer.live.count == 1)
    #expect(abs((f.timer.live.first?.after ?? 0) - (0.3 + Engine.flushSlackS)) < 1e-9)
    f.wait(0.3 + Engine.flushSlackS)
    #expect(f.actions.performed.map(\.id) == ["audio.mute"])
    #expect(f.recognizer.flushes.count == 1)
    #expect(abs(f.recognizer.flushes[0] - (1.0 / 120 + 0.3 + Engine.flushSlackS)) < 1e-9)
    // Nothing else is waiting, so nothing is rescheduled and a stray fire does nothing.
    #expect(f.timer.live.isEmpty)
    f.wait(1)
    #expect(f.actions.performed.count == 1)
  }

  @Test func doubleTapRoutesOnlyTheDoubleTap() throws {
    let f = try FlushHarness()
    f.queue.sync { f.recognizer.held = [Self.tap] }
    f.frame(deadline: 1.0 / 120 + 0.3)
    // The second tap arrives in time: the recognizer emits the double-tap and stops waiting.
    f.queue.sync { f.recognizer.held = [] }
    f.frame(GestureOutput(events: [Self.doubleTap]), deadline: nil)
    #expect(f.timer.live.isEmpty)
    f.wait(0.5)
    #expect(f.actions.performed.map(\.id) == ["media.playPause"])
  }

  @Test func newerFrameSupersedesTheWakeUp() throws {
    let f = try FlushHarness()
    f.frame(deadline: 0.5)
    let first = try #require(f.timer.live.first)
    f.frame(deadline: 0.6)
    #expect(first.cancelled)
    #expect(f.timer.live.count == 1)
    // A superseded wake-up that fires anyway is ignored.
    first.work()
    f.queue.sync {}
    #expect(f.recognizer.flushes.isEmpty)
  }

  @Test func appChangeBeforeTheFlushDropsTheTap() throws {
    let f = try FlushHarness()
    f.queue.sync { f.recognizer.held = [Self.tap] }
    f.frame(deadline: 1.0 / 120 + 0.3)
    f.frontmost.bundleID.value = "com.example.other"
    f.wait(0.3)
    #expect(f.recognizer.flushes.count == 1)
    #expect(f.actions.performed.isEmpty)
  }

  @Test func quiesceCancelsTheWakeUp() throws {
    for quiesce in [{ (e: Engine) in e.pause() }, { $0.apply(.defaults) }, { $0.stop() }, { $0.setTestMode(true) }] {
      let f = try FlushHarness()
      f.queue.sync { f.recognizer.held = [Self.tap] }
      f.frame(deadline: 0.3)
      let pending = try #require(f.timer.live.first)
      quiesce(f.engine)
      #expect(pending.cancelled)
      pending.work()
      f.queue.sync {}
      #expect(f.recognizer.flushes.isEmpty)
      #expect(f.actions.performed.isEmpty)
    }
  }

  @Test func flushedTapReachesTheFeed() throws {
    let f = try FlushHarness()
    let updates = Locked<[LiveFeedUpdate]>([])
    f.engine.observeFeed(on: f.queue) { updates.value.append($0) }
    f.queue.sync { f.recognizer.held = [Self.tap] }
    f.frame(deadline: 0.1)
    f.wait(0.2)
    f.queue.sync {}
    #expect(
      updates.value.flatMap(\.decisions) == [
        .recognized(zone: FlushHarness.tapZone, kind: .tap, phase: .ended, deviceID: Sample.device.id),
        .actionRan("audio.mute", zone: FlushHarness.tapZone, kind: .tap),
      ])
  }

  @Test func recognizerWithoutFlushingNeverSchedules() throws {
    let h = try EngineHarness()
    h.step()
    // EngineHarness uses the plain FakeRecognizer; nothing to wake, nothing breaks.
    #expect(h.actions.performed.isEmpty)
  }
}
