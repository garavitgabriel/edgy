import CoreGraphics
import Testing

@testable import Actions

/// Batch 28: the built-in display is read once and again only after a display reconfiguration.
@Test func builtInDisplayIsReadOnceUntilTheDisplaysChange() {
  final class Box: @unchecked Sendable { var value: CGDirectDisplayID? = 7 }
  let box = Box()
  let cache = BuiltInDisplayCache(read: { box.value })
  for _ in 0..<20 { #expect(cache.current() == 7) }
  #expect(cache.reads == 1)
  box.value = nil
  #expect(cache.current() == 7)
  cache.invalidate()
  #expect(cache.current() == nil)
  #expect(cache.current() == nil)
  #expect(cache.reads == 2)
}

/// Batch 28: a key tap the system turns off (timeout or user input) is turned straight back on;
/// ordinary events are left alone.
@Test func keyTapDisabledByTimeoutIsReEnabled() {
  var enabled = 0
  #expect(TapReenable.handle(.tapDisabledByTimeout) { enabled += 1 })
  #expect(TapReenable.handle(.tapDisabledByUserInput) { enabled += 1 })
  #expect(!TapReenable.handle(.keyDown) { enabled += 1 })
  #expect(enabled == 2)
}

/// Batch 28: the key tap's run loop is its own thread, never main.
@Test func keyTapRunLoopIsNotMain() {
  let loop = KeyTapRunLoop(name: "test.keytap")
  #expect(loop.runLoop !== CFRunLoopGetMain())
}
