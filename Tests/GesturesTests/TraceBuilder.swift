import EdgyCore

/// A synthetic finger (or palm): keyframes in millimetres, times in seconds from the start of the
/// trace, linearly interpolated. The contact is down from the first keyframe to the last.
struct Stroke {
  struct Key {
    var time: Double
    var x: Double
    var y: Double
  }

  var id: Int32
  var keys: [Key]
  var majorAxisMM = 9.0
  var minorAxisMM = 8.0
  /// If set, the major axis grows linearly from `majorAxisMM` to this over `growS` after landing
  /// (palms land small and spread).
  var grownMajorAxisMM: Double?
  var growS = 0.04
  var size = 0.6
  var density = 0.5
  /// Amplitude of deterministic per-frame positional noise on each axis, millimetres.
  var jitterMM = 0.0

  /// `keys` are `(time s, x mm, y mm)`.
  init(id: Int32, _ keys: [(Double, Double, Double)]) {
    self.id = id
    self.keys = keys.map { Key(time: $0.0, x: $0.1, y: $0.2) }
  }

  func point(at time: Double) -> (x: Double, y: Double) {
    guard let first = keys.first, let last = keys.last else { return (0, 0) }
    if time <= first.time { return (first.x, first.y) }
    if time >= last.time { return (last.x, last.y) }
    for (a, b) in zip(keys, keys.dropFirst()) where time <= b.time {
      let span = b.time - a.time
      let f = span > 0 ? (time - a.time) / span : 1
      return (a.x + (b.x - a.x) * f, a.y + (b.y - a.y) * f)
    }
    return (last.x, last.y)
  }

  func majorAxis(at time: Double) -> Double {
    guard let grown = grownMajorAxisMM, let start = keys.first?.time else { return majorAxisMM }
    let f = growS > 0 ? min(1, max(0, (time - start) / growS)) : 1
    return majorAxisMM + (grown - majorAxisMM) * f
  }
}

/// Synthesizes realistic frame sequences: 120 Hz timestamps, `.starting` on the first frame,
/// `.lifting` one frame after the last keyframe, then the contact disappears; one trailing empty frame.
struct TraceBuilder {
  /// A built-in trackpad, 150 × 95 mm.
  static let defaultDevice = TouchDeviceInfo(
    id: 7, kind: .builtInTrackpad, sensorSizeMM: Size2D(width: 150, height: 95), familyID: 0)

  var device = TraceBuilder.defaultDevice
  var hz = 120.0
  var startTime = 100.0
  var strokes: [Stroke] = []

  init(_ strokes: [Stroke] = []) {
    self.strokes = strokes
  }

  func frameIndex(_ time: Double) -> Int { Int((time * hz).rounded()) }

  func time(ofFrame index: Int) -> Double { startTime + Double(index) / hz }

  func frames() -> [TouchFrame] {
    let ranges = strokes.map { stroke -> ClosedRange<Int> in
      frameIndex(stroke.keys.first?.time ?? 0)...frameIndex(stroke.keys.last?.time ?? 0)
    }
    let lastFrame = (ranges.map(\.upperBound).max() ?? 0) + 2
    var frames: [TouchFrame] = []
    for index in 0...lastFrame {
      var contacts: [TouchContact] = []
      for (stroke, range) in zip(strokes, ranges) {
        if range.contains(index) {
          contacts.append(contact(stroke, frame: index, state: index == range.lowerBound ? .starting : .touching))
        } else if index == range.upperBound + 1 {
          contacts.append(contact(stroke, frame: range.upperBound, state: .lifting))
        }
      }
      frames.append(
        TouchFrame(
          deviceID: device.id, timestamp: time(ofFrame: index), frameNumber: Int32(index), contacts: contacts))
    }
    return frames
  }

  func trace(label: String, expectation: String) -> TraceFile {
    TraceFile(label: label, expectation: expectation, device: device, frames: frames())
  }

  private func contact(_ stroke: Stroke, frame index: Int, state: TouchContact.State) -> TouchContact {
    let width = device.sensorSizeMM.width
    let height = device.sensorSizeMM.height
    let t = Double(index) / hz
    let p = stroke.point(at: t)
    let previous = stroke.point(at: t - 1 / hz)
    let x = p.x + stroke.jitterMM * Self.noise(index, stroke.id, axis: 1)
    let y = p.y + stroke.jitterMM * Self.noise(index, stroke.id, axis: 2)
    return TouchContact(
      id: stroke.id, state: state, position: Point2D(x: x / width, y: y / height),
      velocity: Vector2D(dx: (p.x - previous.x) * hz / width, dy: (p.y - previous.y) * hz / height),
      majorAxisMM: stroke.majorAxis(at: t), minorAxisMM: stroke.minorAxisMM, angle: 0,
      size: stroke.size, density: stroke.density)
  }

  /// Deterministic noise in -1...1 from (frame, contact, axis).
  static func noise(_ frame: Int, _ id: Int32, axis: UInt64) -> Double {
    var h =
      (UInt64(truncatingIfNeeded: frame) &* 0x9E37_79B9_7F4A_7C15)
      ^ (UInt64(truncatingIfNeeded: Int64(id)) &* 0xBF58_476D_1CE4_E5B9) ^ (axis &* 0x94D0_49BB_1331_11EB)
    h ^= h >> 31
    h = h &* 0xD6E8_FEB8_6659_FD93
    h ^= h >> 32
    return Double(h % 2001) / 1000 - 1
  }
}
