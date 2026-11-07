import EdgyRuntime
import SwiftUI

/// The config file failed to decode or validate on reload (BRIEF § Issue states). Edgy keeps
/// running the last working settings and the window turns read-only until the file is fixed.
///
/// Until batch 13's `SettingsEditor.configProblem` lands, the app feeds this through
/// `\.windowConditions`; afterwards the chief maps the editor's value onto it (see
/// `blockers-batch-16.md`).
public struct ConfigProblem: Hashable, Sendable {
  public var fileName: String
  public var line: Int?
  public var message: String

  public init(fileName: String = "config.json", line: Int?, message: String) {
    self.fileName = fileName
    self.line = line
    self.message = message
  }

  /// "config.json has an error on line 14: <parser message>. Edgy kept the last working settings."
  public var sentence: String {
    let place = line.map { " on line \($0)" } ?? ""
    return "\(fileName) has an error\(place): \(message). Edgy kept the last working settings."
  }
}

/// Facts the window shows that `SettingsModel` doesn't carry: the Accessibility permission (from
/// `PermissionMonitor` in the app) and a broken config file.
public struct WindowConditions: Hashable, Sendable {
  public var accessibility: PermissionState
  public var configProblem: ConfigProblem?

  public init(accessibility: PermissionState = .granted, configProblem: ConfigProblem? = nil) {
    self.accessibility = accessibility
    self.configProblem = configProblem
  }

  public static let normal = WindowConditions()
}

/// What the window's strip buttons do. The app supplies the live versions; the default does
/// nothing, so previews and tests never touch the system.
public struct WindowCommands: Sendable {
  public typealias Command = @MainActor @Sendable () -> Void

  public var openAccessibilitySettings: Command
  public var openConfigFile: Command
  public var reloadConfig: Command
  /// Writes the running settings over the broken file. The window confirms first.
  public var replaceWithCurrentSettings: Command

  public init(
    openAccessibilitySettings: @escaping Command = {}, openConfigFile: @escaping Command = {},
    reloadConfig: @escaping Command = {}, replaceWithCurrentSettings: @escaping Command = {}
  ) {
    self.openAccessibilitySettings = openAccessibilitySettings
    self.openConfigFile = openConfigFile
    self.reloadConfig = reloadConfig
    self.replaceWithCurrentSettings = replaceWithCurrentSettings
  }

  public static let none = WindowCommands()
}

private struct WindowConditionsKey: EnvironmentKey {
  static let defaultValue = WindowConditions.normal
}

private struct WindowCommandsKey: EnvironmentKey {
  static let defaultValue = WindowCommands.none
}

extension EnvironmentValues {
  /// Accessibility and broken-config facts for `SettingsWindowView`.
  public var windowConditions: WindowConditions {
    get { self[WindowConditionsKey.self] }
    set { self[WindowConditionsKey.self] = newValue }
  }

  /// The strip buttons' commands for `SettingsWindowView`.
  public var windowCommands: WindowCommands {
    get { self[WindowCommandsKey.self] }
    set { self[WindowCommandsKey.self] = newValue }
  }
}
