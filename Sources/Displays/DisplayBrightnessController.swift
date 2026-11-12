import CoreGraphics
import Foundation
import os

let displaysLog = Logger(subsystem: "com.garavit.edgy", category: "displays")

/// Plain-language reasons shown in settings when a display's brightness can't be controlled.
enum DisplayReason {
  static let noResponse =
    "This monitor doesn't respond to brightness control over its cable. Some monitors need DDC/CI turned on in their own menu."
  static let unsupported = "This monitor doesn't support brightness control over its cable."
  static let noRange = "This monitor didn't report a brightness range over its cable."
  static let noPath =
    "Edgy can't reach this monitor's controls. It may be connected through an adapter or dock that blocks brightness control."
  static let needsAppleSilicon = "External brightness needs an Apple silicon Mac."
  static let backlightUnreadable = "macOS didn't let Edgy read this display's brightness."
  static let writeFailed = "The monitor stopped accepting brightness changes."
  static let checking = "Edgy is still checking this monitor's brightness control."
}

/// The USB/EDID vendor number CoreGraphics reports for Apple-made displays.
let appleDisplayVendorID: UInt32 = 0x610

/// A DDC/CI request/response channel to one monitor, with bounded read retries.
struct DDCDevice: Sendable {
  var transport: any DDCTransport
  var pause: @Sendable (TimeInterval) -> Void
  var replyDelay: TimeInterval
  var readAttempts: Int

  func read(_ code: UInt8) throws -> DDC.VCPValue {
    var lastError: any Error = DDC.ReplyError.tooShort(0)
    for _ in 0..<max(1, readAttempts) {
      do {
        try transport.write(DDC.getVCPRequest(code))
        pause(replyDelay)
        return try DDC.parseGetVCPReply(try transport.read(count: DDC.getVCPReplyLength), code: code)
      } catch DDC.ReplyError.unsupported(let code) {
        throw DDC.ReplyError.unsupported(code)
      } catch {
        lastError = error
        pause(replyDelay)
      }
    }
    throw lastError
  }

  func write(_ code: UInt8, value: UInt16) throws {
    try transport.write(DDC.setVCP(code, value: value))
  }
}

/// Brightness state of one DDC monitor: cached value plus its write queue.
final class DDCDisplayChannel: @unchecked Sendable {
  let maximum: UInt16
  let queue: DDCWriteQueue
  private let lock = NSLock()
  private var current: UInt16
  private var failure: String?

  init(device: DDCDevice, initial: DDC.VCPValue, scheduler: any Scheduler, policy: DDCWriteQueue.Policy, id: UInt32) {
    maximum = initial.maximum
    current = min(initial.current, initial.maximum)
    let failureBox = FailureSink()
    queue = DDCWriteQueue(
      scheduler: scheduler, policy: policy,
      write: { value in try device.write(DDC.luminance, value: value) },
      onFailure: { value, error in
        displaysLog.error(
          "display \(id): brightness write \(value) failed after retries: \(String(describing: error), privacy: .public)"
        )
        failureBox.channel?.recordFailure()
      })
    failureBox.channel = self
  }

  var level: Double { lock.withLock { Double(current) / Double(maximum) } }

  func set(_ level: Double) {
    let raw = UInt16((level * Double(maximum)).rounded())
    lock.withLock { current = raw }
    queue.submit(raw)
  }

  /// The last write failure, reported once.
  func takeFailure() -> String? {
    lock.withLock {
      defer { failure = nil }
      return failure
    }
  }

  private func recordFailure() { lock.withLock { failure = DisplayReason.writeFailed } }

  private final class FailureSink: @unchecked Sendable {
    weak var channel: DDCDisplayChannel?
  }
}

/// The live `DisplayBrightnessControlling`: probes lazily on first use, re-probes (debounced)
/// when displays change, routes each display to DisplayServices or DDC/CI.
final class LiveDisplayBrightness: DisplayBrightnessControlling, @unchecked Sendable {
  enum Backend {
    case backlight
    case ddc(DDCDisplayChannel)
    case none
  }

  struct Entry {
    var info: DisplayInfo
    var backend: Backend
  }

  private let environment: DisplayEnvironment

