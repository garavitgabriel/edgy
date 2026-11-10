import CoreFoundation
import Foundation
import Testing

@testable import TouchKit

/// Batch 28: input runs on its own thread's run loop, never main.
@Test func inputRunLoopRunsWorkOffTheMainThread() async {
  let input = InputRunLoop(name: "test.input")
  #expect(input.runLoop !== CFRunLoopGetMain())
  let ranOnMain: Bool = await withCheckedContinuation { continuation in
    CFRunLoopPerformBlock(input.runLoop, CFRunLoopMode.commonModes.rawValue) {
      continuation.resume(returning: Thread.isMainThread)
    }
    CFRunLoopWakeUp(input.runLoop)
  }
  #expect(!ranOnMain)
}

/// Batch 28: a pointer-guard tap the system turns off by timeout is turned back on every time,
/// not only the first (the log line is once; the re-enable is always).
@Test func pointerGuardTapDisabledByTimeoutIsReEnabledEveryTime() {
  let tap = FakeTap()
  let pointerGuard = PointerGuardCore(tap: tap, cursor: FakeCursor(), scheduler: FakeScheduler(), safetyTimeout: 3)
  pointerGuard.engage()
  for _ in 0..<5 { #expect(tap.send(.disabledByTimeout) == .pass) }
  #expect(tap.enableCalls == Array(repeating: true, count: 5))
  #expect(pointerGuard.reEnableCount == 5)
}
