import Actions
import AppKit
import EdgyCore
import EdgyRuntime
import Foundation
import OSLog

/// One screen as the overlay sees it (AppKit global coordinates).
struct OverlayScreen: Equatable {
  /// Stable for the session (the display ID).
  var id: String
  /// The display's name ("Desk 34"), matched against a level plate's `detail`.
  var name: String
  var frame: CGRect
  /// The frame minus the menu bar and the Dock.
  var visibleFrame: CGRect
}

/// Where the overlay gets its screens. Live: `NSScreen`.
@MainActor
protocol OverlayScreenProviding: AnyObject {
  var screens: [OverlayScreen] { get }
  /// The screen with the key window (where the user is working), else the first.
  var mainScreenID: String? { get }
}

/// One plate placed on a screen, ready to draw.
struct PlatePlacement: Equatable {
  var id: Int
  var content: PlateContent
  var screenID: String
  /// AppKit global coordinates.
  var frame: CGRect
  var opacity: Double
}

/// Draws placements. Live: click-through panels per screen plus one clickable panel for the
/// display check. Tests use a recording fake; nothing reaches a real screen.
@MainActor
protocol OverlayPresenting: AnyObject {
  /// The size `content` draws at.
  func size(of content: PlateContent) -> CGSize
  /// Shows exactly these placements (anything else is taken down).
  func present(_ placements: [PlatePlacement], screens: [OverlayScreen], answer: @escaping @MainActor (Bool) -> Void)
  func tearDown()
}

/// The overlay clock: the current time and a repeating tick on the main run loop.
@MainActor
protocol OverlayClock: AnyObject {
  var now: TimeInterval { get }
  func startTicking(_ tick: @escaping @MainActor () -> Void)
  func stopTicking()
}

/// Test Mode's overlay, Edgy's level plate and the display check (bone 9, BRIEF § Level plate
/// and display check). Takes the model's decisions on the main run loop, turns them into plates
/// (`PlateContent.from`), docks each at the touched zone's edge or corner of the right screen and
/// fades them on time. Never takes focus; only the display check accepts clicks.
///
/// The app wires `showsTestModePlates` to the popover's Test Mode switch
/// (`MenuBarController.onOverlayVisibleChange`). Level plates and the display check show either way.
@MainActor
public final class OverlayController {
  /// Test Mode is on: run, would-run, rejection and hold plates show. Off: only the level plate
  /// and the display check.
  public var showsTestModePlates = false {
    didSet {
      guard oldValue != showsTestModePlates else { return }
      if !showsTestModePlates { timeline.dropTestModePlates() }
      render()
    }
  }

  private let model: SettingsModel
  private let screens: OverlayScreenProviding
  private let presenter: OverlayPresenting
  private let clock: OverlayClock
  private let log = Logger(subsystem: "com.garavit.edgy", category: "overlay")
  private(set) var timeline = OverlayTimeline()
  private var isRunning = false
  /// The display check on screen: its display key and name.
  private(set) var askingDisplay: (key: String, name: String)? {
    didSet { if askingDisplay == nil { checkFrame = nil } }
  }
  /// Where the display check was first placed.
  private var checkFrame: CGRect?

  public convenience init(model: SettingsModel) {
    self.init(model: model, screens: LiveScreens(), presenter: PanelPresenter(), clock: RunLoopClock())
  }

  init(model: SettingsModel, screens: OverlayScreenProviding, presenter: OverlayPresenting, clock: OverlayClock) {
    self.model = model
    self.screens = screens
    self.presenter = presenter
    self.clock = clock
  }

  public func start() {
    guard !isRunning else { return }
    isRunning = true
    _ = model.takeDecisions()
    model.startFeed()
    clock.startTicking { [weak self] in self?.pump() }
  }

  public func stop() {
    guard isRunning else { return }
    isRunning = false
    clock.stopTicking()
    timeline.removeAll()
    askingDisplay = nil
    presenter.tearDown()
  }

  // MARK: The loop

  /// One turn: take the model's decisions, update the plates, drop finished fades, draw.
  func pump() {
    // The feed is one shared switch: another surface closing (the settings window calls
    // `stopFeed()`) must not silence the overlay. `startFeed()` does nothing while it is on.
    model.startFeed()
    let decisions = model.takeDecisions()
    if !decisions.isEmpty { receive(decisions) }
    timeline.tick(now: clock.now)
    if askingDisplay != nil, !timeline.entries.contains(where: \.content.isDisplayCheck) { askingDisplay = nil }
    render()
  }

