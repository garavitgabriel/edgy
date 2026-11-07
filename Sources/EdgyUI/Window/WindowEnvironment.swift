import EdgyRuntime
import SwiftUI

/// The config file failed to decode or validate on reload (BRIEF § Issue states). Edgy keeps
/// running the last working settings and the window turns read-only until the file is fixed.
///
/// A thin wrapper over the runtime's `EdgyRuntime.ConfigProblem` (the one source of the parser's
/// message and line) plus the file's name, which only the app knows. The app feeds it through
/// `\.windowConditions` and `MenuBarState.configProblem`; without one, the popover wraps
/// `editor.configProblem` as "config.json". `init(fileName:line:message:)` stays for EdgyApp.
public struct ConfigProblem: Hashable, Sendable {
  public var problem: EdgyRuntime.ConfigProblem
  public var fileName: String

  public var line: Int? {
    get { problem.line }
    set { problem.line = newValue }
  }

  public var message: String {
    get { problem.message }
    set { problem.message = newValue }
  }

  public init(_ problem: EdgyRuntime.ConfigProblem, fileName: String = "config.json") {
    self.problem = problem
    self.fileName = fileName
  }

  public init(fileName: String = "config.json", line: Int?, message: String) {
    self.init(EdgyRuntime.ConfigProblem(message: message, line: line), fileName: fileName)
  }

  /// "config.json has an error on line 14, column 3: Unexpected character ‘x’. Edgy kept the last
  /// working settings." The parser's own "around line N, column M" is folded into the lead so the
  /// line is named once; straight quotes become typographic ones.
  public var sentence: String {
    var text = message.trimmingCharacters(in: .whitespacesAndNewlines)
    var line = self.line
    var column: Int?
    let pattern = #"\s*,?\s*(?:around|at|on)\s+line\s+(\d+)(?:,\s*column\s+(\d+))?"#
    if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
      let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
      let range = Range(match.range, in: text)
    {
      if line == nil, let r = Range(match.range(at: 1), in: text) { line = Int(text[r]) }
      if let r = Range(match.range(at: 2), in: text) { column = Int(text[r]) }
      text.removeSubrange(range)
    }
    while text.hasSuffix(".") { text.removeLast() }
    text = Self.typographic(text)
    var place = line.map { " on line \($0)" } ?? ""
    if line != nil, let column { place += ", column \(column)" }
    return "\(fileName) has an error\(place): \(text). Edgy kept the last working settings."
  }

  /// 'x' → ‘x’, don't → don’t.
  static func typographic(_ text: String) -> String {
    var result = ""
    var previous: Character?
    for character in text {
      if character == "'" {
        let opens = previous == nil || previous!.isWhitespace || "([{".contains(previous!)
        result.append(opens ? "‘" : "’")
      } else if character == "\"" {
        let opens = previous == nil || previous!.isWhitespace || "([{".contains(previous!)
        result.append(opens ? "“" : "”")
      } else {
        result.append(character)
      }
      previous = character
    }
    return result
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
