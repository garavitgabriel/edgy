import EdgyCore
import Foundation
import TouchKit

// edgy-trace — touch diagnostics and trace recording.
//
//   edgy-trace devices
//   edgy-trace live [--seconds <n>]
//   edgy-trace record --label <kebab> --expect "<text>" --seconds <n> --out <path> [--device <id>] [--countdown <n>]

let usage = """
  usage:
    edgy-trace devices
    edgy-trace live [--seconds <n>]
    edgy-trace record --label <kebab> --expect "<text>" --seconds <n> --out <path> [--device <id>] [--countdown <n>]

  env toggles (hardware questions): EDGY_MT_SKIP_START=1, EDGY_MT_RUNLOOP=1, EDGY_MT_SKIP_LAYOUT_CHECK=1
  """

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("edgy-trace: \(message)\n".utf8))
  exit(1)
}

func options(_ args: ArraySlice<String>) -> [String: String] {
  var result: [String: String] = [:]
  var i = args.startIndex
  while i < args.endIndex {
    let key = args[i]
    guard key.hasPrefix("--") else { fail("unexpected argument \(key)\n\(usage)") }
    let next = args.index(after: i)
    guard next < args.endIndex else { fail("missing value for \(key)") }
    result[String(key.dropFirst(2))] = args[next]
    i = args.index(after: next)
  }
  return result
}

func describe(_ d: TouchDeviceInfo) -> String {
  String(
    format: "id=%llu kind=%@ family=%d sensor=%.1f×%.1f mm", d.id, d.kind.rawValue, d.familyID, d.sensorSizeMM.width,
    d.sensorSizeMM.height)
}

func pump(seconds: TimeInterval, until done: () -> Bool = { false }) {
  let end = Date().addingTimeInterval(seconds)
  while Date() < end && !done() { RunLoop.main.run(until: min(end, Date().addingTimeInterval(0.05))) }
}

final class DeviceBox: @unchecked Sendable {
  private let lock = NSLock()
  private var _devices: [TouchDeviceInfo]?
  var devices: [TouchDeviceInfo]? {
    get { lock.withLock { _devices } }
    set { lock.withLock { _devices = newValue } }
  }
}

let args = CommandLine.arguments.dropFirst()
guard let command = args.first else { fail(usage) }
let opts = options(args.dropFirst())
let source = makeLiveTouchSource()
let known = DeviceBox()

switch command {
case "devices":
  do {
    try source.start(onFrame: { _ in }, onDevicesChanged: { known.devices = $0 })
  } catch { fail("\(error)") }
  pump(seconds: 1) { known.devices != nil }
  source.stop()
  let list = known.devices ?? []
  print(list.isEmpty ? "no multitouch devices found" : list.map(describe).joined(separator: "\n"))
  print("accessibility trusted: \(isAccessibilityTrusted())")

case "live":
  let seconds = opts["seconds"].flatMap(Double.init) ?? .infinity
  do {
    try source.start(
      onFrame: { print(FrameFormatter.line($0)) },
      onDevicesChanged: { list in print("devices changed:\n  " + list.map(describe).joined(separator: "\n  ")) })
  } catch { fail("\(error)") }
  print("streaming frames — touch the trackpad; ctrl-c to quit")
  pump(seconds: seconds)
  source.stop()

case "record":
  guard let label = opts["label"], let expectation = opts["expect"], let out = opts["out"],
    let seconds = opts["seconds"].flatMap(Double.init), seconds > 0
  else { fail("record needs --label, --expect, --seconds, --out\n\(usage)") }
  let wanted = opts["device"].flatMap(UInt64.init)
  let countdown = opts["countdown"].flatMap(Int.init) ?? 3
  let recorder: TraceRecorder
  do {
    recorder = try TraceRecorder(label: label, expectation: expectation, deviceID: nil)
  } catch { fail("label must be kebab-case (a-z, 0-9, single hyphens): \(label)") }
  let armed = DeviceBox()  // non-nil once recording is live; holds the chosen device
  do {
    try source.start(
      onFrame: { frame in
        guard let device = armed.devices?.first, frame.deviceID == device.id else { return }
        recorder.append(frame)
      }, onDevicesChanged: { known.devices = $0 })
  } catch { fail("\(error)") }
  pump(seconds: 1.5) { known.devices != nil }
  let list = known.devices ?? []
  let chosen =
    wanted.flatMap { id in list.first { $0.id == id } } ?? list.first { $0.kind == .builtInTrackpad } ?? list.first
  guard let device = chosen else { fail("no multitouch device found") }
  print("device: \(describe(device))")
  print("label: \(label)\nexpect: \(expectation)")
  for n in stride(from: countdown, to: 0, by: -1) {
    print("recording in \(n)…")
    pump(seconds: 1)
  }
  print("● recording \(seconds)s — go")
  armed.devices = [device]
  pump(seconds: seconds)
  armed.devices = nil
  source.stop()
  let trace = recorder.makeTrace(device: device)
  let url = URL(fileURLWithPath: out)
  do {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try trace.write(to: url)
  } catch { fail("writing \(out): \(error)") }
  print("wrote \(trace.frames.count) frames → \(out)")
  if trace.frames.isEmpty { print("warning: no frames captured — see scripts/smoke-touch.sh") }

default:
  fail(usage)
}
