import Foundation
import os

public enum LogLevel: String, Sendable {
  case debug, info, error
}

/// Injectable log sink. Live code uses `SystemLogger`; tests record entries.
public protocol EdgyLogging: Sendable {
  func log(_ level: LogLevel, _ message: String)
}

/// Unified-logging sink under the app's subsystem.
public struct SystemLogger: EdgyLogging {
  public static let subsystem = "com.garavit.edgy"
  private let logger: Logger

  public init(category: String) {
    logger = Logger(subsystem: SystemLogger.subsystem, category: category)
  }

  public func log(_ level: LogLevel, _ message: String) {
    switch level {
    case .debug: logger.debug("\(message, privacy: .public)")
    case .info: logger.info("\(message, privacy: .public)")
    case .error: logger.error("\(message, privacy: .public)")
    }
  }
}
