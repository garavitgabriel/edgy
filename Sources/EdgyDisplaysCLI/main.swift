import Displays
import Foundation

// edgy-displays: probe and drive display brightness by hand (used by scripts/smoke-displays.sh).
// It changes real brightness; never run it from tests.

let usage = """
  usage: edgy-displays list              every display: id, kind, controllable / reason, brightness
         edgy-displays get <id>          current brightness, 0…1
         edgy-displays set <id> <0…1>    set brightness
         edgy-displays nudge [id]        active (or given) display −10% for a moment, then back
  """

/// DDC writes are queued and land shortly after `setBrightness` returns; give them time before exit.
func waitForWrites(_ seconds: TimeInterval = 1.0) {
  RunLoop.current.run(until: Date().addingTimeInterval(seconds))
}

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data((message + "\n").utf8))
  exit(1)
}

func describe(_ error: any Error) -> String {
  switch error {
  case DisplayBrightnessError.noSuchDisplay(let id): "no display with id \(id)"
  case DisplayBrightnessError.notControllable(let id, let reason): "display \(id) is not controllable: \(reason)"
  case DisplayBrightnessError.failed(let id, let reason): "display \(id): \(reason)"
  default: String(describing: error)
  }
}

func displayID(_ text: String?) -> UInt32 {
  guard let text, let id = UInt32(text) else { fail(usage) }
  return id
}

func percent(_ level: Double) -> String { String(format: "%.0f%%", level * 100) }

let control = makeLiveDisplayBrightness()
let arguments = Array(CommandLine.arguments.dropFirst())

switch arguments.first {
case "list":
  let displays = control.displays()
  if displays.isEmpty { print("no displays") }
  let active = control.activeDisplayID()
  for display in displays {
    var line = "\(display.id)\t\(display.kind.rawValue)\t\(display.name)"
    if display.id == active { line += " (active)" }
    if display.brightnessControllable {
      let level = (try? control.brightness(of: display.id)).map(percent) ?? "unreadable"
      line += "\tcontrollable\t\(level)"
    } else {
      line += "\tnot controllable\t\(display.reason ?? "")"
    }
    print(line)
  }

case "get":
  let id = displayID(arguments.dropFirst().first)
  do { print(String(format: "%.3f", try control.brightness(of: id))) } catch { fail(describe(error)) }

case "set":
  let id = displayID(arguments.dropFirst().first)
  guard arguments.count == 3, let level = Double(arguments[2]), (0...1).contains(level) else { fail(usage) }
  do {
    try control.setBrightness(level, of: id)
    waitForWrites()
    print("display \(id) → \(percent(level))")
  } catch { fail(describe(error)) }

case "nudge":
  let given = arguments.count > 1 ? displayID(arguments[1]) : nil
  guard let id = given ?? control.activeDisplayID() else { fail("no active display") }
  do {
    let original = try control.brightness(of: id)
    let dimmed = original >= 0.1 ? original - 0.1 : min(original + 0.1, 1)
    print("display \(id): \(percent(original)) → \(percent(dimmed))")
    try control.setBrightness(dimmed, of: id)
    waitForWrites(1.5)
    try control.setBrightness(original, of: id)
    waitForWrites()
    print("display \(id): back to \(percent(original))")
  } catch { fail(describe(error)) }

default:
  fail(usage)
}
