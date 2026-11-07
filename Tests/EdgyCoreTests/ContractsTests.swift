import Foundation
import Testing

@testable import EdgyCore

@Test func keyComboParsesAndCanonicalizes() {
  #expect(KeyCombo("Shift+CMD+4")?.description == "shift+cmd+4")
  #expect(KeyCombo("command+option+left")?.description == "opt+cmd+left")
  #expect(KeyCombo("f5")?.description == "f5")
  #expect(KeyCombo("ctrl+esc")?.key == "escape")
  #expect(KeyCombo("cmd+/")?.key == "slash")
}

@Test func keyComboRejectsInvalidText() {
  #expect(KeyCombo("") == nil)
  #expect(KeyCombo("cmd+a+b") == nil)  // two keys
  #expect(KeyCombo("cmd+cmd+a") == nil)  // repeated modifier
  #expect(KeyCombo("cmd++a") == nil)
  #expect(KeyCombo("hyper+a") == nil)
}

@Test func keyComboRoundTripsThroughDescription() {
  for name in KeyCombo.keyNames {
    let combo = KeyCombo(modifiers: [.cmd, .shift], key: name)
    #expect(KeyCombo(combo.description) == combo)
  }
}

@Test func zoneSupportsOnlyGesturesItCanProduce() {
  #expect(Zone.corner(.topLeft).supports(.doubleTap))
  #expect(Zone.corner(.topLeft).supports(.longPress))
  #expect(!Zone.corner(.topLeft).supports(.slide))
  #expect(!Zone.corner(.topLeft).supports(.swipe(.left)))
  #expect(Zone.edge(.bottom).supports(.swipe(.left)))
  #expect(!Zone.edge(.bottom).supports(.swipe(.up)))
  #expect(Zone.edge(.right).supports(.swipe(.up)))
  #expect(!Zone.edge(.right).supports(.swipe(.right)))
  #expect(Zone.edge(.left, segment: 1, segments: 2).supports(.slide))
}

@Test func defaultBindingsAreAllSupported() {
  for binding in EdgyConfig.defaults.defaultProfile.bindings {
    #expect(binding.zone.supports(binding.gesture))
  }
}

@Test func descriptorDefaultsKeepOldInitializerWorking() {
  let d = ActionDescriptor(id: "x.y", shape: .trigger, displayName: "X")
  #expect(d.category == .system)
  #expect(d.parameters.isEmpty)
}

@Test func availabilityDefaultsToAvailable() {
  final class Bare: ActionPerforming {
    var available: [ActionDescriptor] { [] }
    func perform(_ id: ActionID, input: ActionInput, context: ActionContext) throws {}
  }
  #expect(Bare().availability(of: "x.y") == .available)
  #expect(ActionAvailability.limited(reason: "r").isUsable)
  #expect(!ActionAvailability.unavailable(reason: "r").isUsable)
}

@Test func keyComboParsesModifierOnly() {
  let fn = KeyCombo("fn")
  #expect(fn?.key == nil)
  #expect(fn?.isModifierOnly == true)
  #expect(fn?.modifiers == [.fn])
  #expect(KeyCombo("opt+ctrl")?.description == "ctrl+opt")
  #expect(KeyCombo("ctrl+opt")?.isModifierOnly == true)
  #expect(KeyCombo(modifiers: []) == nil)
  #expect(KeyCombo("fn+fn") == nil)
  #expect(KeyCombo("cmd+a")?.isModifierOnly == false)
}

@Test func touchFrameDecodesOlderTracesWithoutButtonState() throws {
  let json = #"{"deviceID":1,"timestamp":2.5,"frameNumber":3,"contacts":[]}"#
  let frame = try JSONDecoder().decode(TouchFrame.self, from: Data(json.utf8))
  #expect(frame.buttonDown == false)
  var pressed = frame
  pressed.buttonDown = true
  let roundTrip = try JSONDecoder().decode(TouchFrame.self, from: JSONEncoder().encode(pressed))
  #expect(roundTrip.buttonDown)
}

private let right = Zone.edge(.right)
private let bottom = Zone.edge(.bottom)
private let baseProfile = Profile(bindings: [
  Binding(zone: right, gesture: .slide, action: "audio.volume"),
  Binding(zone: bottom, gesture: .swipe(.left), action: "media.previous"),
  Binding(zone: bottom, gesture: .doubleTap, action: "media.playPause"),
])

private func config(app: Profile) -> EdgyConfig {
  EdgyConfig(app: .defaults, gestures: .defaults, defaultProfile: baseProfile, appProfiles: ["com.example.term": app])
}

@Test func olderProfilesDecodeAsFullReplacement() throws {
  let json = #"{"bindings":[],"disabled":false}"#
  let profile = try JSONDecoder().decode(Profile.self, from: Data(json.utf8))
  #expect(profile.inheritsDefault == false)
  #expect(config(app: profile).profile(for: "com.example.term").bindings.isEmpty)
}

@Test func inheritingProfileOverridesOnlyItsOwnGestures() {
  let app = Profile(
    bindings: [
      Binding(
        zone: bottom, gesture: .swipe(.left), action: "keyboard.shortcut", parameters: ["keys": "cmd+shift+leftbracket"]
      ),
      Binding(zone: .corner(.topLeft), gesture: .longPress, action: "keyboard.hold", parameters: ["keys": "fn"]),
    ],
    inheritsDefault: true)
  let resolved = config(app: app).profile(for: "com.example.term")
  #expect(resolved.bindings.map(\.action) == ["audio.volume", "keyboard.shortcut", "media.playPause", "keyboard.hold"])
  #expect(resolved.inheritsDefault == false)
}

@Test func doNothingTurnsADefaultGestureOffForOneApp() {
  let app = Profile(bindings: [Binding(zone: right, gesture: .slide, action: .doNothing)], inheritsDefault: true)
  let c = config(app: app)
  #expect(!c.profile(for: "com.example.term").bindings.contains { $0.zone == right })
  #expect(c.profile(for: "com.example.other").bindings.contains { $0.zone == right })
  #expect(c.profile(for: nil).bindings.count == 3)
}

@Test func disabledInheritingProfileStaysDisabled() {
  let app = Profile(bindings: [], disabled: true, inheritsDefault: true)
  #expect(config(app: app).profile(for: "com.example.term").disabled)
}
