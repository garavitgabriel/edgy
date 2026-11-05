import EdgyCore
import Foundation
import Testing

@testable import TouchKit

@Suite struct RawLayoutTests {
  func sample(frame: Int32 = 42, id: Int32 = 7) -> RawContact {
    RawContact(
      frame: frame, timestamp: 1234.5, identifier: id, state: 4, fingerIndex: 2, handIndex: 1,
      normalizedX: 0.25, normalizedY: 0.75, normalizedVX: 0.5, normalizedVY: -0.25, size: 0.9, angle: 1.25,
      majorAxis: 12, minorAxis: 9, absoluteX: 10, absoluteY: -5, absoluteVX: 80, absoluteVY: -40, density: 3.5)
  }

  @Test func strideIs96Bytes() {
    #expect(RawContactLayout.stride == 96)
    #expect(RawContactLayout.Offset.density + 4 == RawContactLayout.stride)
  }

  @Test func writeThenReadRoundTripsAtEveryIndex() {
    let buffer = UnsafeMutableRawPointer.allocate(byteCount: RawContactLayout.stride * 3, alignment: 8)
    defer { buffer.deallocate() }
    let contacts = [sample(id: 1), sample(id: 2), sample(id: 3)]
    for (i, c) in contacts.enumerated() { RawContactLayout.write(c, to: buffer, index: i) }
    #expect(RawContactLayout.readAll(from: buffer, count: 3) == contacts)
  }

  @Test func readsFieldsAtDocumentedOffsets() {
    let buffer = UnsafeMutableRawPointer.allocate(byteCount: RawContactLayout.stride, alignment: 8)
    defer { buffer.deallocate() }
    buffer.initializeMemory(as: UInt8.self, repeating: 0, count: RawContactLayout.stride)
    buffer.storeBytes(of: Int32(9), toByteOffset: 0, as: Int32.self)
    buffer.storeBytes(of: 2.5, toByteOffset: 8, as: Double.self)
    buffer.storeBytes(of: Int32(3), toByteOffset: 16, as: Int32.self)
    buffer.storeBytes(of: Int32(5), toByteOffset: 20, as: Int32.self)
    buffer.storeBytes(of: Float(0.5), toByteOffset: 32, as: Float.self)
    buffer.storeBytes(of: Float(11), toByteOffset: 60, as: Float.self)
    buffer.storeBytes(of: Float(7), toByteOffset: 64, as: Float.self)
    buffer.storeBytes(of: Float(2), toByteOffset: 92, as: Float.self)
    let c = RawContactLayout.read(from: buffer, index: 0)
    #expect(c.frame == 9 && c.timestamp == 2.5 && c.identifier == 3 && c.state == 5)
    #expect(c.normalizedX == 0.5 && c.majorAxis == 11 && c.minorAxis == 7 && c.density == 2)
  }

  @Test func consistencyCheckValidatesFrameAndStride() {
    let buffer = UnsafeMutableRawPointer.allocate(byteCount: RawContactLayout.stride * 2, alignment: 8)
    defer { buffer.deallocate() }
    RawContactLayout.write(sample(frame: 42), to: buffer, index: 0)
    RawContactLayout.write(sample(frame: 42), to: buffer, index: 1)
    #expect(RawContactLayout.isConsistent(base: buffer, count: 2, frame: 42))
    #expect(!RawContactLayout.isConsistent(base: buffer, count: 2, frame: 43))
    // Second record at the assumed stride disagrees → the stride (struct size) is wrong.
    RawContactLayout.write(sample(frame: 41), to: buffer, index: 1)
    #expect(!RawContactLayout.isConsistent(base: buffer, count: 2, frame: 42))
    #expect(RawContactLayout.isConsistent(base: nil, count: 0, frame: 42))
    #expect(!RawContactLayout.isConsistent(base: nil, count: 1, frame: 42))
    #expect(!RawContactLayout.isConsistent(base: buffer, count: 500, frame: 42))
  }

  @Test func consistencyCheckRejectsOutOfRangeState() {
    let buffer = UnsafeMutableRawPointer.allocate(byteCount: RawContactLayout.stride, alignment: 8)
    defer { buffer.deallocate() }
    var c = sample()
    c.state = 99
    RawContactLayout.write(c, to: buffer, index: 0)
    #expect(!RawContactLayout.isConsistent(base: buffer, count: 1, frame: c.frame))
  }
}

