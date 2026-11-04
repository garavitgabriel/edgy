import Foundation

/// Swift mirror of one per-contact record delivered by the multitouch contact-frame callback.
///
/// The callback hands us a pointer to a contiguous C array of these records. We never rely on
/// Swift struct layout to read them; instead every field is loaded at an explicit byte offset
/// (see `RawContactLayout`), so the mirror below is a plain value type.
///
/// C layout we rely on (little-endian, natural alignment, 96-byte stride):
///
/// | offset | size | type      | field                              |
/// |-------:|-----:|-----------|------------------------------------|
/// |      0 |    4 | Int32     | frame number (same as callback arg) |
/// |      4 |    4 | —         | padding before the double          |
/// |      8 |    8 | Double    | timestamp (seconds)                |
/// |     16 |    4 | Int32     | contact identifier                 |
/// |     20 |    4 | Int32     | state (0…7, see `ContactStateMapping`) |
/// |     24 |    4 | Int32     | finger index                       |
/// |     28 |    4 | Int32     | hand index                         |
/// |     32 |    8 | Float × 2 | normalized position x, y (0…1)     |
/// |     40 |    8 | Float × 2 | normalized velocity x, y           |
/// |     48 |    4 | Float     | size (pressure proxy)              |
/// |     52 |    4 | Int32     | unused                             |
/// |     56 |    4 | Float     | ellipse angle (radians)            |
/// |     60 |    4 | Float     | ellipse major axis (device units)  |
/// |     64 |    4 | Float     | ellipse minor axis (device units)  |
/// |     68 |    8 | Float × 2 | absolute position x, y (device units) |
/// |     76 |    8 | Float × 2 | absolute velocity x, y (device units) |
/// |     84 |    8 | Int32 × 2 | unused                             |
/// |     92 |    4 | Float     | density                            |
///
/// The layout is validated at runtime against every callback (`RawContactLayout.isConsistent`):
/// each record's frame field must equal the callback's frame argument. Reading the second record
/// at offset `stride` and finding the same frame number confirms the stride itself.
struct RawContact: Equatable, Sendable {
  var frame: Int32 = 0
  var timestamp: Double = 0
  var identifier: Int32 = 0
  var state: Int32 = 0
  var fingerIndex: Int32 = 0
  var handIndex: Int32 = 0
  var normalizedX: Float = 0
  var normalizedY: Float = 0
  var normalizedVX: Float = 0
  var normalizedVY: Float = 0
  var size: Float = 0
  var angle: Float = 0
  var majorAxis: Float = 0
  var minorAxis: Float = 0
  var absoluteX: Float = 0
  var absoluteY: Float = 0
  var absoluteVX: Float = 0
  var absoluteVY: Float = 0
  var density: Float = 0
}

enum RawContactLayout {
  /// Bytes between consecutive records.
  static let stride = 96
  /// Upper bound on contacts per frame we accept; anything above is treated as corrupt.
  static let maximumContacts = 32
  /// Highest valid raw state value.
  static let maximumState: Int32 = 7

  enum Offset {
    static let frame = 0
    static let timestamp = 8
    static let identifier = 16
    static let state = 20
    static let fingerIndex = 24
    static let handIndex = 28
    static let normalizedX = 32
    static let normalizedY = 36
    static let normalizedVX = 40
    static let normalizedVY = 44
    static let size = 48
    static let angle = 56
    static let majorAxis = 60
    static let minorAxis = 64
    static let absoluteX = 68
    static let absoluteY = 72
    static let absoluteVX = 76
    static let absoluteVY = 80
    static let density = 92
  }

  static func read(from base: UnsafeRawPointer, index: Int) -> RawContact {
    let p = base + index * stride
    func f(_ o: Int) -> Float { p.loadUnaligned(fromByteOffset: o, as: Float.self) }
    func i(_ o: Int) -> Int32 { p.loadUnaligned(fromByteOffset: o, as: Int32.self) }
    return RawContact(
      frame: i(Offset.frame),
      timestamp: p.loadUnaligned(fromByteOffset: Offset.timestamp, as: Double.self),
      identifier: i(Offset.identifier),
      state: i(Offset.state),
      fingerIndex: i(Offset.fingerIndex),
      handIndex: i(Offset.handIndex),
      normalizedX: f(Offset.normalizedX),
      normalizedY: f(Offset.normalizedY),
      normalizedVX: f(Offset.normalizedVX),
      normalizedVY: f(Offset.normalizedVY),
      size: f(Offset.size),
      angle: f(Offset.angle),
      majorAxis: f(Offset.majorAxis),
      minorAxis: f(Offset.minorAxis),
      absoluteX: f(Offset.absoluteX),
      absoluteY: f(Offset.absoluteY),
      absoluteVX: f(Offset.absoluteVX),
      absoluteVY: f(Offset.absoluteVY),
      density: f(Offset.density))
  }

  /// Inverse of `read`. Used to build synthetic buffers (tests) and to document the layout.
  static func write(_ c: RawContact, to base: UnsafeMutableRawPointer, index: Int) {
    let p = base + index * stride
    func f(_ v: Float, _ o: Int) { p.storeBytes(of: v, toByteOffset: o, as: Float.self) }
    func i(_ v: Int32, _ o: Int) { p.storeBytes(of: v, toByteOffset: o, as: Int32.self) }
    i(c.frame, Offset.frame)
    p.storeBytes(of: c.timestamp, toByteOffset: Offset.timestamp, as: Double.self)
    i(c.identifier, Offset.identifier)
    i(c.state, Offset.state)
    i(c.fingerIndex, Offset.fingerIndex)
    i(c.handIndex, Offset.handIndex)
    f(c.normalizedX, Offset.normalizedX)
    f(c.normalizedY, Offset.normalizedY)
    f(c.normalizedVX, Offset.normalizedVX)
    f(c.normalizedVY, Offset.normalizedVY)
    f(c.size, Offset.size)
    f(c.angle, Offset.angle)
    f(c.majorAxis, Offset.majorAxis)
    f(c.minorAxis, Offset.minorAxis)
    f(c.absoluteX, Offset.absoluteX)
    f(c.absoluteY, Offset.absoluteY)
    f(c.absoluteVX, Offset.absoluteVX)
    f(c.absoluteVY, Offset.absoluteVY)
    f(c.density, Offset.density)
  }

  /// Runtime validation of our layout assumptions against one callback's buffer.
  /// Checks the first two records (the second one proves the stride) for a matching frame
  /// number and an in-range state.
  static func isConsistent(base: UnsafeRawPointer?, count: Int, frame: Int32) -> Bool {
    guard count >= 0, count <= maximumContacts else { return false }
    guard count > 0 else { return true }
    guard let base else { return false }
    for index in 0..<min(count, 2) {
      let contact = read(from: base, index: index)
      if contact.frame != frame { return false }
      if contact.state < 0 || contact.state > maximumState { return false }
    }
    return true
  }

  static func readAll(from base: UnsafeRawPointer, count: Int) -> [RawContact] {
    (0..<count).map { read(from: base, index: $0) }
  }
}
