import EdgyCore
import Foundation

/// One device as seen by a backend enumeration. `handle` is the backend's opaque device reference
/// (nil in fakes). Handles are only valid until the next enumeration that replaces them.
public struct BackendDevice: @unchecked Sendable {
  public var info: TouchDeviceInfo
  public var handle: UnsafeMutableRawPointer?

  public init(info: TouchDeviceInfo, handle: UnsafeMutableRawPointer? = nil) {
    self.info = info
    self.handle = handle
  }
}

/// The raw multitouch layer, behind a protocol so device management is testable with fakes.
public protocol MultitouchBackend: AnyObject, Sendable {
  func enumerateDevices() -> [BackendDevice]
  /// Start delivering frames for `device`. Returns false if registration failed (retried on the
  /// next refresh).
  func register(_ device: BackendDevice, onFrame: @escaping @Sendable (TouchFrame) -> Void) -> Bool
  func unregister(_ device: BackendDevice)
}

public enum DeviceChangeEvent: Sendable, Equatable {
  /// A device appeared (hot-plug).
  case attached
  /// A device went away.
  case detached
  /// The system woke from sleep: device references may be stale, so everything re-registers.
  case woke
  /// Explicit refresh request.
  case manual
}

/// Hot-plug + sleep/wake signal, behind a protocol so tests never touch IOKit.
public protocol DeviceChangeNotifying: AnyObject, Sendable {
  /// Returns false if notifications could not be set up (the caller still works, without hot-plug).
  func start(_ handler: @escaping @Sendable (DeviceChangeEvent) -> Void) -> Bool
  func stop()
}

/// Difference between two device lists, keyed by device ID.
public struct DeviceDiff: Equatable, Sendable {
  public var added: [TouchDeviceInfo] = []
  public var removed: [TouchDeviceInfo] = []
  /// Same ID, different description (e.g. sensor size resolved differently).
  public var changed: [TouchDeviceInfo] = []
  public var unchanged: [TouchDeviceInfo] = []

  public var isEmpty: Bool { added.isEmpty && removed.isEmpty && changed.isEmpty }

  public static func between(old: [TouchDeviceInfo], new: [TouchDeviceInfo]) -> DeviceDiff {
    var diff = DeviceDiff()
    let oldByID = Dictionary(old.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    let newIDs = Set(new.map(\.id))
    for device in new {
      if let previous = oldByID[device.id] {
        if previous == device { diff.unchanged.append(device) } else { diff.changed.append(device) }
      } else {
        diff.added.append(device)
      }
    }
    diff.removed = old.filter { !newIDs.contains($0.id) }
    return diff
  }
}

/// Owns the set of registered devices: enumerates, diffs, (re-)registers callbacks exactly once
/// per live device, and reports device-list changes.
public final class DeviceManager: @unchecked Sendable {
  private let backend: MultitouchBackend
  private let notifier: DeviceChangeNotifying

  /// Serializes refreshes and protects registration bookkeeping.
  private let refreshLock = NSLock()
  private var registered: [UInt64: BackendDevice] = [:]
  private var current: [TouchDeviceInfo] = []
  private var running = false

  /// Protects the handlers (read on the frame path, which must not wait on a refresh).
  private let handlerLock = NSLock()
  private var onFrame: (@Sendable (TouchFrame) -> Void)?
  private var onDevicesChanged: (@Sendable ([TouchDeviceInfo]) -> Void)?

  public init(backend: MultitouchBackend, notifier: DeviceChangeNotifying) {
    self.backend = backend
    self.notifier = notifier
  }

  public var devices: [TouchDeviceInfo] {
    refreshLock.withLock { current }
  }

  public var registeredDeviceIDs: Set<UInt64> {
    refreshLock.withLock { Set(registered.keys) }
  }

  public var isRunning: Bool { refreshLock.withLock { running } }

  /// Starts (or, if already running, swaps handlers and refreshes). Always reports the current
  /// device list once.
  public func start(
    onFrame: @escaping @Sendable (TouchFrame) -> Void,
    onDevicesChanged: @escaping @Sendable ([TouchDeviceInfo]) -> Void
  ) {
    handlerLock.withLock {
      self.onFrame = onFrame
      self.onDevicesChanged = onDevicesChanged
    }
    let wasRunning = refreshLock.withLock { () -> Bool in
      defer { running = true }
      return running
    }
    if !wasRunning {
      let ok = notifier.start { [weak self] event in self?.handle(event) }
      if !ok { TouchKitLog.touch.error("hot-plug notifications unavailable; device list will not auto-refresh") }
    }
    refresh(reregisterAll: false, alwaysNotify: true)
  }

  public func stop() {
    notifier.stop()
    refreshLock.withLock {
      for device in registered.values { backend.unregister(device) }
      registered.removeAll()
      running = false
    }
    handlerLock.withLock {
      onFrame = nil
      onDevicesChanged = nil
    }
  }

  public func handle(_ event: DeviceChangeEvent) {
    guard isRunning else { return }
    refresh(reregisterAll: event == .woke, alwaysNotify: false)
  }

  private func refresh(reregisterAll: Bool, alwaysNotify: Bool) {
    let notifyList: [TouchDeviceInfo]? = refreshLock.withLock {
      guard running else { return nil }
      var seen = Set<UInt64>()
      let found = backend.enumerateDevices().filter { seen.insert($0.info.id).inserted }
      let infos = found.map(\.info)
      let diff = DeviceDiff.between(old: current, new: infos)

      var drop = Set(diff.removed.map(\.id)).union(diff.changed.map(\.id))
      if reregisterAll { drop.formUnion(registered.keys) }
      // Anything registered but no longer enumerated must go too, even if `current` missed it.
      drop.formUnion(registered.keys.filter { id in !found.contains { $0.info.id == id } })
      for id in drop.sorted() {
        if let device = registered.removeValue(forKey: id) { backend.unregister(device) }
      }

      let sink: @Sendable (TouchFrame) -> Void = { [weak self] frame in self?.deliver(frame) }
      for device in found where registered[device.info.id] == nil {
        if backend.register(device, onFrame: sink) {
          registered[device.info.id] = device
        } else {
          TouchKitLog.touch.error("registering device \(device.info.id) failed; will retry on next refresh")
        }
      }
      current = infos
      return (alwaysNotify || !diff.isEmpty) ? infos : nil
    }
    if let notifyList {
      let handler = handlerLock.withLock { onDevicesChanged }
      handler?(notifyList)
    }
  }

  private func deliver(_ frame: TouchFrame) {
    let handler = handlerLock.withLock { onFrame }
    handler?(frame)
  }
}
