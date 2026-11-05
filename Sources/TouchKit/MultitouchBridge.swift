import CoreFoundation
import EdgyCore
import Foundation

// Live bridge to the private multitouch framework. Loaded at runtime by path; every function is
// resolved by name and every miss is logged. Nothing in this file is reachable from tests.

typealias MTDeviceRef = UnsafeMutableRawPointer
typealias MTContactCallbackRefcon =
  @convention(c) (MTDeviceRef?, UnsafeMutableRawPointer?, Int32, Double, Int32, UnsafeMutableRawPointer?) -> Int32
typealias MTContactCallback = @convention(c) (MTDeviceRef?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Int32

/// Runtime toggles for the open questions only hardware can answer (used by the smoke script).
enum MultitouchOptions {
  /// `EDGY_MT_SKIP_START=1`: do not call the device-start function after registering.
  static var skipStart: Bool { env("EDGY_MT_SKIP_START") }
  /// `EDGY_MT_RUNLOOP=1`: schedule devices on the main run loop (callbacks arrive on main).
  static var scheduleOnRunLoop: Bool { env("EDGY_MT_RUNLOOP") }
  /// `EDGY_MT_SKIP_LAYOUT_CHECK=1`: deliver frames even when the layout check fails.
  static var skipLayoutCheck: Bool { env("EDGY_MT_SKIP_LAYOUT_CHECK") }

  private static func env(_ key: String) -> Bool { ProcessInfo.processInfo.environment[key] == "1" }
}

final class MultitouchFramework: @unchecked Sendable {
  static let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework"

  /// Loaded once; nil (with `loadFailure` set) if the framework or a required symbol is missing.
  static let shared: MultitouchFramework? = MultitouchFramework()
  nonisolated(unsafe) private(set) static var loadFailure: String?

  let createList: @convention(c) () -> UnsafeMutableRawPointer?
  let getDeviceID: (@convention(c) (MTDeviceRef, UnsafeMutablePointer<UInt64>) -> Int32)?
  let getFamilyID: (@convention(c) (MTDeviceRef, UnsafeMutablePointer<Int32>) -> Int32)?
  let isBuiltIn: (@convention(c) (MTDeviceRef) -> Bool)?
  let getSensorSurfaceDimensions:
    (@convention(c) (MTDeviceRef, UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>) -> Int32)?
  let registerWithRefcon: (@convention(c) (MTDeviceRef, MTContactCallbackRefcon, UnsafeMutableRawPointer?) -> Void)?
  let registerPlain: (@convention(c) (MTDeviceRef, MTContactCallback) -> Void)?
  /// Takes the same function pointer that was registered (either flavour), passed as a raw pointer.
  let unregister: (@convention(c) (MTDeviceRef, UnsafeRawPointer?) -> Void)?
  let start: (@convention(c) (MTDeviceRef, Int32) -> Int32)?
  let stop: (@convention(c) (MTDeviceRef) -> Int32)?
  let scheduleOnRunLoop: (@convention(c) (MTDeviceRef, CFRunLoop, CFString) -> Void)?

  private init?() {
    let url = URL(fileURLWithPath: Self.path) as CFURL
    guard let bundle = CFBundleCreate(kCFAllocatorDefault, url) else {
      Self.fail("framework not found at \(Self.path)")
      return nil
    }
    func lookup<T>(_ name: String, as type: T.Type) -> T? {
      guard let p = CFBundleGetFunctionPointerForName(bundle, name as CFString) else {
        TouchKitLog.touch.error("multitouch: symbol \(name, privacy: .public) not found")
        return nil
      }
      return unsafeBitCast(p, to: type)
    }
    guard let createList = lookup("MTDeviceCreateList", as: (@convention(c) () -> UnsafeMutableRawPointer?).self)
    else {
      Self.fail("MTDeviceCreateList missing")
      return nil
    }
    self.createList = createList
    getDeviceID = lookup(
      "MTDeviceGetDeviceID", as: (@convention(c) (MTDeviceRef, UnsafeMutablePointer<UInt64>) -> Int32).self)
    getFamilyID = lookup(
      "MTDeviceGetFamilyID", as: (@convention(c) (MTDeviceRef, UnsafeMutablePointer<Int32>) -> Int32).self)
    isBuiltIn = lookup("MTDeviceIsBuiltIn", as: (@convention(c) (MTDeviceRef) -> Bool).self)
    getSensorSurfaceDimensions = lookup(
      "MTDeviceGetSensorSurfaceDimensions",
      as: (@convention(c) (MTDeviceRef, UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>) -> Int32).self)
    registerWithRefcon = lookup(
      "MTRegisterContactFrameCallbackWithRefcon",
      as: (@convention(c) (MTDeviceRef, MTContactCallbackRefcon, UnsafeMutableRawPointer?) -> Void).self)
    registerPlain = lookup(
      "MTRegisterContactFrameCallback", as: (@convention(c) (MTDeviceRef, MTContactCallback) -> Void).self)
    unregister = lookup(
      "MTUnregisterContactFrameCallback", as: (@convention(c) (MTDeviceRef, UnsafeRawPointer?) -> Void).self)
    start = lookup("MTDeviceStart", as: (@convention(c) (MTDeviceRef, Int32) -> Int32).self)
    stop = lookup("MTDeviceStop", as: (@convention(c) (MTDeviceRef) -> Int32).self)
    scheduleOnRunLoop = lookup(
      "MTDeviceScheduleOnRunLoop", as: (@convention(c) (MTDeviceRef, CFRunLoop, CFString) -> Void).self)
    if registerWithRefcon == nil && registerPlain == nil {
      Self.fail("no contact-frame registration function")
      return nil
    }
  }

  private static func fail(_ reason: String) {
    loadFailure = reason
    TouchKitLog.touch.error("multitouch unavailable: \(reason, privacy: .public)")
  }

  /// Current device references. The list is intentionally not released: releasing it has been
  /// seen to invalidate the device references, and enumeration only happens on device changes.
  func deviceRefs() -> [MTDeviceRef] {
    guard let raw = createList() else { return [] }
    let array = Unmanaged<CFArray>.fromOpaque(raw).takeUnretainedValue()
    return (0..<CFArrayGetCount(array)).compactMap { i in
      CFArrayGetValueAtIndex(array, i).map { UnsafeMutableRawPointer(mutating: $0) }
    }
  }
}

/// Per-registration state reached from the C callback.
final class DeviceCallbackContext: @unchecked Sendable {
  let deviceID: UInt64
  let converter: ContactConverter
  let onFrame: @Sendable (TouchFrame) -> Void
  // Mutated only on the device's callback thread (callbacks for one device are serial).
  var estimator = AxisScaleEstimator()
  var consecutiveLayoutFailures = 0
  var disabled = false
  var loggedFirstFrame = false

  init(deviceID: UInt64, converter: ContactConverter, onFrame: @escaping @Sendable (TouchFrame) -> Void) {
    self.deviceID = deviceID
    self.converter = converter
    self.onFrame = onFrame
  }

  func handle(contacts: UnsafeMutableRawPointer?, count: Int32, timestamp: Double, frame: Int32) {
    guard !disabled else { return }
    let n = Int(count)
    if !MultitouchOptions.skipLayoutCheck && !RawContactLayout.isConsistent(base: contacts, count: n, frame: frame) {
      consecutiveLayoutFailures += 1
      if consecutiveLayoutFailures >= 3 {
        disabled = true
        TouchKitLog.touch.fault(
          "device \(self.deviceID): contact layout check failed 3× in a row (stride \(RawContactLayout.stride)); device disabled"
        )
      }
      return
    }
    consecutiveLayoutFailures = 0
    let raws = (n > 0 && contacts != nil) ? RawContactLayout.readAll(from: contacts!, count: n) : []
    for raw in raws { estimator.observe(raw, sensorSizeMM: converter.sensorSizeMM) }
    if !loggedFirstFrame {
      loggedFirstFrame = true
      TouchKitLog.touch.notice("device \(self.deviceID): first frame received")
    }
    onFrame(
      converter.frame(
        deviceID: deviceID, timestamp: timestamp, frameNumber: frame, raws: raws, mmPerAxisUnit: estimator.mmPerUnit))
  }
}

/// Fallback registry for the callback flavour without a refcon, keyed by device reference.
final class PlainCallbackRegistry: @unchecked Sendable {
  static let shared = PlainCallbackRegistry()
  private let lock = NSLock()
  private var contexts: [UnsafeMutableRawPointer: DeviceCallbackContext] = [:]
  func set(_ context: DeviceCallbackContext?, for device: MTDeviceRef) { lock.withLock { contexts[device] = context } }
  func context(for device: MTDeviceRef) -> DeviceCallbackContext? { lock.withLock { contexts[device] } }
}

private let refconTrampoline: MTContactCallbackRefcon = { _, contacts, count, timestamp, frame, refcon in
  guard let refcon else { return 0 }
  Unmanaged<DeviceCallbackContext>.fromOpaque(refcon).takeUnretainedValue()
    .handle(contacts: contacts, count: count, timestamp: timestamp, frame: frame)
  return 0
}

private let plainTrampoline: MTContactCallback = { device, contacts, count, timestamp, frame in
  guard let device, let context = PlainCallbackRegistry.shared.context(for: device) else { return 0 }
  context.handle(contacts: contacts, count: count, timestamp: timestamp, frame: frame)
  return 0
}

final class LiveMultitouchBackend: MultitouchBackend, @unchecked Sendable {
  private let framework: MultitouchFramework
  private let lock = NSLock()
  private var active: [UInt64: (handle: MTDeviceRef, context: DeviceCallbackContext, usedRefcon: Bool)] = [:]
  /// Contexts of unregistered devices are kept alive: a callback already in flight on the device
  /// thread may still dereference its refcon. A few bytes per device change.
  private var retired: [DeviceCallbackContext] = []
  private var loggedFallback: Set<UInt64> = []

  init(framework: MultitouchFramework) {
    self.framework = framework
  }

  func enumerateDevices() -> [BackendDevice] {
    framework.deviceRefs().compactMap { ref in
      var id: UInt64 = 0
      if let getID = framework.getDeviceID {
        guard getID(ref, &id) == 0 else { return nil }
      } else {
        id = UInt64(UInt(bitPattern: ref))
      }
      var family: Int32 = 0
      _ = framework.getFamilyID?(ref, &family)
      let builtIn = framework.isBuiltIn?(ref) ?? false
      var w: Int32 = 0
      var h: Int32 = 0
      let reported: (width: Int32, height: Int32)? =
        (framework.getSensorSurfaceDimensions.map { $0(ref, &w, &h) == 0 } ?? false) ? (w, h) : nil
      let kind = DeviceCatalog.kind(familyID: family, isBuiltIn: builtIn)
      let sensor = DeviceCatalog.sensorSize(reportedHundredthsMM: reported, familyID: family, kind: kind)
      if sensor.usedFallback {
        let first = lock.withLock { loggedFallback.insert(id).inserted }
        if first {
          TouchKitLog.touch.notice(
            "device \(id) family \(family): no usable sensor size reported; using table \(sensor.size.width)×\(sensor.size.height) mm"
          )
        }
      }
      return BackendDevice(
        info: TouchDeviceInfo(id: id, kind: kind, sensorSizeMM: sensor.size, familyID: family), handle: ref)
    }
  }

  func register(_ device: BackendDevice, onFrame: @escaping @Sendable (TouchFrame) -> Void) -> Bool {
    guard let handle = device.handle else { return false }
    let context = DeviceCallbackContext(
      deviceID: device.info.id, converter: ContactConverter(sensorSizeMM: device.info.sensorSizeMM), onFrame: onFrame)
    let usedRefcon: Bool
    if let registerWithRefcon = framework.registerWithRefcon {
      registerWithRefcon(handle, refconTrampoline, Unmanaged.passUnretained(context).toOpaque())
      usedRefcon = true
    } else if let registerPlain = framework.registerPlain {
      PlainCallbackRegistry.shared.set(context, for: handle)
      registerPlain(handle, plainTrampoline)
      usedRefcon = false
    } else {
      return false
    }
    lock.withLock { active[device.info.id] = (handle, context, usedRefcon) }
    if MultitouchOptions.scheduleOnRunLoop, let schedule = framework.scheduleOnRunLoop {
      schedule(handle, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
    }
    if !MultitouchOptions.skipStart, let start = framework.start {
      let status = start(handle, 0)
      if status != 0 { TouchKitLog.touch.error("device \(device.info.id): start returned \(status)") }
    }
    TouchKitLog.touch.notice("device \(device.info.id) registered (\(device.info.kind.rawValue, privacy: .public))")
    return true
  }

  func unregister(_ device: BackendDevice) {
    guard let entry = lock.withLock({ active.removeValue(forKey: device.info.id) }) else { return }
    if !MultitouchOptions.skipStart { _ = framework.stop?(entry.handle) }
    let callback: UnsafeRawPointer =
      entry.usedRefcon
      ? unsafeBitCast(refconTrampoline, to: UnsafeRawPointer.self)
      : unsafeBitCast(plainTrampoline, to: UnsafeRawPointer.self)
    framework.unregister?(entry.handle, callback)
    if !entry.usedRefcon { PlainCallbackRegistry.shared.set(nil, for: entry.handle) }
    lock.withLock { retired.append(entry.context) }
    TouchKitLog.touch.notice("device \(device.info.id) unregistered")
  }
}
