import AppKit
import ApplicationServices
import CoreGraphics
import EdgyCore
import Foundation

// Live system adapters. Never constructed by tests.

/// The live `TouchSource`: device manager over the private-framework backend + IOKit notifier.
final class LiveTouchSource: TouchSource, @unchecked Sendable {
  private let lock = NSLock()
  private var manager: DeviceManager?

  var devices: [TouchDeviceInfo] { lock.withLock { manager }?.devices ?? [] }

  func start(
    onFrame: @escaping @Sendable (TouchFrame) -> Void,
    onDevicesChanged: @escaping @Sendable ([TouchDeviceInfo]) -> Void
  ) throws {
    guard let framework = MultitouchFramework.shared else {
      throw TouchKitError.multitouchUnavailable(reason: MultitouchFramework.loadFailure ?? "unknown")
    }
    let m = lock.withLock { () -> DeviceManager in
      if let manager { return manager }
      let created = DeviceManager(
        backend: LiveMultitouchBackend(framework: framework), notifier: LiveDeviceChangeNotifier(),
        buttonState: HIDButtonState(), padContacts: .shared)
      manager = created
      return created
    }
    m.start(onFrame: onFrame, onDevicesChanged: onDevicesChanged)
  }

  func stop() {
    lock.withLock { manager }?.stop()
  }
}

/// Button state read from the HID system state at frame time (`CGEventSource.buttonState`).
///
/// Chosen over a listen-only event tap: the read is synchronous when the frame is handed out, and
/// the HID system state changes as the HID event is processed, before the event reaches any tap.
/// So it can't lag the frame the way a tap callback (a WindowServer hop, then a run loop that may
/// be busy) can. It needs no permission and has nothing a timeout can disable. It covers every
/// pointing device the system knows (built-in and Bluetooth trackpads alike). It also doesn't say
/// which device clicked, so a mouse click while a thumb rests on a trackpad edge rejects the thumb.
/// Primary or secondary: a secondary click ("click in the bottom-right corner") is a press too.
final class HIDButtonState: ButtonStateSource, @unchecked Sendable {
  private let lock = NSLock()
  private var source: CGEventSource?

  func start() -> Bool {
    guard let created = CGEventSource(stateID: .hidSystemState) else {
      TouchKitLog.touch.error("button state unavailable: no HID system event source; clicks read as touches")
      return false
    }
    lock.withLock { source = created }
    return true
  }

  func stop() {
    lock.withLock { source = nil }
  }

  var isDown: Bool {
    guard lock.withLock({ source != nil }) else { return false }
    return CGEventSource.buttonState(.hidSystemState, button: .left)
      || CGEventSource.buttonState(.hidSystemState, button: .right)
  }
}

/// Active event tap on pointer motion and left button down/up at the HID level, on the input thread's run loop (batch 28):
/// every pointer event in the system waits on this tap, so it never shares a thread with drawing.
final class LiveEventTap: EventTapping, @unchecked Sendable {
  private let lock = NSLock()
  private var port: CFMachPort?
  private var handler: (@Sendable (TapEventKind, Point2D?) -> TapVerdict)?

  func install(handler: @escaping @Sendable (TapEventKind, Point2D?) -> TapVerdict) -> Bool {
    lock.withLock { self.handler = handler }
    let types: [CGEventType] = [
      .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .leftMouseDown, .leftMouseUp,
    ]
    let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << CGEventMask($1.rawValue)) }
    guard
      let tap = CGEvent.tapCreate(
        tap: .cghidEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask,
        callback: liveTapCallback, userInfo: Unmanaged.passUnretained(self).toOpaque())
    else { return false }
    guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else { return false }
    lock.withLock { port = tap }
    InputRunLoop.shared.add(source)
    CGEvent.tapEnable(tap: tap, enable: true)
    // Intentionally retained for the process lifetime (the tap's userInfo points at self).
    _ = Unmanaged.passRetained(self)
    return true
  }

  func setEnabled(_ enabled: Bool) {
    if let port = lock.withLock({ port }) { CGEvent.tapEnable(tap: port, enable: enabled) }
  }

  fileprivate func handle(_ type: CGEventType, event: CGEvent) -> TapVerdict {
    let kind: TapEventKind
    switch type {
    case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged: kind = .pointerMotion
    case .leftMouseDown: kind = .leftDown(clickState: Int(event.getIntegerValueField(.mouseEventClickState)))
    case .leftMouseUp: kind = .leftUp
    case .tapDisabledByTimeout: kind = .disabledByTimeout
    case .tapDisabledByUserInput: kind = .disabledByUserInput
    default: kind = .other
    }
    let location = event.location
    let point = kind == .pointerMotion ? Point2D(x: location.x, y: location.y) : nil
    return lock.withLock { handler }?(kind, point) ?? .pass
  }
}

private let liveTapCallback: CGEventTapCallBack = { _, type, event, refcon in
  guard let refcon else { return Unmanaged.passUnretained(event) }
  let tap = Unmanaged<LiveEventTap>.fromOpaque(refcon).takeUnretainedValue()
  return tap.handle(type, event: event) == .swallow ? nil : Unmanaged.passUnretained(event)
}

/// Cursor position in global display coordinates (origin top-left of the main display).
final class LiveCursor: CursorControlling, @unchecked Sendable {
  func position() -> Point2D? {
    guard let location = CGEvent(source: nil)?.location else { return nil }
    return Point2D(x: location.x, y: location.y)
  }

  func warp(to point: Point2D) {
    CGWarpMouseCursorPosition(CGPoint(x: point.x, y: point.y))
    // Re-associate so the warp does not suppress the next pointer events.
    CGAssociateMouseAndMouseCursorPosition(1)
  }
}

final class DispatchGuardScheduler: GuardScheduling, @unchecked Sendable {
  private final class Item: GuardCancellable, @unchecked Sendable {
    let work: DispatchWorkItem
    init(_ work: DispatchWorkItem) { self.work = work }
    func cancel() { work.cancel() }
  }

  func schedule(after seconds: TimeInterval, _ work: @escaping @Sendable () -> Void) -> any GuardCancellable {
    let item = DispatchWorkItem(block: work)
    DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + seconds, execute: item)
    return Item(item)
  }
}

/// Global (and local, for our own windows) key-down monitor.
final class LiveKeyMonitor: KeyMonitorInstalling, @unchecked Sendable {
  private var monitors: [Any] = []

  func install(onKeyDown: @escaping @Sendable () -> Void) -> Bool {
    let work = { @Sendable [weak self] in
      MainActor.assumeIsolated {
        guard let self else { return }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { _ in onKeyDown() }) {
          self.monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(
          matching: .keyDown,
          handler: { event in
            onKeyDown()
            return event
          })
        {
          self.monitors.append(local)
        }
      }
    }
    if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    return true
  }
}

enum LivePermissions {
  /// Accessibility trust (needed for the event tap and the global key monitor). Never prompts.
  static func isAccessibilityTrusted() -> Bool { AXIsProcessTrusted() }
}
