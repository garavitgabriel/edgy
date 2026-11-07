import AppKit
import CoreGraphics
import Foundation
import IOKit

// Live implementations of the seams in `Seams.swift`. Never used by tests: every type here is an
// empty value until a method is called, and private symbols resolve on first use.

extension DisplayEnvironment {
  static func live() -> DisplayEnvironment {
    DisplayEnvironment(
      system: LiveDisplaySystem(), backlight: LiveBacklight(), registry: LiveAVServiceRegistry(),
      isAppleSilicon: { isAppleSiliconMac() }, pause: { Thread.sleep(forTimeInterval: $0) },
      makeScheduler: { DispatchScheduler(label: $0) })
  }
}

/// True on Apple silicon (also when running translated).
func isAppleSiliconMac() -> Bool {
  var value: Int32 = 0
  var size = MemoryLayout<Int32>.size
  return sysctlbyname("hw.optional.arm64", &value, &size, nil, 0) == 0 && value == 1
}

// MARK: - CoreGraphics

struct LiveDisplaySystem: DisplaySystem {
  func onlineDisplays() -> [DisplayDescriptor] {
    var count: UInt32 = 0
    guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
    var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
    guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { return [] }
    return ids.prefix(Int(count)).map { id in
      DisplayDescriptor(
        id: id, isBuiltIn: CGDisplayIsBuiltin(id) != 0, vendorID: CGDisplayVendorNumber(id),
        productID: CGDisplayModelNumber(id), serial: CGDisplaySerialNumber(id), bounds: CGDisplayBounds(id))
    }
  }

  func mainDisplayID() -> UInt32? {
    let id = CGMainDisplayID()
    return id == 0 ? nil : id
  }

  func pointerLocation() -> CGPoint? { CGEvent(source: nil)?.location }

  /// Screen names live in AppKit, which is main-thread only; elsewhere the registry name is used.
  func localizedName(of id: UInt32) -> String? {
    guard Thread.isMainThread else { return nil }
    return MainActor.assumeIsolated {
      NSScreen.screens.first {
        ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == id
      }?.localizedName
    }
  }

  func observeReconfiguration(_ handler: @escaping @Sendable () -> Void) {
    // Retained for the life of the process: the controller observes once and is never torn down.
    let box = Unmanaged.passRetained(ReconfigurationHandler(handler)).toOpaque()
    let status = CGDisplayRegisterReconfigurationCallback(
      { _, flags, userInfo in
        guard let userInfo, !flags.contains(.beginConfigurationFlag) else { return }
        Unmanaged<ReconfigurationHandler>.fromOpaque(userInfo).takeUnretainedValue().handler()
      }, box)
    if status != .success {
      displaysLog.error("display change notifications unavailable (\(status.rawValue)); displays won't re-probe")
    }
  }

  private final class ReconfigurationHandler: Sendable {
    let handler: @Sendable () -> Void
    init(_ handler: @escaping @Sendable () -> Void) { self.handler = handler }
  }
}

// MARK: - DisplayServices (built-in and Apple displays)

/// Private DisplayServices brightness, resolved by name on first use; a lookup failure makes
/// every display read as unreadable, with one log line.
struct LiveBacklight: BacklightService {
  private typealias GetFn = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
  private typealias SetFn = @convention(c) (UInt32, Float) -> Int32

  private struct Symbols: @unchecked Sendable {
    var get: GetFn
    var set: SetFn
  }

  private static let symbols: Symbols? = {
    let path = "/System/Library/PrivateFrameworks/DisplayServices.framework"
    guard let bundle = CFBundleCreate(kCFAllocatorDefault, URL(fileURLWithPath: path) as CFURL) else {
      displaysLog.error("display brightness unavailable: cannot open \(path, privacy: .public)")
      return nil
    }
    guard
      let get = CFBundleGetFunctionPointerForName(bundle, "DisplayServicesGetBrightness" as CFString),
      let set = CFBundleGetFunctionPointerForName(bundle, "DisplayServicesSetBrightness" as CFString)
    else {
      displaysLog.error("display brightness unavailable: brightness functions not found")
      return nil
    }
    return Symbols(get: unsafeBitCast(get, to: GetFn.self), set: unsafeBitCast(set, to: SetFn.self))
  }()

  func brightness(of id: UInt32) -> Double? {
    guard let symbols = Self.symbols else { return nil }
    var value: Float = 0
    guard symbols.get(id, &value) == 0, value.isFinite else { return nil }
    return Double(value)
  }

  func setBrightness(_ level: Double, of id: UInt32) -> Bool {
    guard let symbols = Self.symbols else { return false }
    return symbols.set(id, Float(level)) == 0
  }
}

// MARK: - IORegistry + I²C (third-party monitors on Apple silicon)

