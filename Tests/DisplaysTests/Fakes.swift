import CoreGraphics
import Foundation

@testable import Displays

/// In-memory CoreGraphics stand-in.
final class FakeDisplaySystem: DisplaySystem, @unchecked Sendable {
  private let lock = NSLock()
  private var _displays: [DisplayDescriptor]
  private var _main: UInt32?
  private var _pointer: CGPoint?
  private var _names: [UInt32: String] = [:]
  private var handlers: [@Sendable () -> Void] = []

  init(_ displays: [DisplayDescriptor] = [], main: UInt32? = nil, pointer: CGPoint? = nil) {
    _displays = displays
    _main = main ?? displays.first?.id
    _pointer = pointer
  }

  var displays: [DisplayDescriptor] {
    get { lock.withLock { _displays } }
    set { lock.withLock { _displays = newValue } }
  }
  var pointer: CGPoint? {
    get { lock.withLock { _pointer } }
    set { lock.withLock { _pointer = newValue } }
  }
  var main: UInt32? {
    get { lock.withLock { _main } }
    set { lock.withLock { _main = newValue } }
  }
  var observerCount: Int { lock.withLock { handlers.count } }

  func setName(_ name: String, for id: UInt32) { lock.withLock { _names[id] = name } }

  /// Simulates a burst of reconfiguration callbacks.
  func fireReconfiguration(times: Int = 1) {
    let handlers = lock.withLock { self.handlers }
    for _ in 0..<times {
      for handler in handlers { handler() }
    }
  }

  func onlineDisplays() -> [DisplayDescriptor] { displays }
  func mainDisplayID() -> UInt32? { main }
  func pointerLocation() -> CGPoint? { pointer }
  func localizedName(of id: UInt32) -> String? { lock.withLock { _names[id] } }
  func observeReconfiguration(_ handler: @escaping @Sendable () -> Void) { lock.withLock { handlers.append(handler) } }
}

final class FakeBacklight: BacklightService, @unchecked Sendable {
  private let lock = NSLock()
  private var levels: [UInt32: Double]
  private(set) var writes: [(UInt32, Double)] = []

  init(_ levels: [UInt32: Double] = [:]) { self.levels = levels }

  func brightness(of id: UInt32) -> Double? { lock.withLock { levels[id] } }
  func setBrightness(_ level: Double, of id: UInt32) -> Bool {
    lock.withLock {
      guard levels[id] != nil else { return false }
      levels[id] = level
      writes.append((id, level))
      return true
    }
  }
}

/// A monitor answering DDC/CI on a fake I²C channel.
final class FakeMonitor: DDCTransport, @unchecked Sendable {
  enum Behavior {
    case normal
    /// Reads return nothing.
    case silent
    /// Reads fail with an I/O error.
    case readError
    /// Every reply says the feature is unsupported.
    case unsupported
    /// Writes (set-VCP) fail.
    case writeError
  }

  struct IOFailure: Error {}

  private let lock = NSLock()
  private var current: UInt16
  private let maximum: UInt16
  private var behavior: Behavior
  private var _setValues: [UInt16] = []
  private var _requests = 0

  init(current: UInt16 = 50, maximum: UInt16 = 100, behavior: Behavior = .normal) {
    self.current = current
    self.maximum = maximum
    self.behavior = behavior
  }

  var setValues: [UInt16] { lock.withLock { _setValues } }
  var readRequests: Int { lock.withLock { _requests } }
  func become(_ behavior: Behavior) { lock.withLock { self.behavior = behavior } }

  func write(_ message: [UInt8]) throws {
    try lock.withLock {
      if message.count == 7, message[2] == DDC.setVCPOpcode {
        if behavior == .writeError { throw IOFailure() }
        current = UInt16(message[4]) << 8 | UInt16(message[5])
        _setValues.append(current)
      } else {
        _requests += 1
      }
    }
  }

  func read(count: Int) throws -> [UInt8] {
    try lock.withLock {
      switch behavior {
      case .silent: return []
      case .readError: throw IOFailure()
      case .unsupported: return FakeMonitor.reply(result: 1, current: 0, maximum: 0)
      case .normal, .writeError: return FakeMonitor.reply(result: 0, current: current, maximum: maximum)
      }
    }
  }

  static func reply(result: UInt8, current: UInt16, maximum: UInt16, code: UInt8 = DDC.luminance) -> [UInt8] {
    var bytes: [UInt8] = [
      0x6E, 0x88, 0x02, result, code, 0x00, UInt8(maximum >> 8), UInt8(maximum & 0xFF), UInt8(current >> 8),
      UInt8(current & 0xFF),
    ]
    bytes.append(bytes.reduce(0x50, ^))
    return bytes
  }
}

final class FakeRegistry: AVServiceRegistry, @unchecked Sendable {
  private let lock = NSLock()
  private var _nodes: [RegistryNode]
  private var _walks = 0

  init(_ nodes: [RegistryNode] = []) { _nodes = nodes }

  var nodesList: [RegistryNode] {
    get { lock.withLock { _nodes } }
    set { lock.withLock { _nodes = newValue } }
  }
  var walks: Int { lock.withLock { _walks } }

  func nodes() -> [RegistryNode] {
    lock.withLock {
      _walks += 1
      return _nodes
    }
  }
}

func descriptor(
  _ id: UInt32, builtIn: Bool = false, vendor: UInt32 = 0x1234, product: UInt32 = 1, serial: UInt32 = 0,
  bounds: CGRect = .zero
) -> DisplayDescriptor {
  DisplayDescriptor(id: id, isBuiltIn: builtIn, vendorID: vendor, productID: product, serial: serial, bounds: bounds)
}

func attributes(vendor: UInt32 = 0x1234, product: UInt32 = 1, serial: UInt32 = 0, name: String? = nil)
  -> ProductAttributes
{
  ProductAttributes(vendorID: vendor, productID: product, serial: serial, name: name)
}

/// A test rig: fakes plus a controller wired to them. Nothing touches the real system.
struct Rig {
  let system: FakeDisplaySystem
  let backlight: FakeBacklight
  let registry: FakeRegistry
  let scheduler = ManualScheduler()
  let controller: LiveDisplayBrightness

  init(
    system: FakeDisplaySystem, backlight: FakeBacklight = FakeBacklight(), registry: FakeRegistry = FakeRegistry(),
    appleSilicon: Bool = true
  ) {
    self.system = system
    self.backlight = backlight
    self.registry = registry
    let scheduler = self.scheduler
    controller = LiveDisplayBrightness(
      environment: DisplayEnvironment(
        system: system, backlight: backlight, registry: registry, isAppleSilicon: { appleSilicon },
        pause: { _ in }, makeScheduler: { _ in scheduler }))
  }
}
