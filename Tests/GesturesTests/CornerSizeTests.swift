import EdgyCore
import Testing

@testable import Gestures

// The corner square follows `GestureSettings.cornerSizeMM`; tests pin it through
// `GestureSettings.test` so the shipped default can change without moving them.

/// 6 mm from the right side (inside the 8 mm edge strip) and 10.5 mm from the top: inside a 12 mm
/// corner square, outside a 10 mm one.
private let boundaryTap = TraceBuilder([Stroke(id: 1, [(0, 144, 84.5), (0.08, 144, 84.5)])])
private let zones: Set<Zone> = [.corner(.topRight), .edge(.right)]

@Test func tapTenAndAHalfMillimetresFromTheTopIsACornerTapWithTwelveMillimetreCorners() {
  let run = replay(boundaryTap.frames(), zones: zones, settings: .test(cornerSizeMM: 12))
  #expect(run.events.map(\.zone) == [.corner(.topRight)])
  #expect(run.events.map(\.kind) == [.tap])
}

@Test func tapTenAndAHalfMillimetresFromTheTopIsAnEdgeTapWithTenMillimetreCorners() {
  let run = replay(boundaryTap.frames(), zones: zones, settings: .test(cornerSizeMM: 10))
  #expect(run.events.map(\.zone) == [.edge(.right)])
  #expect(run.events.map(\.kind) == [.tap])
}

@Test func testSettingsMatchTheShippedDefaultsApartFromCornerSize() {
  // Pinning the corner must not let the other test settings drift from what ships.
  var shipped = GestureSettings.defaults
  shipped.cornerSizeMM = GestureSettings.test.cornerSizeMM
  #expect(shipped == GestureSettings.test)
}
