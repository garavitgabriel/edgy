/// `DisplayInfo.key`: an identity for a display that survives reconnects, reboots and a new
/// CoreGraphics display id, so per-display answers ("this monitor ignores brightness commands")
/// stick to the monitor.
///
/// Built from the display's own identity, CoreGraphics first, then its EDID attributes:
/// - vendor and model known: `"<vendor>-<model>"` in lowercase hex, plus `"-<serial>"` when the
///   display reports a serial number (two identical monitors without serials share one key, and
///   the same answer, which is right for "this model ignores brightness commands");
/// - otherwise the display's name.
enum DisplayKey {
  static func make(display: DisplayDescriptor, attributes: ProductAttributes?, name: String) -> String {
    let vendor = nonZero(display.vendorID) ?? attributes?.vendorID.flatMap(nonZero)
    let product = nonZero(display.productID) ?? attributes?.productID.flatMap(nonZero)
    let serial = nonZero(display.serial) ?? attributes?.serial.flatMap(nonZero)
    guard let vendor, let product else { return name }
    var key = "\(hex(vendor))-\(hex(product))"
    if let serial { key += "-\(hex(serial))" }
    return key
  }

  private static func nonZero(_ value: UInt32) -> UInt32? { value == 0 ? nil : value }

  private static func hex(_ value: UInt32) -> String { String(value, radix: 16) }
}
