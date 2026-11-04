import Foundation
import Testing

@testable import EdgyCore

@Test func defaultConfigRoundTripsThroughJSON() throws {
  let data = try JSONEncoder().encode(EdgyConfig.defaults)
  let decoded = try JSONDecoder().decode(EdgyConfig.self, from: data)
  #expect(decoded == EdgyConfig.defaults)
}

@Test func appProfileOverridesDefault() {
  var config = EdgyConfig.defaults
  config.appProfiles["com.example.game"] = Profile(bindings: [], disabled: true)
  #expect(config.profile(for: "com.example.game").disabled)
  #expect(config.profile(for: "com.example.other") == config.defaultProfile)
  #expect(config.profile(for: nil) == config.defaultProfile)
}

@Test func traceFileRoundTrips() throws {
  let device = TouchDeviceInfo(
    id: 1, kind: .builtInTrackpad, sensorSizeMM: Size2D(width: 160, height: 100), familyID: 0)
  let contact = TouchContact(
    id: 1, state: .touching, position: Point2D(x: 0.98, y: 0.5), velocity: Vector2D(dx: 0, dy: 0.2),
    majorAxisMM: 9, minorAxisMM: 8, angle: 0, size: 0.5, density: 0.5)
  let trace = TraceFile(
    label: "unit", expectation: "round trip", device: device,
    frames: [TouchFrame(deviceID: 1, timestamp: 0, frameNumber: 0, contacts: [contact])])
  let url = FileManager.default.temporaryDirectory.appendingPathComponent("edgy-trace-test.json")
  try trace.write(to: url)
  #expect(try TraceFile.load(from: url) == trace)
}
