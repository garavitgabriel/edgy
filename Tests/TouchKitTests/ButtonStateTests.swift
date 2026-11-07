import EdgyCore
import Foundation
import Testing

@testable import TouchKit

/// `DeviceManager` stamps `TouchFrame.buttonDown` from a fake button source. No test reads real
/// input: the live `HIDButtonState` is only built by `LiveTouchSource`.
@Suite struct ButtonStateTests {
  func frame(_ number: Int32, deviceID: UInt64 = 1) -> TouchFrame {
    TouchFrame(deviceID: deviceID, timestamp: Double(number) / 120, frameNumber: number, contacts: [])
  }

  func make(_ button: FakeButtonState) -> (DeviceManager, FakeBackend, Box<[TouchFrame]>) {
    let backend = FakeBackend()
    backend.devices = [device(1), device(2)]
    let manager = DeviceManager(backend: backend, notifier: FakeNotifier(), buttonState: button)
    return (manager, backend, Box([]))
  }

  @Test func framesCarryTheButtonStateInPressReleaseOrder() {
    let button = FakeButtonState()
    let (manager, backend, frames) = make(button)
    manager.start(onFrame: { f in frames.mutate { $0.append(f) } }, onDevicesChanged: { _ in })
    backend.emit(frame(1))
    button.down = true
    backend.emit(frame(2))  // the first frame after the press
    backend.emit(frame(3, deviceID: 2))  // every device sees it
    backend.emit(frame(4))
    button.down = false
    backend.emit(frame(5))  // the first frame after the release
    #expect(frames.value.map(\.buttonDown) == [false, true, true, true, false])
    #expect(frames.value.map(\.frameNumber) == [1, 2, 3, 4, 5])
    manager.stop()
  }

  @Test func failedStartReadsButtonUp() {
    let button = FakeButtonState(startResult: false)
    button.down = true
    let (manager, backend, frames) = make(button)
    manager.start(onFrame: { f in frames.mutate { $0.append(f) } }, onDevicesChanged: { _ in })
    backend.emit(frame(1))
    backend.emit(frame(2))
    #expect(frames.value.count == 2)
    #expect(frames.value.allSatisfy { !$0.buttonDown })
    manager.stop()
  }

  @Test func sourceStartsOnStartNotAtConstructionAndStopsWithTheManager() {
    let button = FakeButtonState()
    let (manager, _, _) = make(button)
    #expect(button.starts == 0, "nothing starts at construction")
    manager.start(onFrame: { _ in }, onDevicesChanged: { _ in })
    #expect(button.starts == 1)
    manager.start(onFrame: { _ in }, onDevicesChanged: { _ in })
    #expect(button.starts == 1, "a second start only swaps handlers")
    manager.stop()
    #expect(button.stops == 1)
  }

  @Test func restartAfterAFailedStartTriesAgain() {
    let button = FakeButtonState(startResult: false)
    let (manager, _, _) = make(button)
    manager.start(onFrame: { _ in }, onDevicesChanged: { _ in })
    manager.stop()
    manager.start(onFrame: { _ in }, onDevicesChanged: { _ in })
    #expect(button.starts == 2)
    manager.stop()
  }

  @Test func withoutASourceEveryFrameReadsButtonUp() {
    let backend = FakeBackend()
    backend.devices = [device(1)]
    let manager = DeviceManager(backend: backend, notifier: FakeNotifier())
    let frames = Box<[TouchFrame]>([])
    manager.start(onFrame: { f in frames.mutate { $0.append(f) } }, onDevicesChanged: { _ in })
    backend.emit(frame(1))
    #expect(frames.value.map(\.buttonDown) == [false])
    manager.stop()
  }
}