  func receive(_ decisions: [LiveDecision]) {
    let now = clock.now
    let dryRun = model.isDryRun
    let context = PlateContext.current(model: model)
    let catalog = model.mirrorCatalog
    for decision in decisions {
      if case .recognized(let zone, let kind, let phase, _) = decision {
        timeline.gesture(zone: zone, kind: kind, phase: phase, now: now)
        continue
      }
      guard let content = PlateContent.from(decision, catalog: catalog, context: context, dryRun: dryRun) else {
        continue
      }
      if content.isTestModeOnly && !showsTestModePlates { continue }
      if case .displayCheck(let key) = content.kind {
        guard askDisplayCheck(key: key, name: content.displayName ?? "") else { continue }
      }
      timeline.show(content, gesture: decision.plateGesture, now: now)
    }
  }

  // MARK: Display check

  /// Whether to show the question now; counts the ask (at most 3 per display, the editor's rule).
  private func askDisplayCheck(key: String, name: String) -> Bool {
    guard model.editor.displayCheckDue(key: key) else { return false }
    do {
      try model.editor.countDisplayCheckAsk(key: key)
    } catch {
      log.error("display check: couldn't count the ask: \(String(describing: error), privacy: .public)")
      return false
    }
    askingDisplay = (key, name)
    return true
  }

  /// Yes (`responds`) or "No, turn off for this display".
  func answerDisplayCheck(_ responds: Bool) {
    guard let asking = askingDisplay else { return }
    do {
      try model.editor.answerDisplayCheck(key: asking.key, responds: responds)
    } catch {
      log.error("display check: couldn't save the answer: \(String(describing: error), privacy: .public)")
    }
    askingDisplay = nil
    timeline.dismissDisplayCheck()
    render()
  }

  // MARK: Layout

  /// Every plate on its screen, docked and stacked.
  func placements() -> [PlatePlacement] {
    let all = screens.screens
    guard let fallback = all.first(where: { $0.id == screens.mainScreenID }) ?? all.first else { return [] }
    let now = clock.now
    var used: [String: Int] = [:]
    var levelFrames: [String: (CGRect, Zone?)] = [:]
    var result: [PlatePlacement] = []
    // The check docks beside its display's level plate, so place it last.
    let ordered =
      timeline.entries.filter { !$0.content.isDisplayCheck } + timeline.entries.filter(\.content.isDisplayCheck)
    for entry in ordered {
      let content = entry.content
      let screen = screen(for: content, in: all) ?? fallback
      let size = presenter.size(of: content)
      let frame: CGRect
      if content.isDisplayCheck {
        // Once placed, the question stays put while the level plate beside it fades.
        if let pinned = checkFrame {
          frame = pinned
        } else if let (level, zone) = levelFrames[screen.id] {
          frame = PlateDocking.beside(level, size: size, zone: zone, in: screen.visibleFrame)
        } else {
          frame = PlateDocking.frame(zone: nil, size: size, in: screen.visibleFrame)
        }
        checkFrame = frame
      } else {
        let key = "\(screen.id)|\(PlateDocking.dockKey(content.zone))"
        frame = PlateDocking.frame(
          zone: content.zone, size: size, in: screen.visibleFrame, stack: used[key, default: 0])
        used[key, default: 0] += 1
        if content.kind == .level { levelFrames[screen.id] = (frame, content.zone) }
      }
      result.append(
        PlatePlacement(
          id: entry.id, content: content, screenID: screen.id, frame: frame,
          opacity: OverlayTimeline.opacity(entry, now: now)))
    }
    return result
  }

  /// A level plate (and the display check) goes on the display it changed; everything else on the
  /// screen being worked on.
  private func screen(for content: PlateContent, in all: [OverlayScreen]) -> OverlayScreen? {
    guard let name = content.displayName else { return nil }
    return all.first { $0.name == name }
  }

  private func render() {
    guard isRunning else { return }
    presenter.present(placements(), screens: screens.screens) { [weak self] responds in
      self?.answerDisplayCheck(responds)
    }
  }
}

// MARK: Live screens and clock

@MainActor
final class LiveScreens: OverlayScreenProviding {
  var screens: [OverlayScreen] {
    NSScreen.screens.map { screen in
      OverlayScreen(
        id: Self.id(of: screen), name: screen.localizedName, frame: screen.frame, visibleFrame: screen.visibleFrame)
    }
  }

  var mainScreenID: String? { NSScreen.main.map(Self.id) }

  static func id(of screen: NSScreen) -> String {
    let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
    return number.map { "\($0.uint32Value)" } ?? screen.localizedName
  }
}

@MainActor
final class RunLoopClock: OverlayClock {
  /// About 30 ticks a second: smooth 200 ms fades, cheap when nothing is up.
  static let interval: TimeInterval = 1.0 / 30
  private var timer: Timer?

  var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

  func startTicking(_ tick: @escaping @MainActor () -> Void) {
    stopTicking()
    let timer = Timer(timeInterval: Self.interval, repeats: true) { _ in
      MainActor.assumeIsolated { tick() }
    }
    RunLoop.main.add(timer, forMode: .common)
    self.timer = timer
  }

  func stopTicking() {
    timer?.invalidate()
    timer = nil
  }
}