@Suite struct ConversionTests {
  @Test func mapsEveryRawState() {
    let expected: [Int32: TouchContact.State] = [
      0: .unknown, 1: .hovering, 2: .hovering, 3: .starting, 4: .touching, 5: .lifting, 6: .leaving, 7: .leaving,
      8: .unknown, -1: .unknown,
    ]
    for (raw, state) in expected { #expect(ContactStateMapping.state(fromRaw: raw) == state, "raw \(raw)") }
  }

  @Test func convertsAxesToMillimetresAndOrdersThem() {
    let converter = ContactConverter(sensorSizeMM: Size2D(width: 160, height: 115))
    let raw = RawContact(identifier: 3, state: 4, normalizedX: 0.9, normalizedY: 0.1, majorAxis: 4, minorAxis: 10)
    let c = converter.contact(from: raw, mmPerAxisUnit: 1.5)
    #expect(c.id == 3 && c.state == .touching)
    #expect(c.majorAxisMM == 15 && c.minorAxisMM == 6)
    #expect(abs(c.position.x - 0.9) < 1e-6 && abs(c.position.y - 0.1) < 1e-6)
  }

  @Test func clampsPositionAndCopiesVelocitySizeDensity() {
    let converter = ContactConverter(sensorSizeMM: Size2D(width: 100, height: 100))
    let raw = RawContact(
      state: 3, normalizedX: 1.2, normalizedY: -0.1, normalizedVX: 0.5, normalizedVY: -2, size: 0.75, angle: 0.5,
      density: 4)
    let c = converter.contact(from: raw, mmPerAxisUnit: 1)
    #expect(c.position == Point2D(x: 1, y: 0))
    #expect(c.velocity == Vector2D(dx: 0.5, dy: -2))
    #expect(c.size == 0.75 && c.density == 4 && c.angle == 0.5 && c.state == .starting)
  }

  @Test func buildsFrameWithDeviceAndTimestamp() {
    let converter = ContactConverter(sensorSizeMM: Size2D(width: 100, height: 100))
    let frame = converter.frame(
      deviceID: 77, timestamp: 9.5, frameNumber: 12, raws: [RawContact(identifier: 1), RawContact(identifier: 2)],
      mmPerAxisUnit: 1)
    #expect(frame.deviceID == 77 && frame.timestamp == 9.5 && frame.frameNumber == 12)
    #expect(frame.contacts.map(\.id) == [1, 2])
  }

  @Test func axisScaleIsLearnedFromVelocityRatioAndSensorSize() {
    var estimator = AxisScaleEstimator()
    #expect(estimator.mmPerUnit == 1)
    // 0.5 sensor-widths/s == 40 device units/s → 80 units span 160 mm → 2 mm per unit.
    let raw = RawContact(normalizedVX: 0.5, normalizedVY: 0, absoluteVX: 40, absoluteVY: 0)
    estimator.observe(raw, sensorSizeMM: Size2D(width: 160, height: 115))
    #expect(abs(estimator.mmPerUnit - 2) < 1e-6)
    #expect(estimator.sampleCount == 1)
  }

  @Test func axisScaleIgnoresSlowOrInconsistentSamples() {
    var estimator = AxisScaleEstimator()
    let size = Size2D(width: 160, height: 115)
    estimator.observe(RawContact(normalizedVX: 0.01, absoluteVX: 1), sensorSizeMM: size)
    estimator.observe(RawContact(normalizedVX: 0.5, absoluteVX: -40), sensorSizeMM: size)
    estimator.observe(RawContact(normalizedVX: 0.5, absoluteVX: 0.0001), sensorSizeMM: size)
    #expect(estimator.sampleCount == 0)
    #expect(estimator.mmPerUnit == 1)
  }
}

@Suite struct DeviceCatalogTests {
  @Test func classifiesDevices() {
    #expect(DeviceCatalog.kind(familyID: 105, isBuiltIn: true) == .builtInTrackpad)
    #expect(DeviceCatalog.kind(familyID: 130, isBuiltIn: false) == .externalTrackpad)
    #expect(DeviceCatalog.kind(familyID: 112, isBuiltIn: false) == .mouse)
    #expect(DeviceCatalog.kind(familyID: 1, isBuiltIn: false) == .unknown)
  }

  @Test func prefersReportedSensorSizeAndFallsBackWhenImplausible() {
    let reported = DeviceCatalog.sensorSize(
      reportedHundredthsMM: (16000, 11500), familyID: 130, kind: .externalTrackpad)
    #expect(reported.size == Size2D(width: 160, height: 115) && !reported.usedFallback)
    let missing = DeviceCatalog.sensorSize(reportedHundredthsMM: nil, familyID: 129, kind: .externalTrackpad)
    #expect(missing.usedFallback && missing.size == Size2D(width: 160, height: 115))
    let bogus = DeviceCatalog.sensorSize(reportedHundredthsMM: (0, 5), familyID: 105, kind: .builtInTrackpad)
    #expect(
      bogus.usedFallback && bogus.size == DeviceCatalog.fallbackSensorSizeMM(familyID: 105, kind: .builtInTrackpad))
  }
}
