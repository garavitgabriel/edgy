import EdgyCore
import Foundation
import Testing

@testable import EdgyRuntime

@Suite struct ValidationTests {
  let validator = ConfigValidator(catalog: FakeCatalog.descriptors)

  func codes(_ binding: Binding) -> [ValidationIssue.Code] {
    validator.validate(binding).map(\.code)
  }

  func everything(_ key: String, _ value: String) -> Binding {
    Binding(zone: .corner(.topLeft), gesture: .tap, action: "fake.everything", parameters: [key: value])
  }

  @Test func defaultsAreClean() {
    #expect(validator.validate(EdgyConfig.defaults).isEmpty)
  }

  @Test func unknownActionIsAnError() {
    let issues = validator.validate(Binding(zone: .edge(.top), gesture: .tap, action: "nope.nothing"))
    #expect(issues.map(\.code) == [.unknownAction])
    #expect(issues.first?.severity == .error)
    #expect(issues.first?.action == "nope.nothing")
  }

  @Test func shapeMismatchBothWays() {
    #expect(codes(Binding(zone: .edge(.left), gesture: .tap, action: "audio.volume")) == [.shapeMismatch])
    #expect(codes(Binding(zone: .edge(.left), gesture: .slide, action: "audio.mute")) == [.shapeMismatch])
    #expect(codes(Binding(zone: .edge(.left), gesture: .slide, action: "audio.volume")).isEmpty)
  }

  @Test func gestureTheZoneCantProduce() {
    #expect(codes(Binding(zone: .corner(.topLeft), gesture: .slide, action: "audio.volume")) == [.gestureNotSupported])
    #expect(codes(Binding(zone: .edge(.left), gesture: .swipe(.left), action: "media.next")) == [.gestureNotSupported])
    #expect(codes(Binding(zone: .edge(.left), gesture: .swipe(.up), action: "media.next")).isEmpty)
  }

