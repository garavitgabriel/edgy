import CoreAudio
import Foundation

/// Default output / input devices through public CoreAudio. Every call resolves the current
/// default device, so switching outputs needs no extra bookkeeping.
final class LiveAudioOutput: AudioOutput {
  private static let mainElement = kAudioObjectPropertyElementMain
  /// Four-char code of the headphone data source on built-in outputs.
  private static let headphoneSource: UInt32 = 0x6864_706E  // "hdpn"

  func outputVolume() throws -> Double {
    let device = try Self.defaultDevice(output: true)
    for element in try Self.volumeElements(device) {
      let value: Float32 = try Self.get(device, kAudioDevicePropertyVolumeScalar, output: true, element)
      return Double(value)
    }
    throw OutputError("output device has no volume control")
  }

  func setOutputVolume(_ level: Double) throws {
    let device = try Self.defaultDevice(output: true)
    let elements = try Self.volumeElements(device)
    guard !elements.isEmpty else { throw OutputError("output device has no volume control") }
    for element in elements {
      try Self.set(device, kAudioDevicePropertyVolumeScalar, output: true, element, Float32(level))
    }
  }

  func isOutputMuted() throws -> Bool { try Self.muted(output: true) }
  func setOutputMuted(_ muted: Bool) throws { try Self.setMuted(muted, output: true) }
  func isInputMuted() throws -> Bool { try Self.muted(output: false) }
  func setInputMuted(_ muted: Bool) throws { try Self.setMuted(muted, output: false) }

  func outputIsHeadphones() -> Bool {
    guard let device = try? Self.defaultDevice(output: true),
      Self.has(device, kAudioDevicePropertyDataSource, output: true, Self.mainElement),
      let source: UInt32 = try? Self.get(device, kAudioDevicePropertyDataSource, output: true, Self.mainElement)
    else { return false }
    return source == Self.headphoneSource
  }

  // MARK: - CoreAudio plumbing

  private static func muted(output: Bool) throws -> Bool {
    let device = try defaultDevice(output: output)
    guard has(device, kAudioDevicePropertyMute, output: output, mainElement) else {
      throw OutputError("\(output ? "output" : "input") device has no mute control")
    }
    let value: UInt32 = try get(device, kAudioDevicePropertyMute, output: output, mainElement)
    return value != 0
  }

  private static func setMuted(_ muted: Bool, output: Bool) throws {
    let device = try defaultDevice(output: output)
    guard settable(device, kAudioDevicePropertyMute, output: output, mainElement) else {
      throw OutputError("\(output ? "output" : "input") device has no mute control")
    }
    try set(device, kAudioDevicePropertyMute, output: output, mainElement, UInt32(muted ? 1 : 0))
  }

  /// The main element when it has a settable volume, else the first two channels.
  private static func volumeElements(_ device: AudioObjectID) throws -> [AudioObjectPropertyElement] {
    if settable(device, kAudioDevicePropertyVolumeScalar, output: true, mainElement) { return [mainElement] }
    return [1, 2].filter { settable(device, kAudioDevicePropertyVolumeScalar, output: true, $0) }
  }

  private static func defaultDevice(output: Bool) throws -> AudioObjectID {
    var address = AudioObjectPropertyAddress(
      mSelector: output ? kAudioHardwarePropertyDefaultOutputDevice : kAudioHardwarePropertyDefaultInputDevice,
      mScope: kAudioObjectPropertyScopeGlobal, mElement: mainElement)
    var device = AudioObjectID(kAudioObjectUnknown)
    var size = UInt32(MemoryLayout<AudioObjectID>.size)
    let status = AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
    guard status == noErr, device != kAudioObjectUnknown else {
      throw OutputError("no default \(output ? "output" : "input") device (\(status))")
    }
    return device
  }

  private static func address(
    _ selector: AudioObjectPropertySelector, output: Bool, _ element: AudioObjectPropertyElement
  ) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(
      mSelector: selector, mScope: output ? kAudioDevicePropertyScopeOutput : kAudioDevicePropertyScopeInput,
      mElement: element)
  }

  private static func has(
    _ device: AudioObjectID, _ selector: AudioObjectPropertySelector, output: Bool,
    _ element: AudioObjectPropertyElement
  ) -> Bool {
    var address = address(selector, output: output, element)
    return AudioObjectHasProperty(device, &address)
  }

  private static func settable(
    _ device: AudioObjectID, _ selector: AudioObjectPropertySelector, output: Bool,
    _ element: AudioObjectPropertyElement
  ) -> Bool {
    var address = address(selector, output: output, element)
    guard AudioObjectHasProperty(device, &address) else { return false }
    var settable: DarwinBoolean = false
    return AudioObjectIsPropertySettable(device, &address, &settable) == noErr && settable.boolValue
  }

  private static func get<T: FixedWidthInteger & BitwiseCopyable>(
    _ device: AudioObjectID, _ selector: AudioObjectPropertySelector, output: Bool,
    _ element: AudioObjectPropertyElement
  ) throws -> T {
    var value: T = 0
    try read(device, selector, output: output, element, into: &value)
    return value
  }

  private static func get(
    _ device: AudioObjectID, _ selector: AudioObjectPropertySelector, output: Bool,
    _ element: AudioObjectPropertyElement
  ) throws -> Float32 {
    var value: Float32 = 0
    try read(device, selector, output: output, element, into: &value)
    return value
  }

  private static func read<T: BitwiseCopyable>(
    _ device: AudioObjectID, _ selector: AudioObjectPropertySelector, output: Bool,
    _ element: AudioObjectPropertyElement, into value: inout T
  ) throws {
    var address = address(selector, output: output, element)
    var size = UInt32(MemoryLayout<T>.size)
    let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value)
    guard status == noErr else { throw OutputError("audio property read failed (\(status))") }
  }

  private static func set<T: BitwiseCopyable>(
    _ device: AudioObjectID, _ selector: AudioObjectPropertySelector, output: Bool,
    _ element: AudioObjectPropertyElement, _ value: T
  ) throws {
    var address = address(selector, output: output, element)
    var value = value
    let status = AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<T>.size), &value)
    guard status == noErr else { throw OutputError("audio property write failed (\(status))") }
  }
}
