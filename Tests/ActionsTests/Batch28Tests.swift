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