  @Test func segmentOutOfRange() {
    #expect(
      codes(Binding(zone: .edge(.top, segment: 0, segments: 5), gesture: .tap, action: "media.next")) == [
        .segmentOutOfRange
      ])
    #expect(
      codes(Binding(zone: .edge(.top, segment: 2, segments: 2), gesture: .tap, action: "media.next")) == [
        .segmentOutOfRange
      ])
    #expect(
      codes(Binding(zone: .edge(.top, segment: -1, segments: 2), gesture: .tap, action: "media.next")) == [
        .segmentOutOfRange
      ])
    #expect(
      codes(Binding(zone: .edge(.top, segment: 0, segments: 0), gesture: .tap, action: "media.next")) == [
        .segmentOutOfRange
      ])
    #expect(codes(Binding(zone: .edge(.top, segment: 3, segments: 4), gesture: .tap, action: "media.next")).isEmpty)
  }

  @Test func missingRequiredParameter() {
    let issues = validator.validate(Binding(zone: .corner(.topLeft), gesture: .tap, action: "fake.press"))
    #expect(issues.map(\.code) == [.missingParameter])
    #expect(issues.first?.parameter == "keys")
    #expect(
      codes(Binding(zone: .corner(.topLeft), gesture: .tap, action: "fake.press", parameters: ["keys": " "])) == [
        .missingParameter
      ])
    #expect(
      codes(Binding(zone: .corner(.topLeft), gesture: .tap, action: "fake.press", parameters: ["keys": "cmd+shift+4"]))
        .isEmpty)
  }

  @Test func parameterKindChecks() {
    let cases: [(String, String, ValidationIssue.Code?)] = [
      ("combo", "cmd+shift+4", nil), ("combo", "cmd+banana", .invalidKeyCombo), ("combo", "cmd+", .invalidKeyCombo),
      ("link", "https://example.com", nil), ("link", "mailto:a@b.c", nil), ("link", "example.com", .invalidURL),
      ("count", "3", nil), ("count", "2.5", nil), ("count", "lots", .notANumber), ("count", "11", .numberOutOfRange),
      ("count", "0", .numberOutOfRange), ("mode", "fast", nil), ("mode", "medium", .invalidChoice),
      ("app", "com.example.app", nil), ("app", "example", .invalidBundleID), ("app", "com..x", .invalidBundleID),
      ("path", "/Applications", nil), ("path", "~/Documents", nil), ("path", "~", nil),
      ("path", "Documents/x", .invalidFilePath), ("note", "anything at all", nil),
    ]
    for (key, value, expected) in cases {
      let found = codes(everything(key, value))
      #expect(found == (expected.map { [$0] } ?? []), "\(key)=\(value)")
    }
  }

  @Test func unknownParameterIsAWarningButHapticsAndSensitivityAreKnown() {
    let issues = validator.validate(
      Binding(
        zone: .edge(.right), gesture: .slide, action: "audio.volume",
        parameters: ["haptics": "off", "sensitivity": "2", "color": "blue"]))
    #expect(issues.map(\.code) == [.unknownParameter])
    #expect(issues.first?.severity == .warning)
    #expect(issues.first?.parameter == "color")
  }

  @Test func duplicateSlotInOneProfileIsAnError() {
    var config = EdgyConfig.defaults
    config.defaultProfile.bindings.append(Binding(zone: .edge(.right), gesture: .slide, action: "display.brightness"))
    let issues = validator.validate(config)
    #expect(issues.map(\.code) == [.duplicateBinding])
    #expect(issues.first?.severity == .error)
    #expect(issues.first?.profile == .default)
  }

  @Test func overlappingZonesOnOneEdgeWarn() {
    var config = EdgyConfig.defaults
    config.defaultProfile.bindings.append(
      Binding(zone: .edge(.right, segment: 1, segments: 2), gesture: .slide, action: "display.brightness"))
    let issues = validator.validate(config)
    #expect(issues.map(\.code) == [.overlappingZones])
    #expect(issues.first?.severity == .warning)

    let half0 = Binding(zone: .edge(.top, segment: 0, segments: 2), gesture: .tap, action: "media.next")
    let half1 = Binding(zone: .edge(.top, segment: 1, segments: 2), gesture: .tap, action: "media.next")
    let third1 = Binding(zone: .edge(.top, segment: 1, segments: 3), gesture: .tap, action: "media.next")
    let doubleTap = Binding(zone: .edge(.top), gesture: .doubleTap, action: "media.next")
    #expect(!ConfigValidator.overlaps(half0, half1))
    #expect(ConfigValidator.overlaps(half0, third1))
    #expect(ConfigValidator.overlaps(half1, third1))
    #expect(!ConfigValidator.overlaps(half0, doubleTap))
  }

  @Test func appProfileKeyMustBeABundleID() {
    var config = EdgyConfig.defaults
    config.appProfiles["not a bundle"] = Profile(bindings: [])
    config.appProfiles["com.example.ok"] = Profile(bindings: [])
    #expect(validator.validate(config) == [ValidationIssue(.error, .invalidProfileID, profile: .app("not a bundle"))])
  }

  @Test func outOfRangeGestureSettingsWarn() {
    var config = EdgyConfig.defaults
    config.gestures.edgeWidthMM = 50
    config.gestures.fingers = 3
    config.gestures.dwellMS = .nan
    let issues = validator.validate(config)
    #expect(issues.allSatisfy { $0.code == .settingOutOfRange && $0.severity == .warning })
    #expect(Set(issues.compactMap(\.parameter)) == ["edgeWidthMM", "fingers", "dwellMS"])
  }

  @Test func clampingKeepsEveryValueInRange() {
    var wild = GestureSettings.defaults
    wild.edgeWidthMM = 100
    wild.cornerSizeMM = -4
    wild.dwellMS = .infinity
    wild.longPressMS = 10
    wild.fingers = 0
    let clamped = GestureSettingsLimits.clamped(wild)
    #expect(clamped.edgeWidthMM == 20)
    #expect(clamped.cornerSizeMM == 5)
    #expect(clamped.dwellMS == GestureSettings.defaults.dwellMS)
    #expect(clamped.longPressMS == 250)
    #expect(clamped.fingers == 1)
    #expect(GestureSettingsLimits.outOfRange(clamped).isEmpty)
    #expect(GestureSettingsLimits.clamped(.defaults) == .defaults)
  }

  /// One config that trips every code, so a new code can't ship without a test reaching it.
  @Test func everyCodeIsReachable() {
    var config = EdgyConfig.defaults
    config.gestures.longPressMS = 5000
    config.defaultProfile.bindings += [
      Binding(zone: .edge(.top), gesture: .tap, action: "nope.nothing"),
      Binding(zone: .edge(.top), gesture: .doubleTap, action: "audio.volume"),
      Binding(zone: .corner(.bottomLeft), gesture: .slide, action: "audio.volume"),
      Binding(zone: .edge(.top, segment: 4, segments: 4), gesture: .longPress, action: "media.next"),
      Binding(zone: .corner(.bottomRight), gesture: .tap, action: "fake.press"),
      Binding(zone: .edge(.right), gesture: .slide, action: "audio.volume"),
      Binding(zone: .edge(.right, segment: 0, segments: 3), gesture: .slide, action: "audio.volume"),
    ]
    let bad: [(String, String)] = [
      ("combo", "x+y"), ("link", "nowhere"), ("count", "x"), ("count", "99"), ("mode", "z"), ("app", "x"),
      ("path", "rel"), ("extra", "1"),
    ]
    for (index, (key, value)) in bad.enumerated() {
      config.defaultProfile.bindings.append(
        Binding(
          zone: .edge(.bottom, segment: index % 4, segments: 4), gesture: index < 4 ? .tap : .longPress,
          action: "fake.everything", parameters: [key: value]))
    }
    config.appProfiles["bad id"] = Profile(bindings: [])
    // On a Mac where one bound action (the defaults' next-track swipe) can't work.
    let onThisMac = ConfigValidator(
      catalog: FakeCatalog.descriptors, availability: ["media.next": .unavailable(reason: "test")])
    let found = Set(onThisMac.validate(config).map(\.code))
    #expect(found == Set(ValidationIssue.Code.allCases))
  }
}
