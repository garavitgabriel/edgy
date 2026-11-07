import EdgyCore
import Testing

@testable import Gestures

private let size = Size2D(width: 160, height: 100)
private let settings = GestureSettings(
  edgeWidthMM: 8, cornerSizeMM: 10, dwellMS: 120, palmMajorAxisMM: 18, typingSuppressionMS: 500,
  doubleTapWindowMS: 300, longPressMS: 500, fingers: 1)

@Test func padLayoutRectsMatchTheRecognizerGeometry() {
  let layout = PadLayout(sensorSizeMM: size, settings: settings)
  #expect(layout.rect(for: .corner(.topRight)) == PadRect(x: 150, y: 90, width: 10, height: 10))
  #expect(layout.rect(for: .edge(.right)) == PadRect(x: 152, y: 0, width: 8, height: 100))
  #expect(layout.rect(for: .edge(.bottom, segment: 1, segments: 2)) == PadRect(x: 80, y: 0, width: 80, height: 8))
  #expect(layout.rect(for: .edge(.left, segment: 2, segments: 4)) == PadRect(x: 0, y: 50, width: 8, height: 25))
}

@Test func padLayoutHitTestingAgreesWithThePipeline() {
  let layout = PadLayout(sensorSizeMM: size, settings: settings)
  let mapped: Set<Zone> = [.edge(.right), .corner(.bottomLeft)]
  #expect(layout.zone(atMM: Point2D(x: 155, y: 50), mapped: mapped) == .edge(.right))
  #expect(layout.zone(atMM: Point2D(x: 3, y: 3), mapped: mapped) == .corner(.bottomLeft))
  // An unmapped corner passes through to the mapped edge it overlaps.
  #expect(layout.zone(atMM: Point2D(x: 156, y: 96), mapped: mapped) == .edge(.right))
  #expect(layout.zone(atMM: Point2D(x: 80, y: 50), mapped: mapped) == nil)
}
