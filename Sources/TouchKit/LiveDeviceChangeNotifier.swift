import AppKit
import Foundation
import IOKit

/// Hot-plug via IOKit matching notifications on the multitouch device class (first-match +
/// terminated), plus sleep/wake via workspace notifications. Events are delivered on the main
/// run loop, debounced: devices are often not ready the instant they match, so each event
/// triggers a refresh shortly after and a second, later one (refreshes are idempotent).
final class LiveDeviceChangeNotifier: DeviceChangeNotifying, @unchecked Sendable {
  static let serviceClass = "AppleMultitouchDevice"
  static let refreshDelays: [TimeInterval] = [0.4, 2.0]
  static let wakeDelays: [TimeInterval] = [1.0, 3.0]

  private let lock = NSLock()
  private var handler: (@Sendable (DeviceChangeEvent) -> Void)?
  private var port: IONotificationPortRef?
  private var addedIterator: io_iterator_t = 0
  private var removedIterator: io_iterator_t = 0
  private var observers: [NSObjectProtocol] = []

  func start(_ handler: @escaping @Sendable (DeviceChangeEvent) -> Void) -> Bool {
    lock.withLock { self.handler = handler }
    var ok = true
    if let port = IONotificationPortCreate(kIOMainPortDefault) {
      self.port = port
      CFRunLoopAddSource(
        CFRunLoopGetMain(), IONotificationPortGetRunLoopSource(port).takeUnretainedValue(), .defaultMode)
      let refcon = Unmanaged.passUnretained(self).toOpaque()
      let added: IOServiceMatchingCallback = { refcon, iterator in
        LiveDeviceChangeNotifier.drain(iterator)
        guard let refcon else { return }
        Unmanaged<LiveDeviceChangeNotifier>.fromOpaque(refcon).takeUnretainedValue().emit(.attached)
      }
      let removed: IOServiceMatchingCallback = { refcon, iterator in
        LiveDeviceChangeNotifier.drain(iterator)
        guard let refcon else { return }
        Unmanaged<LiveDeviceChangeNotifier>.fromOpaque(refcon).takeUnretainedValue().emit(.detached)
      }
      let r1 = IOServiceAddMatchingNotification(
        port, kIOFirstMatchNotification, IOServiceMatching(Self.serviceClass), added, refcon, &addedIterator)
      let r2 = IOServiceAddMatchingNotification(
        port, kIOTerminatedNotification, IOServiceMatching(Self.serviceClass), removed, refcon, &removedIterator)
      // Draining arms the notifications; existing devices are covered by the initial enumeration.
      Self.drain(addedIterator)
      Self.drain(removedIterator)
      if r1 != KERN_SUCCESS || r2 != KERN_SUCCESS {
        TouchKitLog.touch.error("IOKit device notifications failed (\(r1), \(r2))")
        ok = false
      }
    } else {
      TouchKitLog.touch.error("IOKit notification port unavailable")
      ok = false
    }
    let center = NSWorkspace.shared.notificationCenter
    observers.append(
      center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
        self?.emit(.woke)
      })
    return ok
  }

  func stop() {
    lock.withLock { handler = nil }
    for o in observers { NSWorkspace.shared.notificationCenter.removeObserver(o) }
    observers.removeAll()
    if addedIterator != 0 { IOObjectRelease(addedIterator) }
    if removedIterator != 0 { IOObjectRelease(removedIterator) }
    addedIterator = 0
    removedIterator = 0
    if let port { IONotificationPortDestroy(port) }
    port = nil
  }

  private func emit(_ event: DeviceChangeEvent) {
    let delays = event == .woke ? Self.wakeDelays : Self.refreshDelays
    for (index, delay) in delays.enumerated() {
      // Only the first refresh after wake re-registers everything; the later one just diffs.
      let e: DeviceChangeEvent = (event == .woke && index > 0) ? .manual : event
      DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
        let h = self?.lock.withLock { self?.handler }
        h?(e)
      }
    }
  }

  fileprivate static func drain(_ iterator: io_iterator_t) {
    while case let service = IOIteratorNext(iterator), service != 0 { IOObjectRelease(service) }
  }
}
