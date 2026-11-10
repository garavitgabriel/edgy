import Actions
import AppKit
import EdgyCore
import EdgyRuntime
import Foundation
import OSLog
import Observation

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

/// What the user is working on, which plates keep clear of (AppKit global coordinates).
struct OverlayWorkArea: Equatable {
  /// The focused text element's frame: a plate never covers it (bone 9).
  var text: CGRect?
  /// The focused window's frame: a plate keeps `PlateDocking.workGap` from it when it can.
  var window: CGRect?
}

/// Where the overlay gets its screens. Live: `NSScreen` plus the focused element through
/// Accessibility; tests use a fake.
@MainActor
protocol OverlayScreenProviding: AnyObject {
  var screens: [OverlayScreen] { get }
  /// The screen with the key window (where the user is working), else the first.
  var mainScreenID: String? { get }
  /// The focused text element and its window, read when a plate is about to show (never per tick).
  func workArea() -> OverlayWorkArea
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

/// The overlay clock: the current time and a repeating tick on the main run loop. The controller
/// asks for ticks only while a plate is up or fading (batch 28: no repeating timer while idle).
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
  /// Keeps a re-trigger quiet while a key sequence is still sending (batch 33 fix 4).
  private(set) var sequenceQuiet = SequenceQuiet()
  private var isRunning = false
  /// The clock is ticking (a plate is up, fading, or the display check is asked).
  private(set) var isTicking = false
  /// The screens as last read: when a plate appears or the screens change, never per tick.
  private var screenList: [OverlayScreen] = []
  private var mainScreenID: String?
  private var screenObserver: NSObjectProtocol?
  /// The display check on screen: its display key and name.
  private(set) var askingDisplay: (key: String, name: String)? {
    didSet { if askingDisplay == nil { checkFrame = nil } }
  }
  /// Where the display check was first placed.
  private var checkFrame: CGRect?
  /// What the plates keep clear of, read once per batch of new plates.
  private(set) var workArea = OverlayWorkArea()

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
    refreshScreens()
    observeDecisions()
    screenObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.screensChanged() }
    }
  }

  public func stop() {
    guard isRunning else { return }
    isRunning = false
    if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    screenObserver = nil
    setTicking(false)
    timeline.removeAll()
    askingDisplay = nil
    presenter.tearDown()
  }

  // MARK: The loop

  /// Wakes on every new decision (`decisionSerial` changes) without a clock. Observation calls
  /// back once per registration (before the write lands), so the pump runs on the next main turn
  /// and registers again.
  private func observeDecisions() {
    guard isRunning else { return }
    withObservationTracking {
      _ = model.decisionSerial
    } onChange: { [weak self] in
      Task { @MainActor in self?.wake() }
    }
  }

  /// A decision arrived: register for the next one and run a turn (which starts the clock if a
  /// plate went up).
  func wake() {
    guard isRunning else { return }
    observeDecisions()
    pump()
  }

  /// Ticks only while something is on screen or fading; idle costs nothing.
  private func setTicking(_ on: Bool) {
    guard on != isTicking else { return }
    isTicking = on
    if on {
      clock.startTicking { [weak self] in self?.pump() }
    } else {
      clock.stopTicking()
    }
  }

  private func refreshScreens() {
    screenList = screens.screens
    mainScreenID = screens.mainScreenID
  }

  /// The displays were rearranged, added or removed: read them again and redraw what is up.
  func screensChanged() {
    guard isRunning else { return }
    refreshScreens()
    checkFrame = nil
    render()
  }

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
    setTicking(isRunning && (!timeline.entries.isEmpty || askingDisplay != nil))
  }

  func receive(_ decisions: [LiveDecision]) {
    let now = clock.now
    let dryRun = model.isDryRun
    let context = PlateContext.current(model: model)
    let catalog = model.mirrorCatalog
    let newestBefore = timeline.entries.map(\.id).max() ?? 0
    defer {
      // Read the work area only when a plate that wasn't up appears (ids only grow on append):
      // never for a slide's updates, which arrive every tick, nor for decisions with no plate.
      if (timeline.entries.map(\.id).max() ?? 0) > newestBefore {
        workArea = screens.workArea()
        refreshScreens()
      }
    }
    for decision in decisions {
      if case .recognized(let zone, let kind, let phase, _) = decision {
        timeline.gesture(zone: zone, kind: kind, phase: phase, now: now)
        continue
      }
      guard let content = PlateContent.from(decision, catalog: catalog, context: context, dryRun: dryRun) else {
        continue
      }
      if content.isTestModeOnly && !showsTestModePlates { continue }
      if !dryRun, !sequenceQuiet.admits(decision, context: context, now: now) { continue }
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
    pump()
  }

  // MARK: Layout

  /// Every plate on its screen, docked and stacked.
  func placements() -> [PlatePlacement] {
    let all = screenList
    guard let fallback = all.first(where: { $0.id == mainScreenID }) ?? all.first else { return [] }
    let now = clock.now
    var used: [String: Int] = [:]
    var levelFrames: [String: (CGRect, Zone?)] = [:]
    var placed: [String: [CGRect]] = [:]
    var result: [PlatePlacement] = []
    // The check docks beside its display's level plate, so place it last.
    let ordered =
      timeline.entries.filter { !$0.content.isDisplayCheck } + timeline.entries.filter(\.content.isDisplayCheck)
    for entry in ordered {
      let content = entry.content
      let screen = screen(for: content, in: all) ?? fallback
      let visible = screen.visibleFrame
      let size = presenter.size(of: content)
      let others = placed[screen.id, default: []]
      let frame: CGRect
      if content.isDisplayCheck {
        // Once placed, the question stays put while the level plate beside it fades.
        if let pinned = checkFrame {
          frame = pinned
        } else if let (level, zone) = levelFrames[screen.id] {
          let beside = PlateDocking.beside(level, size: size, zone: zone, in: visible)
          frame = PlateDocking.settle(beside, zone: zone, in: visible, work: workArea, plates: others)
        } else {
          let docked = PlateDocking.frame(zone: nil, size: size, in: visible)
          frame = PlateDocking.settle(docked, zone: nil, in: visible, work: workArea, plates: others)
        }
        checkFrame = frame
      } else {
        let key = "\(screen.id)|\(PlateDocking.dockKey(content.zone))"
        let docked = PlateDocking.frame(zone: content.zone, size: size, in: visible, stack: used[key, default: 0])
        frame = PlateDocking.settle(docked, zone: content.zone, in: visible, work: workArea, plates: others)
        used[key, default: 0] += 1
        if content.kind == .level { levelFrames[screen.id] = (frame, content.zone) }
      }
      placed[screen.id, default: []].append(frame)
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
    presenter.present(placements(), screens: screenList) { [weak self] responds in
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

  private let log = Logger(subsystem: "com.garavit.edgy", category: "overlay")
  private var loggedUntrusted = false
  /// Each Accessibility read may block this long at most (the frontmost app answers the IPC).
  static let messagingTimeout: Float = 0.1

  /// The frontmost app's focused element and focused window, through Accessibility. Empty (plates
  /// simply dock at the edge) when Accessibility isn't granted or the app doesn't answer.
  func workArea() -> OverlayWorkArea {
    guard AXIsProcessTrusted() else {
      if !loggedUntrusted {
        log.info("work area: Accessibility not granted; plates dock without avoiding the text")
        loggedUntrusted = true
      }
      return OverlayWorkArea()
    }
    guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
      pid != ProcessInfo.processInfo.processIdentifier
    else { return OverlayWorkArea() }
    let app = AXUIElementCreateApplication(pid)
    AXUIElementSetMessagingTimeout(app, Self.messagingTimeout)
    let text = element(app, kAXFocusedUIElementAttribute).flatMap(frame(of:))
    let window = element(app, kAXFocusedWindowAttribute).flatMap(frame(of:))
    if text == nil && window == nil { log.debug("work area: the frontmost app reported no focused element") }
    return OverlayWorkArea(text: text, window: window)
  }

  private func element(_ parent: AXUIElement, _ attribute: String) -> AXUIElement? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(parent, attribute as CFString, &value) == .success, let value,
      CFGetTypeID(value) == AXUIElementGetTypeID()
    else { return nil }
    let element = unsafeDowncast(value, to: AXUIElement.self)
    AXUIElementSetMessagingTimeout(element, Self.messagingTimeout)
    return element
  }

  /// An element's frame, flipped from Accessibility's top-left origin to AppKit's bottom-left.
  private func frame(of element: AXUIElement) -> CGRect? {
    var origin = CGPoint.zero
    var size = CGSize.zero
    guard let position = axValue(element, kAXPositionAttribute), AXValueGetValue(position, .cgPoint, &origin),
      let extent = axValue(element, kAXSizeAttribute), AXValueGetValue(extent, .cgSize, &size),
      size.width > 0, size.height > 0, let primary = NSScreen.screens.first
    else { return nil }
    return CGRect(x: origin.x, y: primary.frame.maxY - origin.y - size.height, width: size.width, height: size.height)
  }

  private func axValue(_ element: AXUIElement, _ attribute: String) -> AXValue? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success, let value,
      CFGetTypeID(value) == AXValueGetTypeID()
    else { return nil }
    return unsafeDowncast(value, to: AXValue.self)
  }

  static func id(of screen: NSScreen) -> String {
    let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
    return number.map { "\($0.uint32Value)" } ?? screen.localizedName
  }
}

@MainActor
final class RunLoopClock: OverlayClock {
  /// About 30 ticks a second: smooth 200 ms fades. Runs only while a plate is up (batch 28).
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
