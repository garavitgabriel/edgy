import Actions
import EdgyCore
import EdgyRuntime
import Foundation
import Observation

/// What the action picker popover is choosing for.
public struct PickerTarget: Hashable, Sendable {
  public var zone: Zone
  /// `nil` = "Add gesture…" (the picker also chooses the gesture).
  public var gesture: GestureKind?

  public init(zone: Zone, gesture: GestureKind?) {
    self.zone = zone
    self.gesture = gesture
  }
}

/// The one observable model every Edgy surface reads. It adds only UI state (selection, the live
/// feed, engine status) on top of `SettingsEditor`, which stays the single way to change settings:
/// call `editor` methods directly, then the model republishes.
///
/// **Frozen for parallel batches** (chief-owned). Batches add behaviour in `extension
/// SettingsModel` files inside their own folder; new stored state belongs in their own views or
/// a blocker.
@MainActor
@Observable
public final class SettingsModel {
  // MARK: Settings

  public let editor: SettingsEditor
  /// Bumped on every editor change, so views that read `editor` re-render.
  public private(set) var revision = 0

  // MARK: Selection

  /// The open profile tab.
  public var selectedProfile: ProfileRef = .default
  /// The selected zone on the mirror (the inspector shows it).
  public var selectedZone: Zone?
  /// The open picker popover, if any.
  public var picking: PickerTarget?

  // MARK: Engine and live feed

  public private(set) var engineStatus = EngineStatus()
  /// The engine's dry run ("Don't run actions"): gestures are recognized, nothing runs. The
  /// overlay draws the outline "would run" mark while this is on. (Test Mode's overlay itself is
  /// the popover's state; actions run unless this is on.)
  public private(set) var isTestMode = false
  /// Alias of `isTestMode` under the name the design uses.
  public var isDryRun: Bool { isTestMode }
  /// Bundle ID of the frontmost app (set by the app on activation; never Edgy's own). The mini
  /// mirror and the popover chips follow it.
  public var frontmostBundleID: String?
  /// The last trackpad size seen, so the mirror keeps its shape while no trackpad is attached.
  public private(set) var lastKnownPadSizeMM: Size2D?
  /// Used before any trackpad was ever seen (a Magic Trackpad's sensor).
  public static let defaultPadSizeMM = Size2D(width: 160, height: 115)
  /// The pad the mirror shows: the one touched last, else the first attached.
  public private(set) var mirroredDevice: TouchDeviceInfo?
  /// Fingers on `mirroredDevice` right now.
  public private(set) var liveTouches: [LiveTouch] = []
  /// Decisions since the last `takeDecisions()`, newest last (overlay and Test Mode).
  public private(set) var pendingDecisions: [LiveDecision] = []
  /// The last decisions seen (newest last, at most `recentDecisionLimit`), never drained: for
  /// readers that must not compete with the overlay's `takeDecisions()` (onboarding's Try it).
  public private(set) var recentDecisions: [LiveDecision] = []
  public static let recentDecisionLimit = 32

  // MARK: Pickers (data sources for parameter editors)

  public let installedApps: InstalledAppsProviding?
  public let shortcuts: ShortcutsListing?
  public let keyRecorder: KeyComboRecording?

  @ObservationIgnored private let engine: LiveEngine?
  @ObservationIgnored private var feedToken: UUID?
  @ObservationIgnored private var editorToken: UUID?

  public init(
    editor: SettingsEditor, engine: LiveEngine?, installedApps: InstalledAppsProviding? = nil,
    shortcuts: ShortcutsListing? = nil, keyRecorder: KeyComboRecording? = nil,
    devices: [TouchDeviceInfo] = []
  ) {
    self.editor = editor
    self.engine = engine
    self.installedApps = installedApps
    self.shortcuts = shortcuts
    self.keyRecorder = keyRecorder
    mirroredDevice = devices.first
    if let engine {
      engineStatus = engine.status
      isTestMode = engine.isTestMode
      mirroredDevice = engine.status.devices.first { $0.kind != .mouse } ?? mirroredDevice
      engine.onStatusChange { [weak self] status in
        Task { @MainActor in self?.engineStatusChanged(status) }
      }
    }
    editorToken = editor.observe { [weak self] _ in self?.revision += 1 }
  }

  // MARK: Feed

  /// Starts the live feed (mirror touches + decisions). Call while a surface that shows it is visible.
  public func startFeed() {
    guard feedToken == nil, let engine else { return }
    feedToken = engine.observeFeed(on: .main) { [weak self] update in
      MainActor.assumeIsolated { self?.receive(update) }
    }
  }

  public func stopFeed() {
    guard let feedToken, let engine else { return }
    engine.removeFeedObserver(feedToken)
    self.feedToken = nil
    liveTouches = []
  }

  /// Hands the accumulated decisions to the caller (the overlay) and clears them.
  public func takeDecisions() -> [LiveDecision] {
    defer { pendingDecisions = [] }
    return pendingDecisions
  }

  public func setTestMode(_ on: Bool) {
    engine?.setTestMode(on)
    isTestMode = engine?.isTestMode ?? on
  }

  public func pause(until date: Date?) { engine?.pause(until: date) }
  public func resume() { engine?.resume() }

  // MARK: For previews and snapshot tests

  /// Injects a feed update as if the engine sent it.
  public func simulate(_ update: LiveFeedUpdate) { receive(update) }

  /// Injects an engine status as if the engine sent it.
  public func simulate(_ status: EngineStatus) { engineStatusChanged(status) }

  // MARK: Private

  private func receive(_ update: LiveFeedUpdate) {
    if let frame = update.touches {
      // The mirror follows the pad touched last.
      if frame.deviceID != mirroredDevice?.id, !frame.touches.isEmpty,
        let device = engineStatus.devices.first(where: { $0.id == frame.deviceID })
      {
        mirroredDevice = device
      }
      if frame.deviceID == mirroredDevice?.id { liveTouches = frame.touches }
    }
    pendingDecisions += update.decisions
    if !update.decisions.isEmpty {
      recentDecisions = Array((recentDecisions + update.decisions).suffix(Self.recentDecisionLimit))
    }
  }

  private func engineStatusChanged(_ status: EngineStatus) {
    engineStatus = status
    isTestMode = engine?.isTestMode ?? isTestMode
    if mirroredDevice == nil || !status.devices.contains(where: { $0.id == mirroredDevice?.id }) {
      mirroredDevice = status.devices.first { $0.kind != .mouse }
    }
    if let size = mirroredDevice?.sensorSizeMM { lastKnownPadSizeMM = size }
  }
}