/// The private IOAVService functions in IOKit, resolved by name on first use.
struct IOAVSymbols: @unchecked Sendable {
  typealias CreateFn = @convention(c) (CFAllocator?, io_service_t) -> Unmanaged<CFTypeRef>?
  typealias TransferFn = @convention(c) (CFTypeRef, UInt32, UInt32, UnsafeMutableRawPointer, UInt32) -> IOReturn

  var create: CreateFn
  var read: TransferFn
  var write: TransferFn

  static let shared: IOAVSymbols? = {
    let path = "/System/Library/Frameworks/IOKit.framework"
    guard let bundle = CFBundleCreate(kCFAllocatorDefault, URL(fileURLWithPath: path) as CFURL) else {
      displaysLog.error("external brightness unavailable: cannot open \(path, privacy: .public)")
      return nil
    }
    guard
      let create = CFBundleGetFunctionPointerForName(bundle, "IOAVServiceCreateWithService" as CFString),
      let read = CFBundleGetFunctionPointerForName(bundle, "IOAVServiceReadI2C" as CFString),
      let write = CFBundleGetFunctionPointerForName(bundle, "IOAVServiceWriteI2C" as CFString)
    else {
      displaysLog.error("external brightness unavailable: display I2C functions not found")
      return nil
    }
    return IOAVSymbols(
      create: unsafeBitCast(create, to: CreateFn.self), read: unsafeBitCast(read, to: TransferFn.self),
      write: unsafeBitCast(write, to: TransferFn.self))
  }()
}

struct LiveAVServiceRegistry: AVServiceRegistry {
  /// Registry class of the per-display audio/video service on Apple silicon.
  static let serviceClass = "DCPAVServiceProxy"

  func nodes() -> [RegistryNode] {
    guard let symbols = IOAVSymbols.shared else { return [] }
    var iterator: io_iterator_t = 0
    let status = IORegistryCreateIterator(
      kIOMainPortDefault, kIOServicePlane, IOOptionBits(kIORegistryIterateRecursively), &iterator)
    guard status == KERN_SUCCESS else {
      displaysLog.error("display registry walk failed (\(status))")
      return []
    }
    defer { IOObjectRelease(iterator) }

    var nodes: [RegistryNode] = []
    while case let entry = IOIteratorNext(iterator), entry != 0 {
      defer { IOObjectRelease(entry) }
      if let attributes = property(entry, "DisplayAttributes") as? [String: Any] {
        nodes.append(.display(Self.productAttributes(attributes)))
      } else if IOObjectConformsTo(entry, Self.serviceClass) != 0 {
        let external = (property(entry, "Location") as? String) == "External"
        var transport: (any DDCTransport)?
        if external, let service = symbols.create(kCFAllocatorDefault, entry)?.takeRetainedValue() {
          transport = LiveI2CTransport(service: service, symbols: symbols)
        }
        nodes.append(.avService(external: external, transport: transport))
      }
    }
    return nodes
  }

  private func property(_ entry: io_registry_entry_t, _ key: String) -> Any? {
    IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
  }

  static func productAttributes(_ displayAttributes: [String: Any]) -> ProductAttributes {
    let product = displayAttributes["ProductAttributes"] as? [String: Any] ?? [:]
    func number(_ key: String) -> UInt32? { (product[key] as? NSNumber)?.uint32Value }
    return ProductAttributes(
      vendorID: number("LegacyManufacturerID"), productID: number("ProductID"), serial: number("SerialNumber"),
      name: product["ProductName"] as? String)
  }
}

/// DDC/CI over one monitor's AV service. All transfers, to every monitor, are serialized.
final class LiveI2CTransport: DDCTransport, @unchecked Sendable {
  /// Sub-address used for reads; the DDC/CI host address, as for writes.
  static let readOffset: UInt32 = UInt32(DDC.hostSource)
  private static let transferLock = NSLock()

  struct TransferError: Error, CustomStringConvertible {
    var operation: String
    var status: IOReturn
    var description: String { "I2C \(operation) failed (0x\(String(UInt32(bitPattern: status), radix: 16)))" }
  }

  private let service: CFTypeRef
  private let symbols: IOAVSymbols

  init(service: CFTypeRef, symbols: IOAVSymbols) {
    self.service = service
    self.symbols = symbols
  }

  func write(_ message: [UInt8]) throws {
    guard let subAddress = message.first else { return }
    var payload = Array(message.dropFirst())
    let status = Self.transferLock.withLock {
      symbols.write(service, UInt32(DDC.chipAddress), UInt32(subAddress), &payload, UInt32(payload.count))
    }
    guard status == kIOReturnSuccess else { throw TransferError(operation: "write", status: status) }
  }

  func read(count: Int) throws -> [UInt8] {
    var buffer = [UInt8](repeating: 0, count: count)
    let status = Self.transferLock.withLock {
      symbols.read(service, UInt32(DDC.chipAddress), Self.readOffset, &buffer, UInt32(count))
    }
    guard status == kIOReturnSuccess else { throw TransferError(operation: "read", status: status) }
    return buffer
  }
}
