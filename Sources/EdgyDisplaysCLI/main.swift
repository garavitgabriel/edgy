import Displays

// Owned by the displays batch: list / get / set / nudge for scripts/smoke-displays.sh.
let control = makeLiveDisplayBrightness()
for display in control.displays() {
  print(
    display.id, display.kind.rawValue, display.name,
    display.brightnessControllable ? "controllable" : (display.reason ?? "not controllable"))
}
