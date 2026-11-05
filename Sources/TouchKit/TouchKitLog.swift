import os

enum TouchKitLog {
  static let touch = Logger(subsystem: "com.garavit.edgy", category: "touch")
  static let pointer = Logger(subsystem: "com.garavit.edgy", category: "pointer")
  static let typing = Logger(subsystem: "com.garavit.edgy", category: "typing")
}

/// Errors surfaced by the live touch source.
public enum TouchKitError: Error, Equatable, CustomStringConvertible {
  case multitouchUnavailable(reason: String)

  public var description: String {
    switch self {
    case .multitouchUnavailable(let reason): return "multitouch unavailable: \(reason)"
    }
  }
}
