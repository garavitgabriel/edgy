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
  #expect(KeyCombo("cmd") == nil)  // no key
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
