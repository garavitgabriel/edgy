import CoreGraphics
import Testing

@testable import Displays

// MARK: Classification and naming

@Test func classifiesBuiltInAppleAndThirdPartyDisplays() {
  let monitor = FakeMonitor()
  let rig = Rig(
    system: FakeDisplaySystem([descriptor(1, builtIn: true), descriptor(2, vendor: 0x610), descriptor(3)]),
    backlight: FakeBacklight([1: 0.4, 2: 0.6]),
    registry: FakeRegistry([
      .display(attributes(vendor: 0x610)), .avService(external: true, transport: nil),
      .display(attributes()), .avService(external: true, transport: monitor),
    ]))
  let displays = rig.controller.displays()
  #expect(displays.map(\.kind) == [.builtIn, .appleExternal, .thirdParty])
  #expect(displays.allSatisfy { $0.brightnessControllable })
  #expect(displays.allSatisfy { $0.reason == nil })
}

@Test func namesComeFromMacOSThenRegistryThenFallback() {
  let system = FakeDisplaySystem([descriptor(1, builtIn: true), descriptor(2), descriptor(3, product: 9)])
  system.setName("Desk", for: 3)
  let rig = Rig(
    system: system, backlight: FakeBacklight([1: 0.5]),
    registry: FakeRegistry([
      .display(attributes(name: "Office Monitor")), .avService(external: true, transport: FakeMonitor()),
    ]))
  #expect(rig.controller.displays().map(\.name) == ["Built-in Display", "Office Monitor", "Desk"])
}

@Test func unnamedExternalFallsBackToDisplayNumber() {
  let rig = Rig(system: FakeDisplaySystem([descriptor(7)]), registry: FakeRegistry())
  #expect(rig.controller.displays().first?.name == "Display 1")
}

// MARK: Probing and reasons

@Test func silentMonitorIsNotControllableWithDDCReason() {
  let monitor = FakeMonitor(behavior: .silent)
  let rig = Rig(
    system: FakeDisplaySystem([descriptor(3)]),
    registry: FakeRegistry([.display(attributes()), .avService(external: true, transport: monitor)]))
  let info = rig.controller.displays()[0]
  #expect(!info.brightnessControllable)
  #expect(info.reason == DisplayReason.noResponse)
  #expect(info.reason?.contains("DDC/CI") == true)
  #expect(monitor.readRequests == 3)  // bounded read retries
}

@Test func readErrorIsNotControllable() {
  let rig = Rig(
    system: FakeDisplaySystem([descriptor(3)]),
    registry: FakeRegistry([
      .display(attributes()), .avService(external: true, transport: FakeMonitor(behavior: .readError)),
    ]))
  #expect(rig.controller.displays()[0].reason == DisplayReason.noResponse)
}

@Test func unsupportedLuminanceGetsItsOwnReason() {
  let monitor = FakeMonitor(behavior: .unsupported)
  let rig = Rig(
    system: FakeDisplaySystem([descriptor(3)]),
    registry: FakeRegistry([.display(attributes()), .avService(external: true, transport: monitor)]))
  #expect(rig.controller.displays()[0].reason == DisplayReason.unsupported)
  #expect(monitor.readRequests == 1)  // a definite "no" is not retried
}

@Test func zeroMaximumIsNotControllable() {
  let rig = Rig(
    system: FakeDisplaySystem([descriptor(3)]),
    registry: FakeRegistry([
      .display(attributes()), .avService(external: true, transport: FakeMonitor(current: 0, maximum: 0)),
    ]))
  let info = rig.controller.displays()[0]
  #expect(!info.brightnessControllable)
  #expect(info.reason == DisplayReason.noRange)
}

@Test func monitorWithoutAnAVServiceIsBlamedOnTheConnection() {
  let rig = Rig(system: FakeDisplaySystem([descriptor(3)]), registry: FakeRegistry([]))
  #expect(rig.controller.displays()[0].reason == DisplayReason.noPath)
  #expect(DisplayReason.noPath.contains("adapter or dock"))
}

