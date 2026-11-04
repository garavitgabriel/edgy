import EdgyCore
import Foundation

public enum ConfigStoreError: Error, Equatable, CustomStringConvertible {
  /// The file was written by a different (usually newer) version of Edgy. The original is kept at `backupPath`.
  case unsupportedSchemaVersion(found: Int, supported: Int, backupPath: String)
  /// The file is not valid config JSON. The original is kept at `backupPath`.
  case malformed(reason: String, backupPath: String)

  public var description: String {
    switch self {
    case .unsupportedSchemaVersion(let found, let supported, let backupPath):
      return
        "Config schemaVersion \(found) is not supported (this build reads version \(supported)). "
        + "Your file was backed up to \(backupPath); built-in defaults are in use."
    case .malformed(let reason, let backupPath):
      return
        "Config file could not be read (\(reason)). It was backed up to \(backupPath); built-in defaults are in use."
    }
  }
}

/// Loads, saves and watches the JSON config file.
///
/// The file is pretty-printed with sorted keys so it stays hand-editable. A failed load leaves the
/// in-memory config at its previous value (built-in defaults on first load) so the app keeps running.
public final class ConfigStore: @unchecked Sendable {
  public static var defaultFileURL: URL {
    FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Application Support/Edgy/config.json")
  }

  public let fileURL: URL
  public var backupURL: URL {
    fileURL.deletingLastPathComponent().appendingPathComponent(fileURL.lastPathComponent + ".bak")
  }

  private let logger: EdgyLogging
  private let debounce: TimeInterval
  private let watchQueue = DispatchQueue(label: "com.garavit.edgy.config-watch")

  // Guarded by `lock`.
  private let lock = NSLock()
  private var current: EdgyConfig = .defaults
  /// Bytes most recently loaded or saved; a watcher event whose file matches them is ignored, which
  /// also stops our own saves from echoing back as reloads.
  private var lastSeenData: Data?

  // Confined to `watchQueue`.
  private var directorySource: DispatchSourceFileSystemObject?
  private var fileSource: DispatchSourceFileSystemObject?
  private var pendingReload: DispatchWorkItem?
  private var onChange: (@Sendable (EdgyConfig) -> Void)?

  public init(
    fileURL: URL = ConfigStore.defaultFileURL, debounce: TimeInterval = 0.3,
    logger: EdgyLogging = SystemLogger(category: "config")
  ) {
    self.fileURL = fileURL
    self.debounce = debounce
    self.logger = logger
  }

  deinit {
    directorySource?.cancel()
    fileSource?.cancel()
  }

  /// The most recently loaded or saved config.
  public var config: EdgyConfig { lock.withLock { current } }

  /// Reads the file, creating it with defaults on first run.
  @discardableResult
  public func load() throws -> EdgyConfig {
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      try save(.defaults)
      logger.log(.info, "Created default config at \(fileURL.path)")
      return .defaults
    }
    let data = try Data(contentsOf: fileURL)
    let config = try decode(data)
    lock.withLock {
      current = config
      lastSeenData = data
    }
    return config
  }

  public func save(_ config: EdgyConfig) throws {
    let data = try Self.encode(config)
    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: fileURL, options: .atomic)
    lock.withLock {
      current = config
      lastSeenData = data
    }
  }

  /// Watches the file (and its directory, so editors that save via rename are seen) and calls
  /// `onChange` on a background queue after edits settle for the debounce interval.
  public func startWatching(onChange: @escaping @Sendable (EdgyConfig) -> Void) {
    try? FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    watchQueue.sync {
      self.onChange = onChange
      armDirectorySource()
      armFileSource()
    }
  }

  public func stopWatching() {
    watchQueue.sync {
      pendingReload?.cancel()
      pendingReload = nil
      directorySource?.cancel()
      directorySource = nil
      fileSource?.cancel()
      fileSource = nil
      onChange = nil
    }
  }

  static func encode(_ config: EdgyConfig) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    var data = try encoder.encode(config)
    data.append(0x0A)
    return data
  }

  private func decode(_ data: Data) throws -> EdgyConfig {
    struct SchemaProbe: Decodable { var schemaVersion: Int }
    let version: Int
    do {
      version = try JSONDecoder().decode(SchemaProbe.self, from: data).schemaVersion
    } catch {
      throw ConfigStoreError.malformed(reason: Self.describe(error), backupPath: try backUp(data))
    }
    guard version == EdgyConfig.currentSchemaVersion else {
      throw ConfigStoreError.unsupportedSchemaVersion(
        found: version, supported: EdgyConfig.currentSchemaVersion, backupPath: try backUp(data))
    }
    do {
      return try JSONDecoder().decode(EdgyConfig.self, from: data)
    } catch {
      throw ConfigStoreError.malformed(reason: Self.describe(error), backupPath: try backUp(data))
    }
  }

  private func backUp(_ data: Data) throws -> String {
    try data.write(to: backupURL, options: .atomic)
    return backupURL.path
  }

  private static func describe(_ error: Error) -> String {
    if case .dataCorrupted(let ctx) = error as? DecodingError { return ctx.debugDescription }
    if case .keyNotFound(let key, _) = error as? DecodingError { return "missing key '\(key.stringValue)'" }
    if case .typeMismatch(_, let ctx) = error as? DecodingError {
      return "wrong type at \(ctx.codingPath.map(\.stringValue).joined(separator: "."))"
    }
    return String(describing: error)
  }

  // MARK: Watching (watchQueue only)

  private func armDirectorySource() {
    directorySource?.cancel()
    directorySource = makeSource(path: fileURL.deletingLastPathComponent().path, mask: [.write, .rename, .delete])
  }

  private func armFileSource() {
    fileSource?.cancel()
    fileSource = makeSource(path: fileURL.path, mask: [.write, .extend, .rename, .delete, .attrib])
  }

  private func makeSource(path: String, mask: DispatchSource.FileSystemEvent) -> DispatchSourceFileSystemObject? {
    let fd = open(path, O_EVTONLY)
    guard fd >= 0 else { return nil }
    let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: mask, queue: watchQueue)
    source.setEventHandler { [weak self] in self?.scheduleReload() }
    source.setCancelHandler { close(fd) }
    source.resume()
    return source
  }

  private func scheduleReload() {
    pendingReload?.cancel()
    let item = DispatchWorkItem { [weak self] in self?.reloadFromDisk() }
    pendingReload = item
    watchQueue.asyncAfter(deadline: .now() + debounce, execute: item)
  }

  private func reloadFromDisk() {
    guard onChange != nil else { return }
    // Editors often replace the file; re-open so later in-place writes are still seen.
    armFileSource()
    guard let data = try? Data(contentsOf: fileURL) else { return }
    if lock.withLock({ lastSeenData == data }) { return }
    do {
      let config = try decode(data)
      lock.withLock {
        current = config
        lastSeenData = data
      }
      logger.log(.info, "Config reloaded from disk")
      onChange?(config)
    } catch {
      lock.withLock { lastSeenData = data }
      logger.log(.error, "Config reload failed: \(error)")
    }
  }
}
