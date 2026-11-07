import Foundation

// Batch EDGY-DISPLAYS owns this module. The types and the factory below are FROZEN contracts:
// Actions builds against them in parallel. Replace the factory body, never the signatures.

/// One attached display as far as brightness is concerned.
public struct DisplayInfo: Hashable, Sendable {
  public enum Kind: String, Sendable {
    /// A MacBook's own panel.
    case builtIn
    /// An Apple-made external display whose brightness macOS controls itself.
    case appleExternal
    /// Any other monitor; brightness only through DDC/CI over the cable, if the monitor allows it.
    case thirdParty
  }

  /// Stable for the session (CoreGraphics display ID).
  public var id: UInt32
  public var name: String
  public var kind: Kind
  /// Whether brightness can be read and set right now (probed, not assumed).
  public var brightnessControllable: Bool
  /// Shown to the user when `brightnessControllable` is false.
  public var reason: String?

  public init(id: UInt32, name: String, kind: Kind, brightnessControllable: Bool, reason: String? = nil) {
    self.id = id
    self.name = name
    self.kind = kind
    self.brightnessControllable = brightnessControllable
    self.reason = reason
  }
}

public enum DisplayBrightnessError: Error, Equatable, Sendable {
  case noSuchDisplay(UInt32)
  case notControllable(UInt32, reason: String)
  case failed(UInt32, reason: String)
}

/// Brightness for every attached display, 0...1. Implementations must be safe to call from the
/// action thread at slide rate: slow transports (DDC) coalesce writes and never block the caller.
public protocol DisplayBrightnessControlling: AnyObject, Sendable {
  /// Attached displays, re-probed when displays are connected or disconnected.
  func displays() -> [DisplayInfo]
  /// The display under the mouse pointer, falling back to the main display.
  func activeDisplayID() -> UInt32?
  func brightness(of id: UInt32) throws -> Double
  func setBrightness(_ level: Double, of id: UInt32) throws
}

// FROZEN FACTORY SIGNATURE. Building it has no side effects; probing happens on first use.
public func makeLiveDisplayBrightness() -> DisplayBrightnessControlling {
  UnavailableDisplayBrightness()
}

/// Placeholder until the Displays batch lands: reports no controllable displays.
final class UnavailableDisplayBrightness: DisplayBrightnessControlling {
  func displays() -> [DisplayInfo] { [] }
  func activeDisplayID() -> UInt32? { nil }
  func brightness(of id: UInt32) throws -> Double { throw DisplayBrightnessError.noSuchDisplay(id) }
  func setBrightness(_ level: Double, of id: UInt32) throws { throw DisplayBrightnessError.noSuchDisplay(id) }
}