  private let stateLock = NSLock()
  private var entries: [Entry]?
  private var observing = false
  private var changeGeneration = 0
  private var controlScheduler: (any Scheduler)?
  private var probes = 0

  /// Serializes probes so concurrent first calls probe once.
  private let probeLock = NSLock()
  /// The first main-thread call started the full probe on a background queue.
  private var backgroundProbeStarted = false

  init(environment: DisplayEnvironment) {
    self.environment = environment
  }

  /// How many full probes have run (tests).
  var probeCount: Int { stateLock.withLock { probes } }

  // MARK: DisplayBrightnessControlling

  /// Never probes monitors on the main thread. A DDC read on a monitor that doesn't answer waits
  /// for its I2C timeout (about 9 s per monitor, measured 2026-11-12 with two externals), and the
  /// first call comes from `applicationDidFinishLaunching` via `ActionRegistry.availability(of:)`,
  /// so launch stalled ~20 s: no menu, no permission check. On the main thread before the first
  /// probe has finished, this starts it in the background and answers without DDC (built-in and
  /// Apple displays as usual, third-party ones "still checking"). Callers off the main thread (the
  /// brightness actions) still wait for the real answer.
  func displays() -> [DisplayInfo] {
    if let entries = stateLock.withLock({ entries }) { return entries.map(\.info) }
    guard Thread.isMainThread else { return snapshot().map(\.info) }
    let start = stateLock.withLock {
      defer { backgroundProbeStarted = true }
      return !backgroundProbeStarted
    }
    if start {
      DispatchQueue.global(qos: .userInitiated).async { [weak self] in _ = self?.snapshot() }
    }
    return probe(readingDDC: false).map(\.info)
  }

  func activeDisplayID() -> UInt32? {
    let system = environment.system
    let online = system.onlineDisplays()
    if let pointer = system.pointerLocation(), let hit = online.first(where: { $0.bounds.contains(pointer) }) {
      return hit.id
    }
    if let main = system.mainDisplayID(), online.isEmpty || online.contains(where: { $0.id == main }) {
      return main
    }
    return online.first?.id
  }

  func brightness(of id: UInt32) throws -> Double {
    switch try controllableBackend(of: id) {
    case .backlight:
      guard let level = environment.backlight.brightness(of: id) else {
        throw DisplayBrightnessError.failed(id, reason: DisplayReason.backlightUnreadable)
      }
      return min(max(level, 0), 1)
    case .ddc(let channel):
      if let failure = channel.takeFailure() { throw DisplayBrightnessError.failed(id, reason: failure) }
      return channel.level
    case .none:
      throw DisplayBrightnessError.noSuchDisplay(id)
    }
  }

  func setBrightness(_ level: Double, of id: UInt32) throws {
    guard level.isFinite else { throw DisplayBrightnessError.failed(id, reason: "Brightness must be a number.") }
    let level = min(max(level, 0), 1)
    switch try controllableBackend(of: id) {
    case .backlight:
      guard environment.backlight.setBrightness(level, of: id) else {
        throw DisplayBrightnessError.failed(id, reason: "macOS refused the brightness change.")
      }
    case .ddc(let channel):
      if let failure = channel.takeFailure() { throw DisplayBrightnessError.failed(id, reason: failure) }
      channel.set(level)
    case .none:
      throw DisplayBrightnessError.noSuchDisplay(id)
    }
  }

  // MARK: Probing

  private func controllableBackend(of id: UInt32) throws -> Backend {
    guard let entry = snapshot().first(where: { $0.info.id == id }) else {
      throw DisplayBrightnessError.noSuchDisplay(id)
    }
    guard entry.info.brightnessControllable else {
      throw DisplayBrightnessError.notControllable(id, reason: entry.info.reason ?? DisplayReason.noResponse)
    }
    return entry.backend
  }

  private func snapshot() -> [Entry] {
    if let entries = stateLock.withLock({ entries }) { return entries }
    return probeLock.withLock {
      if let entries = stateLock.withLock({ entries }) { return entries }
      return reprobeLocked()
    }
  }

