import CoreFoundation
import Foundation

/// A dedicated thread with its own run loop for input: the pointer-guard event tap and (when
/// scheduled on a run loop) the multitouch device callbacks. Edgy's drawing on the main thread can
/// never delay a pointer event that waits on the tap (batch 28).
///
/// Everything installed here runs on this thread: handlers protect their shared state with locks
/// and hop to the main queue only for UI.
final class InputRunLoop: @unchecked Sendable {
  static let shared = InputRunLoop(name: "com.garavit.edgy.input")

  let runLoop: CFRunLoop
  let thread: Thread

  init(name: String) {
    final class Handoff: @unchecked Sendable {
      var runLoop: CFRunLoop?
      let ready = DispatchSemaphore(value: 0)
    }
    let handoff = Handoff()
    let thread = Thread {
      let loop = CFRunLoopGetCurrent()!
      // A run loop with no sources returns at once; this empty one keeps it running.
      var context = CFRunLoopSourceContext()
      let keepAlive = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &context)
      CFRunLoopAddSource(loop, keepAlive, .defaultMode)
      handoff.runLoop = loop
      handoff.ready.signal()
      while true { CFRunLoopRun() }
    }
    thread.name = name
    thread.qualityOfService = .userInteractive
    thread.start()
    handoff.ready.wait()
    self.thread = thread
    runLoop = handoff.runLoop!
  }

  func add(_ source: CFRunLoopSource) {
    CFRunLoopAddSource(runLoop, source, .commonModes)
    CFRunLoopWakeUp(runLoop)
  }

  func remove(_ source: CFRunLoopSource) {
    CFRunLoopRemoveSource(runLoop, source, .commonModes)
    CFRunLoopWakeUp(runLoop)
  }
}
