import Testing

@testable import TouchKit

@Test func moduleLinks() {
  #expect(TouchKitInfo.module == "TouchKit")
}
