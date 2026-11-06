import EdgyCore
import Foundation

@testable import EdgyRuntime

// Test doubles for every engine collaborator. None of them touches the real system.

final class Locked<Value>: @unchecked Sendable {
  private let lock = NSLock()
  private var stored: Value
  init(_ value: Value) { stored = value }
  var value: Value {
    get { lock.withLock { stored } }
    set { lock.withLock { stored = newValue } }
  }
}

final class RecordingLogger: EdgyLogging, @unchecked Sendable {
  private let entries = Locked<[(LogLevel, String)]>([])
  func log(_ level: LogLevel, _ message: String) { entries.value.append((level, message)) }
  var errors: [String] { entries.value.filter { $0.0 == .error }.map(\.1) }
}

final class FakeTouchSource: TouchSource, @unchecked Sendable {
  private let state = Locked<(devices: [TouchDeviceInfo], onFrame: (@Sendable (TouchFrame) -> Void)?)>(([], nil))
  private let changed = Locked<(@Sendable ([TouchDeviceInfo]) -> Void)?>(nil)
  let stopCount = Locked(0)
  /// When set, `start` throws it.
  let startError = Locked<Error?>(nil)

  init(devices: [TouchDeviceInfo]) { state.value.devices = devices }

  var devices: [TouchDeviceInfo] { state.value.devices }

  func start(
    onFrame: @escaping @Sendable (TouchFrame) -> Void,
    onDevicesChanged: @escaping @Sendable ([TouchDeviceInfo]) -> Void
  ) throws {
    if let error = startError.value { throw error }
    state.value.onFrame = onFrame
    changed.value = onDevicesChanged
  }

  func stop() { stopCount.value += 1 }

  func emit(_ frame: TouchFrame) { state.value.onFrame?(frame) }

  func changeDevices(_ devices: [TouchDeviceInfo]) {
    state.value.devices = devices
    changed.value?(devices)
  }
}

/// Returns scripted outputs, one per frame (empty output once the script runs out).
final class FakeRecognizer: GestureRecognizing {
  var script: [GestureOutput] = []
  private(set) var contexts: [GestureContext] = []
  private(set) var resetCount = 0

  func process(_ frame: TouchFrame, device: TouchDeviceInfo, context: GestureContext) -> GestureOutput {
    contexts.append(context)
    return script.isEmpty ? GestureOutput() : script.removeFirst()
  }

  func reset() { resetCount += 1 }
}

struct PerformedAction: Equatable {
  var id: ActionID
  var input: ActionInput
  var frontmostBundleID: String?
  var parameters: [String: String]
}

final class FakeActions: ActionPerforming {
  var available: [ActionDescriptor] { [] }
  private(set) var performed: [PerformedAction] = []
  var errorToThrow: Error?
  private(set) var appliedSettings: [AppSettings] = []
  private(set) var feedbacks: [HapticEvent] = []

  func feedback(_ event: HapticEvent, context: ActionContext) { feedbacks.append(event) }

  func apply(settings: AppSettings) { appliedSettings.append(settings) }

  func perform(_ id: ActionID, input: ActionInput, context: ActionContext) throws {
    performed.append(
      PerformedAction(
        id: id, input: input, frontmostBundleID: context.frontmostBundleID, parameters: context.parameters))
    if let errorToThrow { throw errorToThrow }
  }
}

final class FakePointerGuard: PointerGuarding, @unchecked Sendable {
  let calls = Locked<[String]>([])
  func engage() { calls.value.append("engage") }
  func release() { calls.value.append("release") }
}

final class FakeTyping: TypingActivitySource, @unchecked Sendable {
  let seconds = Locked<TimeInterval?>(nil)
  var secondsSinceLastKeyPress: TimeInterval? { seconds.value }
}

final class FakeFrontmost: FrontmostAppProviding, @unchecked Sendable {
  let bundleID = Locked<String?>(nil)
  var frontmostBundleID: String? { bundleID.value }
}

enum Sample {
  static let device = TouchDeviceInfo(
    id: 7, kind: .builtInTrackpad, sensorSizeMM: Size2D(width: 160, height: 100), familyID: 0)

  static func frame(_ n: Int32, deviceID: UInt64 = device.id) -> TouchFrame {
    TouchFrame(deviceID: deviceID, timestamp: Double(n) / 120, frameNumber: n, contacts: [])
  }

  static func event(
    _ zone: Zone, _ kind: GestureKind, phase: GestureEvent.Phase = .ended, delta: Double = 0
  ) -> GestureEvent {
    GestureEvent(
      zone: zone, kind: kind, fingers: 1, phase: phase, delta: delta, position: 0.5, timestamp: 0,
      deviceID: device.id)
  }

  static func tempConfigURL() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("edgy-tests-\(UUID().uuidString)", isDirectory: true)
      .appendingPathComponent("config.json")
  }
}