@Test func unopenableAVServiceIsNotControllable() {
  let rig = Rig(
    system: FakeDisplaySystem([descriptor(3)]),
    registry: FakeRegistry([.display(attributes()), .avService(external: true, transport: nil)]))
  #expect(rig.controller.displays()[0].reason == DisplayReason.noResponse)
}

@Test func intelMacReportsAppleSiliconReasonWithoutTouchingTheRegistry() {
  let registry = FakeRegistry([.display(attributes()), .avService(external: true, transport: FakeMonitor())])
  let rig = Rig(
    system: FakeDisplaySystem([descriptor(1, builtIn: true), descriptor(3)]), backlight: FakeBacklight([1: 0.5]),
    registry: registry, appleSilicon: false)
  let displays = rig.controller.displays()
  #expect(displays[0].brightnessControllable)
  #expect(!displays[1].brightnessControllable)
  #expect(displays[1].reason == "External brightness needs an Apple silicon Mac.")
  #expect(registry.walks == 0)
}

@Test func unreadableBacklightIsNotControllable() {
  let rig = Rig(system: FakeDisplaySystem([descriptor(2, vendor: 0x610)]), backlight: FakeBacklight())
  let info = rig.controller.displays()[0]
  #expect(info.kind == .appleExternal)
  #expect(!info.brightnessControllable)
  #expect(info.reason == DisplayReason.backlightUnreadable)
}

// MARK: Reading and writing

@Test func ddcReadsAreCachedAfterTheProbe() throws {
  let monitor = FakeMonitor(current: 30, maximum: 60)
  let rig = Rig(
    system: FakeDisplaySystem([descriptor(3)]),
    registry: FakeRegistry([.display(attributes()), .avService(external: true, transport: monitor)]))
  #expect(try rig.controller.brightness(of: 3) == 0.5)
  #expect(try rig.controller.brightness(of: 3) == 0.5)
  #expect(monitor.readRequests == 1)
}

@Test func ddcSetUpdatesCacheAtOnceAndWritesLater() throws {
  let monitor = FakeMonitor(current: 50, maximum: 100)
  let rig = Rig(
    system: FakeDisplaySystem([descriptor(3)]),
    registry: FakeRegistry([.display(attributes()), .avService(external: true, transport: monitor)]))
  try rig.controller.setBrightness(0.8, of: 3)
  #expect(try rig.controller.brightness(of: 3) == 0.8)
  #expect(monitor.setValues.isEmpty)  // the caller never waits for the monitor
  rig.scheduler.advance(by: 1)
  #expect(monitor.setValues == [80])
}

@Test func rapidSlideCoalescesAtTheMonitor() throws {
  let monitor = FakeMonitor(current: 0, maximum: 100)
  let rig = Rig(
    system: FakeDisplaySystem([descriptor(3)]),
    registry: FakeRegistry([.display(attributes()), .avService(external: true, transport: monitor)]))
  for step in 1...10 { try rig.controller.setBrightness(Double(step) / 10, of: 3) }
  rig.scheduler.advance(by: 1)
  #expect((1...2).contains(monitor.setValues.count))
  #expect(monitor.setValues.last == 100)
}

@Test func failedWritesSurfaceOnceOnTheNextCall() throws {
  let monitor = FakeMonitor()
  let rig = Rig(
    system: FakeDisplaySystem([descriptor(3)]),
    registry: FakeRegistry([.display(attributes()), .avService(external: true, transport: monitor)]))
  _ = rig.controller.displays()
  monitor.become(.writeError)
  try rig.controller.setBrightness(0.2, of: 3)
  rig.scheduler.advance(by: 2)
  #expect(throws: DisplayBrightnessError.failed(3, reason: DisplayReason.writeFailed)) {
    try rig.controller.setBrightness(0.3, of: 3)
  }
  monitor.become(.normal)
  try rig.controller.setBrightness(0.3, of: 3)
  rig.scheduler.advance(by: 1)
  #expect(monitor.setValues.last == 30)
}

@Test func backlightDisplaysReadAndWriteThroughDisplayServices() throws {
  let backlight = FakeBacklight([1: 0.25])
  let rig = Rig(system: FakeDisplaySystem([descriptor(1, builtIn: true)]), backlight: backlight)
  #expect(try rig.controller.brightness(of: 1) == 0.25)
  try rig.controller.setBrightness(1.7, of: 1)  // clamped
  #expect(try rig.controller.brightness(of: 1) == 1)
}

