import Testing

@testable import Displays

@Test func pairsEachExternalServiceWithThePrecedingDisplay() {
  let candidates = AVServiceMatching.candidates(from: [
    .display(attributes(product: 1, name: "Built-in")), .avService(external: false, transport: nil),
    .display(attributes(product: 2, name: "Left")), .avService(external: true, transport: nil),
    .display(attributes(product: 3, name: "Right")), .avService(external: true, transport: nil),
    .avService(external: true, transport: nil),
  ])
  #expect(candidates.map { $0.attributes?.name } == ["Left", "Right", nil])
}

@Test func identicalMonitorsAreAssignedInOrder() {
  let candidates = AVServiceMatching.candidates(from: [
    .display(attributes()), .avService(external: true, transport: nil),
    .display(attributes()), .avService(external: true, transport: nil),
  ])
  let assigned = AVServiceMatching.assign(displays: [descriptor(5), descriptor(6)], candidates: candidates)
  #expect(assigned == [5: 0, 6: 1])
}

@Test func serialNumberBreaksTies() {
  let candidates = AVServiceMatching.candidates(from: [
    .display(attributes(serial: 111)), .avService(external: true, transport: nil),
    .display(attributes(serial: 222)), .avService(external: true, transport: nil),
  ])
  let assigned = AVServiceMatching.assign(
    displays: [descriptor(5, serial: 222), descriptor(6, serial: 111)], candidates: candidates)
  #expect(assigned == [5: 1, 6: 0])
}

@Test func unknownMonitorGetsNoServiceUnlessOneIsUnlabelled() {
  let labelled = AVServiceMatching.candidates(from: [
    .display(attributes(vendor: 0x9999)), .avService(external: true, transport: nil),
  ])
  #expect(AVServiceMatching.assign(displays: [descriptor(5)], candidates: labelled).isEmpty)
  let unlabelled = AVServiceMatching.candidates(from: [.avService(external: true, transport: nil)])
  #expect(AVServiceMatching.assign(displays: [descriptor(5)], candidates: unlabelled) == [5: 0])
}

@Test func parsesRegistryProductAttributes() {
  let parsed = LiveAVServiceRegistry.productAttributes([
    "ProductAttributes": [
      "LegacyManufacturerID": 7789, "ProductID": 1, "SerialNumber": 16_843_009, "ProductName": "Office Monitor",
      "ManufacturerID": "ABC",
    ] as [String: Any]
  ])
  #expect(parsed == ProductAttributes(vendorID: 7789, productID: 1, serial: 16_843_009, name: "Office Monitor"))
  #expect(LiveAVServiceRegistry.productAttributes([:]) == ProductAttributes())
}
