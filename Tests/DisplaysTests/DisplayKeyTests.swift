import CoreGraphics
import Testing

@testable import Displays

// `DisplayInfo.key`: an identity that survives reconnects. All fakes; nothing touches the system.

@Test func keyIsVendorModelAndSerial() {
  let rig = Rig(
    system: FakeDisplaySystem([descriptor(5, vendor: 0x4c2d, product: 0x7154, serial: 0x3042)]),
    registry: FakeRegistry([.display(attributes()), .avService(external: true, transport: FakeMonitor())]))
  #expect(rig.controller.displays().first?.key == "4c2d-7154-3042")
}

@Test func keySurvivesAReconnectWithANewDisplayID() {
  let system = FakeDisplaySystem([descriptor(5, vendor: 0x4c2d, product: 0x7154, serial: 9)])
  system.setName("Desk 34", for: 5)
  let rig = Rig(
    system: system,
    registry: FakeRegistry([.display(attributes()), .avService(external: true, transport: FakeMonitor())]))
  let before = rig.controller.displays().first

  // Unplugged and plugged back in: CoreGraphics hands out a new id.
  system.displays = [descriptor(11, vendor: 0x4c2d, product: 0x7154, serial: 9)]
  system.setName("Desk 34", for: 11)
  system.fireReconfiguration()
  rig.scheduler.advance(by: 1)
  let after = rig.controller.displays().first

  #expect(before?.id == 5)
  #expect(after?.id == 11)
  #expect(before?.key == after?.key)
  #expect(after?.key == "4c2d-7154-9")
}

@Test func keyOmitsAMissingSerial() {
  let rig = Rig(
    system: FakeDisplaySystem([descriptor(5, vendor: 0x4c2d, product: 0x7154, serial: 0)]),
    registry: FakeRegistry([.display(attributes(serial: 0)), .avService(external: true, transport: FakeMonitor())]))
  #expect(rig.controller.displays().first?.key == "4c2d-7154")
}

@Test func twoMonitorsOfOneModelWithSerialsGetTwoKeys() {
  let rig = Rig(
    system: FakeDisplaySystem([
      descriptor(5, vendor: 0x4c2d, product: 0x7154, serial: 1),
      descriptor(6, vendor: 0x4c2d, product: 0x7154, serial: 2),
    ]),
    registry: FakeRegistry([
      .display(attributes()), .avService(external: true, transport: FakeMonitor()),
      .display(attributes()), .avService(external: true, transport: FakeMonitor()),
    ]))
  let keys = rig.controller.displays().map(\.key)
  #expect(keys == ["4c2d-7154-1", "4c2d-7154-2"])
}

@Test func keyTakesTheSerialFromTheEDIDWhenCoreGraphicsHasNone() {
  let rig = Rig(
    system: FakeDisplaySystem([descriptor(5, vendor: 0x1e6d, product: 0x5b11, serial: 0)]),
    registry: FakeRegistry([
      .display(attributes(vendor: 0x1e6d, product: 0x5b11, serial: 77)),
      .avService(external: true, transport: FakeMonitor()),
    ]))
  #expect(rig.controller.displays().first?.key == "1e6d-5b11-4d")
}

@Test func keyFallsBackToTheNameWithoutAnyIdentity() {
  let system = FakeDisplaySystem([descriptor(5, vendor: 0, product: 0, serial: 0)])
  system.setName("Desk 34", for: 5)
  let rig = Rig(system: system, registry: FakeRegistry())
  let display = rig.controller.displays().first
  #expect(display?.key == "Desk 34")
  #expect(display?.brightnessControllable == false)
}

@Test func uncontrollableAndBuiltInDisplaysHaveKeysToo() {
  let rig = Rig(
    system: FakeDisplaySystem([
      descriptor(1, builtIn: true, vendor: 0x610, product: 0xa029), descriptor(2, vendor: 0x1e6d, product: 3),
    ]),
    backlight: FakeBacklight([1: 0.5]), registry: FakeRegistry())
  let displays = rig.controller.displays()
  #expect(displays.map(\.key) == ["610-a029", "1e6d-3"])
  #expect(displays.map(\.brightnessControllable) == [true, false])
}
