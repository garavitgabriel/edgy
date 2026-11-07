import CoreGraphics
import Foundation

// Internal seams between the brightness logic and the system. Live implementations are in
// `Live*.swift`; tests inject fakes. Nothing here touches the system by itself.

/// One online display as CoreGraphics reports it.
struct DisplayDescriptor: Equatable, Sendable {
  var id: UInt32
  var isBuiltIn: Bool
  var vendorID: UInt32
  var productID: UInt32
  var serial: UInt32
  /// Global coordinates, top-left origin (the space `CGDisplayBounds` and `CGEvent` locations share).
  var bounds: CGRect
}

/// CoreGraphics: display list, pointer, names, reconfiguration events.
protocol DisplaySystem: Sendable {
  func onlineDisplays() -> [DisplayDescriptor]
  func mainDisplayID() -> UInt32?
  /// Pointer position in the same space as `DisplayDescriptor.bounds`.
  func pointerLocation() -> CGPoint?
  /// The name macOS shows for the display, when it can be had cheaply on this thread.
  func localizedName(of id: UInt32) -> String?
  /// Calls `handler` (possibly many times per change, on any thread) whenever displays are
  /// added, removed or rearranged. Called at most once per controller.
  func observeReconfiguration(_ handler: @escaping @Sendable () -> Void)
}

/// Software brightness for built-in panels and Apple external displays.
protocol BacklightService: Sendable {
  /// 0...1, or nil when it can't be read (no such control, or the framework is missing).
  func brightness(of id: UInt32) -> Double?
  /// False when the write was refused.
  func setBrightness(_ level: Double, of id: UInt32) -> Bool
}

/// One I²C channel to a monitor's DDC/CI address. Implementations serialize their own transfers.
protocol DDCTransport: Sendable {
  /// Sends one host → monitor message as built by `DDC` (starting with the `0x51` source byte).
  func write(_ message: [UInt8]) throws
  /// Reads up to `count` reply bytes.
  func read(count: Int) throws -> [UInt8]
}

/// What the display registry says about a monitor (from its EDID).
struct ProductAttributes: Equatable, Sendable {
  var vendorID: UInt32?
  var productID: UInt32?
  var serial: UInt32?
  var name: String?
}

/// The parts of the IORegistry walk the pairing step cares about, in registry order.
enum RegistryNode: Sendable {
  /// An entry carrying a connected display's attributes (a framebuffer).
  case display(ProductAttributes)
  /// An audio/video service. `transport` is nil when it could not be opened.
  case avService(external: Bool, transport: (any DDCTransport)?)
}

protocol AVServiceRegistry: Sendable {
  /// Registry nodes in plane order. Empty when the registry or the I²C functions are unavailable.
  func nodes() -> [RegistryNode]
}

/// Everything the controller needs from the outside world.
struct DisplayEnvironment: Sendable {
  var system: any DisplaySystem
  var backlight: any BacklightService
  var registry: any AVServiceRegistry
  /// DDC over IOAVService exists only on Apple silicon. Evaluated lazily, at probe time.
  var isAppleSilicon: @Sendable () -> Bool
  /// Blocks the calling thread (live: sleeps). Used only between a DDC request and its reply.
  var pause: @Sendable (TimeInterval) -> Void
  var makeScheduler: @Sendable (_ label: String) -> any Scheduler
  var writePolicy = DDCWriteQueue.Policy()
  /// Reconfiguration callbacks arrive in bursts; re-probe once they have been quiet this long.
  var reprobeDebounce: TimeInterval = 0.5
  /// Delay between a DDC request and reading its reply.
  var replyDelay: TimeInterval = 0.05
  var readAttempts = 3
}
