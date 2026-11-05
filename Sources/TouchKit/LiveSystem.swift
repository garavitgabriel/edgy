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
        backend: LiveMultitouchBackend(framework: framework), notifier: LiveDeviceChangeNotifier())
      manager = created
      return created
    }
    m.start(onFrame: onFrame, onDevicesChanged: onDevicesChanged)
  }

  func stop() {
    lock.withLock { manager }?.stop()
  }
}

/// Active event tap on pointer motion at the HID level.
final class LiveEventTap: EventTapping, @unchecked Sendable {
  private let lock = NSLock()
  private var port: CFMachPort?
  private var handler: (@Sendable (TapEventKind, Point2D?) -> TapVerdict)?

  func install(handler: @escaping @Sendable (TapEventKind, Point2D?) -> TapVerdict) -> Bool {
    lock.withLock { self.handler = handler }
    let types: [CGEventType] = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
    let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << CGEventMask($1.rawValue)) }
    guard
      let tap = CGEvent.tapCreate(
        tap: .cghidEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask,
        callback: liveTapCallback, userInfo: Unmanaged.passUnretained(self).toOpaque())
    else { return false }
    guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else { return false }
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    lock.withLock { port = tap }
    // Intentionally retained for the process lifetime (the tap's userInfo points at self).
    _ = Unmanaged.passRetained(self)
    return true
  }

  func setEnabled(_ enabled: Bool) {
    if let port = lock.withLock({ port }) { CGEvent.tapEnable(tap: port, enable: enabled) }
  }

  fileprivate func handle(_ type: CGEventType, location: CGPoint) -> TapVerdict {
    let kind: TapEventKind
    switch type {
    case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged: kind = .pointerMotion
    case .tapDisabledByTimeout: kind = .disabledByTimeout
    case .tapDisabledByUserInput: kind = .disabledByUserInput
    default: kind = .other
    }
    let point = kind == .pointerMotion ? Point2D(x: location.x, y: location.y) : nil
    return lock.withLock { handler }?(kind, point) ?? .pass
  }
}

private let liveTapCallback: CGEventTapCallBack = { _, type, event, refcon in
  guard let refcon else { return Unmanaged.passUnretained(event) }
  let tap = Unmanaged<LiveEventTap>.fromOpaque(refcon).takeUnretainedValue()
  return tap.handle(type, location: event.location) == .swallow ? nil : Unmanaged.passUnretained(event)
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
