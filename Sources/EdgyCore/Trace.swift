import Foundation

/// A recorded touch stream, replayed in tests so misfire defense is regression-tested.
/// Files live as JSON under `Fixtures/traces/` (real recordings) and
/// `Tests/GesturesTests/Fixtures/` (fixtures the Gestures tests load).
public struct TraceFile: Codable, Hashable, Sendable {
  public static let currentSchemaVersion = 1

  public var schemaVersion: Int
  /// Short kebab-case label, e.g. "palm-rest-right", "deliberate-slide-right-up".
  public var label: String
  /// What the recording shows and what the pipeline is expected to do with it.
  public var expectation: String
  public var device: TouchDeviceInfo
  public var frames: [TouchFrame]

  public init(
    schemaVersion: Int = TraceFile.currentSchemaVersion, label: String, expectation: String,
    device: TouchDeviceInfo, frames: [TouchFrame]
  ) {
    self.schemaVersion = schemaVersion
    self.label = label
    self.expectation = expectation
    self.device = device
    self.frames = frames
  }

  public static func load(from url: URL) throws -> TraceFile {
    try JSONDecoder().decode(TraceFile.self, from: Data(contentsOf: url))
  }

  public func write(to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(self).write(to: url)
  }
}
