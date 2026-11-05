import AppKit

// Menu-bar app entry point. Accessory policy keeps Edgy out of the Dock even when run unbundled
// (`swift run Edgy`); the bundled app also sets LSUIElement.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
