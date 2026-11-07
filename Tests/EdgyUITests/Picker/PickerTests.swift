import CoreGraphics
import EdgyCore
import EdgyRuntime
import Foundation
import Testing

@testable import EdgyUI

@MainActor @Suite struct PickerCatalogTests {
  private func catalog(
    _ gesture: GestureKind, query: String = "", appTab: Bool = false, model: SettingsModel? = nil
  ) -> PickerCatalog {
    let model = model ?? InspectorFixtures.model()
    return PickerCatalog(
      groups: model.editor.catalogByCategory, gesture: gesture, query: query, isAppTab: appTab,
      availability: model.editor.availability(of:))
  }

  @Test func groupsComeInCatalogOrder() {
    let order = catalog(.tap).sections.map(\.title)
    let full = ["Sound", "Display", "Media", "System", "Windows", "Apps", "Keyboard", "Shortcuts"]
    #expect(order == full.filter(order.contains))
    #expect(order.first == "Sound" && order.last == "Shortcuts")
    #expect(catalog(.tap).sections.flatMap(\.items).allSatisfy { $0.id != .doNothing })
  }

  @Test func shapesThatDontFitCollapseIntoOneDisclosure() {
    let tap = catalog(.tap)
    #expect(tap.others.allSatisfy { $0.descriptor.shape != .trigger })
    #expect(tap.sections.flatMap(\.items).allSatisfy { $0.descriptor.shape == .trigger })
    #expect(tap.othersTitle == "\(tap.others.count) more need a slide or long-press")
    let slide = catalog(.slide)
    #expect(slide.othersTitle == "\(slide.others.count) more need a tap, swipe or long-press")
    let hold = catalog(.longPress)
    #expect(hold.othersTitle == "\(hold.others.count) more need a slide")
    #expect(hold.sections.flatMap(\.items).contains { $0.id == "keyboard.hold" })
  }

  @Test func searchFiltersGroupsAndTheDisclosure() {
    let found = catalog(.tap, query: "keyboard")
    #expect(Set(found.sections.flatMap(\.items).map(\.title)) == ["Keyboard Backlight On/Off", "Keyboard Shortcut…"])
    #expect(found.others.map(\.title) == ["Keyboard Brightness"])
    #expect(found.othersTitle == "1 more needs a slide")
    #expect(catalog(.tap, query: "zzz").sections.isEmpty)
  }

  @Test func unavailableStaysInItsGroupDimmedWithItsReason() {
    let item = catalog(.tap).sections.flatMap(\.items).first { $0.id == "keyboard.backlightToggle" }
    #expect(item?.isDimmed == true)
    #expect(item?.subtitle == InspectorFixtures.backlitReason)
    let limited = catalog(.tap).sections.flatMap(\.items).first { $0.id == "spaces.left" }
    #expect(limited?.isDimmed == false && limited?.subtitle == InspectorFixtures.spaceNote)
  }

  @Test func parametersEndInAnEllipsisAndDoNothingIsAppTabOnly() {
    let titles = catalog(.tap).sections.flatMap(\.items).map(\.title)
    #expect(titles.contains("Open App…") && titles.contains("Keyboard Shortcut…") && titles.contains("Mute"))
    #expect(catalog(.tap).offersDoNothing == false)
    #expect(catalog(.tap, appTab: true).offersDoNothing)
  }
}

@Suite struct PickerPlacementTests {
  // A 864 × 621 pad at (40, 60) in a 1200 × 760 window; 43 pt strips.
  let pad = CGRect(x: 40, y: 60, width: 864, height: 621)
  var bottom: CGRect { CGRect(x: pad.minX + 54, y: pad.maxY - 43, width: pad.width - 108, height: 43) }
  var right: CGRect { CGRect(x: pad.maxX - 43, y: pad.minY + 54, width: 43, height: pad.height - 108) }
  var left: CGRect { CGRect(x: pad.minX, y: pad.minY + 54, width: 43, height: pad.height - 108) }
  let window = CGRect(x: 0, y: 0, width: 1200, height: 760)

  @Test func heightIsCappedByTheMirror() {
    #expect(PickerPlacement.height(mirrorHeight: 370) == 354)
    #expect(PickerPlacement.height(mirrorHeight: 900) == 420)
    #expect(PickerPlacement.height(mirrorHeight: nil) == 420)
    #expect(PickerPlacement.width <= PickerPlacement.maxWidth)
  }

  var top: CGRect { CGRect(x: pad.minX + 54, y: pad.minY, width: pad.width - 108, height: 43) }

  @Test func aBottomBarOpensUpwardWithoutCoveringAnyOtherBar() {
    let size = CGSize(width: 320, height: PickerPlacement.height(mirrorHeight: pad.height))
    let result = PickerPlacement.place(
      anchor: bottom, zone: .edge(.bottom), avoiding: [left, right, top], size: size, in: window)
    #expect(result.side == .above)
    #expect(!result.frame.intersects(bottom))
    #expect(!result.frame.intersects(left) && !result.frame.intersects(right))
    #expect(!result.frame.intersects(top))  // shrinks below the cap rather than cover the opposite bar
    #expect(result.frame.height <= size.height && result.frame.height >= PickerPlacement.minHeight)
  }

  /// A to-scale external pad at 3.7 pt/mm (592 × 425, 30 pt strips): mirror − 16 is taller than the
  /// interior, so the picker shortens to sit between the bars.
  @Test func onAShortPadThePickerShrinksBetweenTheBars() {
    let pad = CGRect(x: 60, y: 60, width: 592, height: 425)
    let bar: CGFloat = 30
    let bottom = CGRect(x: pad.minX + 37, y: pad.maxY - bar, width: pad.width - 74, height: bar)
    let top = CGRect(x: pad.minX + 37, y: pad.minY, width: pad.width - 74, height: bar)
    let left = CGRect(x: pad.minX, y: pad.minY + 37, width: bar, height: pad.height - 74)
    let right = CGRect(x: pad.maxX - bar, y: pad.minY + 37, width: bar, height: pad.height - 74)
    let size = CGSize(width: 320, height: PickerPlacement.height(mirrorHeight: pad.height))
    let result = PickerPlacement.place(
      anchor: bottom, zone: .edge(.bottom), avoiding: [top, left, right], size: size, in: window)
    #expect(result.side == .above)
    #expect(result.frame.height < size.height)
    for zone in [bottom, top, left, right] { #expect(!result.frame.intersects(zone)) }
    #expect(window.contains(result.frame))
    #expect(abs(result.frame.minX + result.arrowOffset - bottom.midX) < 1)
  }

  @Test func aRightStripOpensToItsLeft() {
    let size = CGSize(width: 320, height: 420)
    let result = PickerPlacement.place(
      anchor: right, zone: .edge(.right), avoiding: [bottom, left, top], size: size, in: window)
    #expect(result.side == .left)
    #expect(!result.frame.intersects(right))
    #expect(!result.frame.intersects(top) && !result.frame.intersects(bottom))
    #expect(window.contains(result.frame))
  }

  @Test func itNeverLeavesTheWindow() {
    let corner = CGRect(x: 1140, y: 20, width: 54, height: 54)
    let result = PickerPlacement.place(
      anchor: corner, zone: .corner(.topRight), avoiding: [], size: CGSize(width: 320, height: 420), in: window)
    #expect(window.insetBy(dx: PickerPlacement.margin - 0.5, dy: PickerPlacement.margin - 0.5).contains(result.frame))
    #expect(!result.frame.intersects(corner))
  }
}
