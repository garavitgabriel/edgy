import EdgyCore
import Foundation
import Testing

@testable import TouchKit

@Suite struct DeviceDiffTests {
  @Test func detectsAdded() {
    let d = DeviceDiff.between(old: [device(1)], new: [device(1), device(2)])
    #expect(d.added == [device(2)] && d.removed.isEmpty && d.unchanged == [device(1)] && !d.isEmpty)
  }

  @Test func detectsRemoved() {
    let d = DeviceDiff.between(old: [device(1), device(2)], new: [device(2)])
    #expect(d.removed == [device(1)] && d.added.isEmpty && !d.isEmpty)
  }

  @Test func sameListIsEmpty() {
    let d = DeviceDiff.between(old: [device(1), device(2)], new: [device(2), device(1)])
    #expect(d.isEmpty && d.unchanged.count == 2)
  }

  @Test func detectsChangedDescription() {
    let d = DeviceDiff.between(old: [device(1, width: 100)], new: [device(1, width: 160)])
    #expect(d.changed == [device(1, width: 160)] && !d.isEmpty)
  }
}

@Suite struct DeviceManagerTests {
  func make(_ devices: [TouchDeviceInfo]) -> (DeviceManager, FakeBackend, FakeNotifier, Box<[[TouchDeviceInfo]]>) {
    let backend = FakeBackend()
    backend.devices = devices
    let notifier = FakeNotifier()
    let manager = DeviceManager(backend: backend, notifier: notifier)
    return (manager, backend, notifier, Box([]))
  }

  @Test func startRegistersEachDeviceOnceAndReportsList() {
    let (manager, backend, notifier, changes) = make([device(1), device(2)])
    manager.start(onFrame: { _ in }, onDevicesChanged: { list in changes.mutate { $0.append(list) } })
    #expect(backend.registerLog.sorted() == [1, 2])
    #expect(changes.value == [[device(1), device(2)]])
    #expect(manager.devices == [device(1), device(2)])
    #expect(notifier.startCount == 1)
  }

  @Test func hotPlugAddRegistersOnlyTheNewDevice() {
    let (manager, backend, notifier, changes) = make([device(1)])
    manager.start(onFrame: { _ in }, onDevicesChanged: { list in changes.mutate { $0.append(list) } })
    backend.devices = [device(1), device(2)]
    notifier.fire(.attached)
    #expect(backend.registerLog == [1, 2])
    #expect(backend.unregisterLog.isEmpty)
    #expect(changes.value.last == [device(1), device(2)])
  }

  @Test func hotPlugRemoveUnregistersAndReports() {
    let (manager, backend, notifier, changes) = make([device(1), device(2)])
    manager.start(onFrame: { _ in }, onDevicesChanged: { list in changes.mutate { $0.append(list) } })
    backend.devices = [device(1)]
    notifier.fire(.detached)
    #expect(backend.unregisterLog == [2])
    #expect(manager.registeredDeviceIDs == [1])
    #expect(changes.value.last == [device(1)])
  }

  @Test func unchangedRefreshDoesNothing() {
    let (manager, backend, notifier, changes) = make([device(1)])
    manager.start(onFrame: { _ in }, onDevicesChanged: { list in changes.mutate { $0.append(list) } })
    notifier.fire(.attached)
    notifier.fire(.manual)
    #expect(backend.registerLog == [1])
    #expect(backend.unregisterLog.isEmpty)
    #expect(changes.value.count == 1)
  }

  @Test func wakeReRegistersEveryDeviceExactlyOnce() {
    let (manager, backend, notifier, _) = make([device(1), device(2)])
    manager.start(onFrame: { _ in }, onDevicesChanged: { _ in })
    notifier.fire(.woke)
    #expect(backend.unregisterLog.sorted() == [1, 2])
    #expect(backend.registerLog.sorted() == [1, 1, 2, 2])
    #expect(backend.activeIDs == [1, 2])
  }

  @Test func failedRegistrationIsRetriedOnNextRefresh() {
    let (manager, backend, notifier, _) = make([device(1)])
    backend.failing = [1]
    manager.start(onFrame: { _ in }, onDevicesChanged: { _ in })
    #expect(manager.registeredDeviceIDs.isEmpty)
    backend.failing = []
    notifier.fire(.manual)
    #expect(manager.registeredDeviceIDs == [1])
    #expect(backend.registerLog == [1, 1])
  }

  @Test func duplicateEnumerationEntriesRegisterOnce() {
    let (manager, backend, _, _) = make([device(1), device(1)])
    manager.start(onFrame: { _ in }, onDevicesChanged: { _ in })
    #expect(backend.registerLog == [1])
    #expect(manager.devices == [device(1)])
  }

  @Test func stopUnregistersAllAndIgnoresLaterEvents() {
    let (manager, backend, notifier, _) = make([device(1), device(2)])
    manager.start(onFrame: { _ in }, onDevicesChanged: { _ in })
    manager.stop()
    #expect(backend.unregisterLog.sorted() == [1, 2])
    #expect(backend.activeIDs.isEmpty)
    #expect(notifier.stopCount == 1)
    manager.handle(.attached)
    #expect(backend.registerLog.count == 2)
  }

  @Test func restartAfterStopRegistersAgain() {
    let (manager, backend, _, _) = make([device(1)])
    manager.start(onFrame: { _ in }, onDevicesChanged: { _ in })
    manager.stop()
    manager.start(onFrame: { _ in }, onDevicesChanged: { _ in })
    #expect(backend.registerLog == [1, 1])
    #expect(backend.activeIDs == [1])
  }

  @Test func forwardsFramesFromRegisteredDevices() {
    let (manager, backend, _, _) = make([device(5)])
    let frames = Box<[TouchFrame]>([])
    manager.start(onFrame: { f in frames.mutate { $0.append(f) } }, onDevicesChanged: { _ in })
    backend.emit(TouchFrame(deviceID: 5, timestamp: 1, frameNumber: 1, contacts: []))
    #expect(frames.value.count == 1)
    manager.stop()
    backend.emit(TouchFrame(deviceID: 5, timestamp: 2, frameNumber: 2, contacts: []))
    #expect(frames.value.count == 1)
  }
}
