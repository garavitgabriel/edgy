import EdgyCore
import Foundation
import Testing

@testable import TouchKit

@Suite struct TraceRecorderTests {
  func contact(_ id: Int32, x: Double) -> TouchContact {
    TouchContact(
      id: id, state: .touching, position: Point2D(x: x, y: 0.5), velocity: Vector2D(dx: 0.1, dy: 0),
      majorAxisMM: 11, minorAxisMM: 9, angle: 0.3, size: 0.8, density: 2)
  }

  @Test func writesTraceFileThatRoundTrips() throws {
    let recorder = try TraceRecorder(label: "deliberate-slide-right-up", expectation: "slide up on the right edge")
    recorder.append(TouchFrame(deviceID: 7, timestamp: 50, frameNumber: 1, contacts: [contact(1, x: 0.95)]))
    recorder.append(TouchFrame(deviceID: 7, timestamp: 50.008, frameNumber: 2, contacts: [contact(1, x: 0.96)]))
    recorder.append(TouchFrame(deviceID: 7, timestamp: 50.016, frameNumber: 3, contacts: []))
    let trace = recorder.makeTrace(device: device(7))

    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("edgy-trace-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let url = dir.appendingPathComponent("deliberate-slide-right-up.json")
    try trace.write(to: url)
    let loaded = try TraceFile.load(from: url)

    #expect(loaded == trace)
    #expect(loaded.schemaVersion == TraceFile.currentSchemaVersion)
    #expect(loaded.label == "deliberate-slide-right-up")
    #expect(loaded.frames.count == 3)
    #expect(loaded.frames.first?.timestamp == 0)
    #expect(abs((loaded.frames.last?.timestamp ?? 0) - 0.016) < 1e-9)
  }

  @Test func buttonDownRoundTripsThroughATraceFile() throws {
    let recorder = try TraceRecorder(label: "click-drag-right-edge", expectation: "never a gesture")
    recorder.append(TouchFrame(deviceID: 7, timestamp: 50, frameNumber: 1, contacts: [contact(1, x: 0.96)]))
    recorder.append(
      TouchFrame(deviceID: 7, timestamp: 50.008, frameNumber: 2, contacts: [contact(1, x: 0.96)], buttonDown: true))
    recorder.append(TouchFrame(deviceID: 7, timestamp: 50.016, frameNumber: 3, contacts: []))
    let trace = recorder.makeTrace(device: device(7))

    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("edgy-trace-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let url = dir.appendingPathComponent("click-drag-right-edge.json")
    try trace.write(to: url)
    let loaded = try TraceFile.load(from: url)
    #expect(loaded.frames.map(\.buttonDown) == [false, true, false])
    #expect(loaded == trace)
    #expect(try String(contentsOf: url, encoding: .utf8).contains("\"buttonDown\" : true"))
  }

  @Test func traceWithoutButtonDownDecodesAsButtonUp() throws {
    // Traces recorded before v0.4 have no `buttonDown` key.
    let json = """
      {"schemaVersion": 1, "label": "old", "expectation": "",
       "device": {"id": 7, "kind": "builtInTrackpad", "sensorSizeMM": {"width": 150, "height": 95}, "familyID": 0},
       "frames": [{"deviceID": 7, "timestamp": 0, "frameNumber": 1, "contacts": []}]}
      """
    let trace = try JSONDecoder().decode(TraceFile.self, from: Data(json.utf8))
    #expect(trace.frames.map(\.buttonDown) == [false])
  }

  @Test func liveLineMarksTheButton() {
    let down = TouchFrame(deviceID: 7, timestamp: 1, frameNumber: 1, contacts: [], buttonDown: true)
    let up = TouchFrame(deviceID: 7, timestamp: 1, frameNumber: 1, contacts: [])
    #expect(FrameFormatter.line(down).contains("BUTTON"))
    #expect(!FrameFormatter.line(up).contains("BUTTON"))
  }

  @Test func locksOntoOneDevice() throws {
    let recorder = try TraceRecorder(label: "palm-rest-right", expectation: "nothing fires")
    recorder.append(TouchFrame(deviceID: 2, timestamp: 1, frameNumber: 1, contacts: []))
    recorder.append(TouchFrame(deviceID: 3, timestamp: 1, frameNumber: 1, contacts: []))
    recorder.append(TouchFrame(deviceID: 2, timestamp: 2, frameNumber: 2, contacts: []))
    #expect(recorder.deviceID == 2 && recorder.frameCount == 2)

    let pinned = try TraceRecorder(label: "x", expectation: "", deviceID: 3)
    pinned.append(TouchFrame(deviceID: 2, timestamp: 1, frameNumber: 1, contacts: []))
    #expect(pinned.frameCount == 0)
  }

  @Test func keepsTimestampsWhenNotRebasing() throws {
    let recorder = try TraceRecorder(label: "x", expectation: "")
    recorder.append(TouchFrame(deviceID: 1, timestamp: 5, frameNumber: 1, contacts: []))
    #expect(recorder.makeTrace(device: device(1), rebaseTimestamps: false).frames.first?.timestamp == 5)
  }

  @Test func validatesKebabCaseLabels() {
    #expect(TraceRecorder.isValidLabel("double-tap-top-right-corner"))
    #expect(TraceRecorder.isValidLabel("a1"))
    for bad in ["", "Palm", "palm rest", "palm--rest", "-palm", "palm-", "palm_rest"] {
      #expect(!TraceRecorder.isValidLabel(bad), "\(bad)")
    }
    #expect(throws: TraceRecorder.RecorderError.invalidLabel("Bad")) {
      try TraceRecorder(label: "Bad", expectation: "")
    }
  }

  @Test func formatsCompactLiveLine() {
    let line = FrameFormatter.line(
      TouchFrame(deviceID: 9, timestamp: 1.5, frameNumber: 4, contacts: [contact(2, x: 0.5)]))
    #expect(line.contains("dev=9") && line.contains("n=1") && line.contains("[2 touch (0.500,0.500)"))
    #expect(line.contains("11.0x9.0mm"))
  }
}