@Test func errorsNameTheProblem() {
  let rig = Rig(system: FakeDisplaySystem([descriptor(3)]), registry: FakeRegistry([]))
  #expect(throws: DisplayBrightnessError.noSuchDisplay(99)) { try rig.controller.brightness(of: 99) }
  #expect(throws: DisplayBrightnessError.notControllable(3, reason: DisplayReason.noPath)) {
    try rig.controller.setBrightness(0.5, of: 3)
  }
}

// MARK: Lifecycle

@Test func constructionHasNoSideEffects() {
  let system = FakeDisplaySystem([descriptor(3)])
  let registry = FakeRegistry([.display(attributes()), .avService(external: true, transport: FakeMonitor())])
  let rig = Rig(system: system, registry: registry)
  #expect(system.observerCount == 0)
  #expect(registry.walks == 0)
  #expect(rig.controller.probeCount == 0)
  _ = rig.controller.displays()
  #expect(system.observerCount == 1)
  #expect(rig.controller.probeCount == 1)
}

@Test func liveFactoryReturnsTheLiveControllerWithoutProbing() {
  // Construction only: no display, registry or framework call happens until a method is used.
  #expect(makeLiveDisplayBrightness() is LiveDisplayBrightness)
}

@Test func reconfigurationBurstReprobesOnceAfterDebounce() {
  let system = FakeDisplaySystem([descriptor(1, builtIn: true)])
  let rig = Rig(system: system, backlight: FakeBacklight([1: 0.5]), registry: FakeRegistry([]))
  #expect(rig.controller.displays().count == 1)
  system.displays.append(descriptor(3))
  system.fireReconfiguration(times: 5)
  rig.scheduler.advance(by: 0.2)
  #expect(rig.controller.probeCount == 1)  // still debouncing
  rig.scheduler.advance(by: 1)
  #expect(rig.controller.probeCount == 2)
  #expect(rig.controller.displays().map(\.id) == [1, 3])
}

@Test func reprobePicksUpAMonitorThatStartedResponding() {
  let monitor = FakeMonitor(behavior: .silent)
  let system = FakeDisplaySystem([descriptor(3)])
  let rig = Rig(
    system: system, registry: FakeRegistry([.display(attributes()), .avService(external: true, transport: monitor)]))
  #expect(!rig.controller.displays()[0].brightnessControllable)
  monitor.become(.normal)
  system.fireReconfiguration()
  rig.scheduler.advance(by: 1)
  #expect(rig.controller.displays()[0].brightnessControllable)
}

// MARK: Active display

@Test func activeDisplayIsTheOneUnderThePointer() {
  let system = FakeDisplaySystem(
    [
      descriptor(1, builtIn: true, bounds: CGRect(x: 0, y: 0, width: 1512, height: 982)),
      descriptor(3, bounds: CGRect(x: 1512, y: -200, width: 2560, height: 1440)),
    ], main: 1, pointer: CGPoint(x: 2000, y: 100))
  let rig = Rig(system: system)
  #expect(rig.controller.activeDisplayID() == 3)
  system.pointer = CGPoint(x: 10, y: 10)
  #expect(rig.controller.activeDisplayID() == 1)
}

@Test func activeDisplayFallsBackToMain() {
  let system = FakeDisplaySystem(
    [
      descriptor(1, bounds: CGRect(x: 0, y: 0, width: 100, height: 100)),
      descriptor(3, bounds: CGRect(x: 100, y: 0, width: 100, height: 100)),
    ], main: 3, pointer: CGPoint(x: -500, y: -500))
  let rig = Rig(system: system)
  #expect(rig.controller.activeDisplayID() == 3)
  system.pointer = nil
  #expect(rig.controller.activeDisplayID() == 3)
}

@Test func noDisplaysMeansNoActiveDisplay() {
  let system = FakeDisplaySystem([])
  system.main = nil
  #expect(Rig(system: system).controller.activeDisplayID() == nil)
}
