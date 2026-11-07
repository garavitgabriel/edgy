import Testing

@testable import Displays

@Test func placeholderReportsNoDisplays() {
  #expect(UnavailableDisplayBrightness().displays().isEmpty)
}