  /// Runs a full probe and publishes it. Call with `probeLock` held.
  @discardableResult
  private func reprobeLocked() -> [Entry] {
    startObservingIfNeeded()
    let fresh = probe()
    stateLock.withLock {
      entries = fresh
      probes += 1
    }
    for entry in fresh {
      displaysLog.info(
        "display \(entry.info.id) \(entry.info.kind.rawValue, privacy: .public) controllable=\(entry.info.brightnessControllable) \(entry.info.reason ?? "", privacy: .public)"
      )
    }
    return fresh
  }

  private func startObservingIfNeeded() {
    let start = stateLock.withLock {
      defer { observing = true }
      return !observing
    }
    guard start else { return }
    environment.system.observeReconfiguration { [weak self] in self?.displaysChanged() }
  }

  /// Debounced: every callback restarts the quiet period; only the last one re-probes.
  private func displaysChanged() {
    let (generation, scheduler) = stateLock.withLock {
      changeGeneration += 1
      if controlScheduler == nil { controlScheduler = environment.makeScheduler("com.garavit.edgy.displays.control") }
      return (changeGeneration, controlScheduler!)
    }
    scheduler.schedule(after: environment.reprobeDebounce) { [weak self] in
      guard let self, stateLock.withLock({ self.changeGeneration == generation }) else { return }
      probeLock.withLock { _ = reprobeLocked() }
    }
  }

  private func probe(readingDDC: Bool = true) -> [Entry] {
    let online = environment.system.onlineDisplays()
    let externals = online.filter { !$0.isBuiltIn }
    let appleSilicon = externals.isEmpty ? true : environment.isAppleSilicon()

    var candidates: [AVServiceCandidate] = []
    var assignment: [UInt32: Int] = [:]
    if appleSilicon && !externals.isEmpty {
      candidates = AVServiceMatching.candidates(from: environment.registry.nodes())
      assignment = AVServiceMatching.assign(displays: externals, candidates: candidates)
    }

    return online.enumerated().map { index, display in
      let kind: DisplayInfo.Kind =
        display.isBuiltIn ? .builtIn : display.vendorID == appleDisplayVendorID ? .appleExternal : .thirdParty
      let candidate = assignment[display.id].map { candidates[$0] }
      let name =
        environment.system.localizedName(of: display.id) ?? candidate?.attributes?.name
        ?? (display.isBuiltIn ? "Built-in Display" : "Display \(index + 1)")

      let key = DisplayKey.make(display: display, attributes: candidate?.attributes, name: name)

      func entry(_ backend: Backend, reason: String? = nil) -> Entry {
        let controllable = if case .none = backend { false } else { true }
        return Entry(
          info: DisplayInfo(
            id: display.id, name: name, kind: kind, brightnessControllable: controllable,
            reason: controllable ? nil : reason, key: key),
          backend: backend)
      }

      switch kind {
      case .builtIn, .appleExternal:
        return environment.backlight.brightness(of: display.id) == nil
          ? entry(.none, reason: DisplayReason.backlightUnreadable) : entry(.backlight)
      case .thirdParty:
        guard appleSilicon else { return entry(.none, reason: DisplayReason.needsAppleSilicon) }
        guard let candidate else { return entry(.none, reason: DisplayReason.noPath) }
        guard let transport = candidate.transport else { return entry(.none, reason: DisplayReason.noResponse) }
        guard readingDDC else { return entry(.none, reason: DisplayReason.checking) }
        let device = DDCDevice(
          transport: transport, pause: environment.pause, replyDelay: environment.replyDelay,
          readAttempts: environment.readAttempts)
        do {
          let value = try device.read(DDC.luminance)
          guard value.maximum > 0 else { return entry(.none, reason: DisplayReason.noRange) }
          let channel = DDCDisplayChannel(
            device: device, initial: value,
            scheduler: environment.makeScheduler("com.garavit.edgy.displays.ddc.\(display.id)"),
            policy: environment.writePolicy, id: display.id)
          return entry(.ddc(channel))
        } catch DDC.ReplyError.unsupported {
          return entry(.none, reason: DisplayReason.unsupported)
        } catch {
          displaysLog.info(
            "display \(display.id): DDC probe failed: \(String(describing: error), privacy: .public)")
          return entry(.none, reason: DisplayReason.noResponse)
        }
      }
    }
  }
}
