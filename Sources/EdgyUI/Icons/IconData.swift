// Transcribed from `docs/design/assets/icons/*.svg` (design supplement 2, artboards S11 and S12).
// Every element is copied verbatim from its SVG: path data strings as-is, rect and circle attributes as
// numbers. `IconTranscriptionTests` re-reads each SVG and fails if anything here drifts from it.
// Regenerate from the SVGs; never edit a drawing by hand.

import CoreGraphics

extension IconDrawing {
  /// Every exported drawing, keyed by SVG file name (without `.svg`).
  static let all: [String: IconDrawing] = [
    "app-open": IconDrawing(
      width: 16, height: 16,
      elements: [
        .rect(x: 2.5, y: 2.5, width: 11, height: 11, rx: 3.2, fill: false, stroke: 1.5)
      ]),
    "apps-switcher": IconDrawing(
      width: 16, height: 16,
      elements: [
        .rect(x: 1.75, y: 1.75, width: 8.5, height: 8.5, rx: 2.4, fill: false, stroke: 1.5),
        .rect(x: 5.75, y: 5.75, width: 8.5, height: 8.5, rx: 2.4, fill: false, stroke: 1.5),
      ]),
    "audio-mute": IconDrawing(
      width: 16, height: 16,
      elements: [
        .path("M2.2 6 H4.8 L8.6 2.8 V13.2 L4.8 10 H2.2 Z", fill: false, stroke: 1.5),
        .path("M11.2 6 A2.8 2.8 0 0 1 11.2 10", fill: false, stroke: 1.5),
        .path("M2.4 2.4 L13.6 13.6", fill: false, stroke: 1.5),
      ]),
    "audio-volume": IconDrawing(
      width: 16, height: 16,
      elements: [
        .path("M2.2 6 H4.8 L8.6 2.8 V13.2 L4.8 10 H2.2 Z", fill: false, stroke: 1.5),
        .path("M11 6 A2.8 2.8 0 0 1 11 10 M12.8 4 A5.4 5.4 0 0 1 12.8 12", fill: false, stroke: 1.5),
      ]),
    "display-brightness": IconDrawing(
      width: 16, height: 16,
      elements: [
        .circle(cx: 8, cy: 8, r: 2.8, fill: false, stroke: 1.5),
        .path(
          "M12.90 8.00 L14.40 8.00 M11.46 11.46 L12.53 12.53 M8.00 12.90 L8.00 14.40 M4.54 11.46 L3.47 12.53 M3.10 8.00 L1.60 8.00 M4.54 4.54 L3.47 3.47 M8.00 3.10 L8.00 1.60 M11.46 4.54 L12.53 3.47",
          fill: false, stroke: 1.5),
      ]),
    "edgy-none": IconDrawing(
      width: 16, height: 16,
      elements: [
        .circle(cx: 8, cy: 8, r: 6, fill: false, stroke: 1.5),
        .path("M3.9 12.1 L12.1 3.9", fill: false, stroke: 1.5),
      ]),
    "file-open": IconDrawing(
      width: 16, height: 16,
      elements: [
        .path(
          "M1.8 4.2 A1.2 1.2 0 0 1 3 3 H6.2 L7.6 4.6 H13 A1.2 1.2 0 0 1 14.2 5.8 V12 A1.2 1.2 0 0 1 13 13.2 H3 A1.2 1.2 0 0 1 1.8 12 Z",
          fill: false, stroke: 1.5)
      ]),
    "keyboard-backlight": IconDrawing(
      width: 16, height: 16,
      elements: [
        .rect(x: 1.75, y: 7.25, width: 12.5, height: 6.5, rx: 1.8, fill: false, stroke: 1.5),
        .path("M4.4 10.5 H5 M7.7 10.5 H8.3 M11 10.5 H11.6", fill: false, stroke: 1.5),
        .path("M8 1.6 V3.8 M4.1 2.6 L5.1 4.4 M11.9 2.6 L10.9 4.4", fill: false, stroke: 1.5),
      ]),
    "keyboard-backlight-toggle": IconDrawing(
      width: 16, height: 16,
      elements: [
        .rect(x: 1.75, y: 7.25, width: 12.5, height: 6.5, rx: 1.8, fill: false, stroke: 1.5),
        .path("M4.4 10.5 H5 M7.7 10.5 H8.3 M11 10.5 H11.6", fill: false, stroke: 1.5),
        .path("M8 1.6 V3.8 M4.1 2.6 L5.1 4.4 M11.9 2.6 L10.9 4.4", fill: false, stroke: 1.5),
      ]),
    "keyboard-hold": IconDrawing(
      width: 16, height: 16,
      elements: [
        .rect(x: 3, y: 7.2, width: 10, height: 4.8, rx: 1.8, fill: false, stroke: 1.5),
        .path("M1.8 14 H14.2 M8 1.4 V4.6 M6.2 3 L8 4.8 L9.8 3", fill: false, stroke: 1.5),
      ]),
    "keyboard-shortcut": IconDrawing(
      width: 16, height: 16,
      elements: [
        .rect(x: 2, y: 2.5, width: 12, height: 11, rx: 2.6, fill: false, stroke: 1.5),
        .rect(x: 4.6, y: 4.6, width: 6.8, height: 5, rx: 1.2, fill: false, stroke: 1.5),
      ]),
    "keyboard-slide-steps": IconDrawing(
      width: 16, height: 16,
      elements: [
        .rect(x: 3, y: 4.5, width: 10, height: 7, rx: 2.2, fill: false, stroke: 1.5),
        .path("M6.4 2.4 L8 1 L9.6 2.4 M6.4 13.6 L8 15 L9.6 13.6", fill: false, stroke: 1.5),
      ]),
    "media-next": IconDrawing(
      width: 16, height: 16,
      elements: [
        .path("M2.6 3.4 L9.6 8 L2.6 12.6 Z", fill: false, stroke: 1.5),
        .path("M13 3.4 V12.6", fill: false, stroke: 1.5),
      ]),
    "media-play-pause": IconDrawing(
      width: 16, height: 16,
      elements: [
        .path("M2.4 3.6 L8.2 8 L2.4 12.4 Z", fill: false, stroke: 1.5),
        .path("M11 3.6 V12.4 M14 3.6 V12.4", fill: false, stroke: 1.5),
      ]),
    "media-previous": IconDrawing(
      width: 16, height: 16,
      elements: [
        .path("M13.4 3.4 L6.4 8 L13.4 12.6 Z", fill: false, stroke: 1.5),
        .path("M3 3.4 V12.6", fill: false, stroke: 1.5),
      ]),
    "mic-mute": IconDrawing(
      width: 16, height: 16,
      elements: [
        .rect(x: 6, y: 1.8, width: 4, height: 7.4, rx: 2, fill: false, stroke: 1.5),
        .path("M3.9 7.6 A4.1 4.1 0 0 0 12.1 7.6 M8 11.7 V14 M5.8 14 H10.2", fill: false, stroke: 1.5),
        .path("M2.6 2.4 L13.4 13.6", fill: false, stroke: 1.5),
      ]),
    "shortcut-run": IconDrawing(
      width: 16, height: 16,
      elements: [
        .rect(x: 1.75, y: 9.85, width: 6.6, height: 4.4, rx: 1.4, fill: false, stroke: 1.5),
        .rect(x: 4.7, y: 5.8, width: 6.6, height: 4.4, rx: 1.4, fill: false, stroke: 1.5),
        .rect(x: 7.65, y: 1.75, width: 6.6, height: 4.4, rx: 1.4, fill: false, stroke: 1.5),
      ]),
    "spaces-left": IconDrawing(
      width: 16, height: 16,
      elements: [
        .rect(x: 1.75, y: 2.5, width: 12.5, height: 9, rx: 1.8, fill: false, stroke: 1.5),
        .path("M6 14 H10", fill: false, stroke: 1.5),
        .path("M10.6 7 H5.4 M7.4 5 L5.4 7 L7.4 9", fill: false, stroke: 1.5),
      ]),
    "spaces-right": IconDrawing(
      width: 16, height: 16,
      elements: [
        .rect(x: 1.75, y: 2.5, width: 12.5, height: 9, rx: 1.8, fill: false, stroke: 1.5),
        .path("M6 14 H10", fill: false, stroke: 1.5),
        .path("M5.4 7 H10.6 M8.6 5 L10.6 7 L8.6 9", fill: false, stroke: 1.5),
      ]),
    "split-horizontal-1": IconDrawing(
      width: 40, height: 12,
      elements: [
        .rect(x: 0.5, y: 0.5, width: 39, height: 11, rx: 5.5, fill: false, stroke: 1)
      ]),
    "split-horizontal-1-selected": IconDrawing(
      width: 40, height: 12,
      elements: [
        .rect(x: 0, y: 0, width: 40, height: 12, rx: 6, fill: true, stroke: 0)
      ]),
    "split-horizontal-2": IconDrawing(
      width: 40, height: 12,
      elements: [
        .rect(x: 0.5, y: 0.5, width: 18, height: 11, rx: 5.5, fill: false, stroke: 1),
        .rect(x: 21.5, y: 0.5, width: 18, height: 11, rx: 5.5, fill: false, stroke: 1),
      ]),
    "split-horizontal-2-selected": IconDrawing(
      width: 40, height: 12,
      elements: [
        .rect(x: 0, y: 0, width: 19, height: 12, rx: 6, fill: true, stroke: 0),
        .rect(x: 21, y: 0, width: 19, height: 12, rx: 6, fill: true, stroke: 0),
      ]),
    "split-horizontal-3": IconDrawing(
      width: 40, height: 12,
      elements: [
        .rect(x: 0.5, y: 0.5, width: 11, height: 11, rx: 5.5, fill: false, stroke: 1),
        .rect(x: 14.5, y: 0.5, width: 11, height: 11, rx: 5.5, fill: false, stroke: 1),
        .rect(x: 28.5, y: 0.5, width: 11, height: 11, rx: 5.5, fill: false, stroke: 1),
      ]),
    "split-horizontal-3-selected": IconDrawing(
      width: 40, height: 12,
      elements: [
        .rect(x: 0, y: 0, width: 12, height: 12, rx: 6, fill: true, stroke: 0),
        .rect(x: 14, y: 0, width: 12, height: 12, rx: 6, fill: true, stroke: 0),
        .rect(x: 28, y: 0, width: 12, height: 12, rx: 6, fill: true, stroke: 0),
      ]),
    "split-horizontal-4": IconDrawing(
      width: 40, height: 12,
      elements: [
        .rect(x: 0.5, y: 0.5, width: 7.5, height: 11, rx: 3.75, fill: false, stroke: 1),
        .rect(x: 11, y: 0.5, width: 7.5, height: 11, rx: 3.75, fill: false, stroke: 1),
        .rect(x: 21.5, y: 0.5, width: 7.5, height: 11, rx: 3.75, fill: false, stroke: 1),
        .rect(x: 32, y: 0.5, width: 7.5, height: 11, rx: 3.75, fill: false, stroke: 1),
      ]),
    "split-horizontal-4-selected": IconDrawing(
      width: 40, height: 12,
      elements: [
        .rect(x: 0, y: 0, width: 8.5, height: 12, rx: 4.25, fill: true, stroke: 0),
        .rect(x: 10.5, y: 0, width: 8.5, height: 12, rx: 4.25, fill: true, stroke: 0),
        .rect(x: 21, y: 0, width: 8.5, height: 12, rx: 4.25, fill: true, stroke: 0),
        .rect(x: 31.5, y: 0, width: 8.5, height: 12, rx: 4.25, fill: true, stroke: 0),
      ]),
    "split-vertical-1": IconDrawing(
      width: 12, height: 40,
      elements: [
        .rect(x: 0.5, y: 0.5, width: 11, height: 39, rx: 5.5, fill: false, stroke: 1)
      ]),
    "split-vertical-1-selected": IconDrawing(
      width: 12, height: 40,
      elements: [
        .rect(x: 0, y: 0, width: 12, height: 40, rx: 6, fill: true, stroke: 0)
      ]),
    "split-vertical-2": IconDrawing(
      width: 12, height: 40,
      elements: [
        .rect(x: 0.5, y: 0.5, width: 11, height: 18, rx: 5.5, fill: false, stroke: 1),
        .rect(x: 0.5, y: 21.5, width: 11, height: 18, rx: 5.5, fill: false, stroke: 1),
      ]),
    "split-vertical-2-selected": IconDrawing(
      width: 12, height: 40,
      elements: [
        .rect(x: 0, y: 0, width: 12, height: 19, rx: 6, fill: true, stroke: 0),
        .rect(x: 0, y: 21, width: 12, height: 19, rx: 6, fill: true, stroke: 0),
      ]),
    "split-vertical-3": IconDrawing(
      width: 12, height: 40,
      elements: [
        .rect(x: 0.5, y: 0.5, width: 11, height: 11, rx: 5.5, fill: false, stroke: 1),
        .rect(x: 0.5, y: 14.5, width: 11, height: 11, rx: 5.5, fill: false, stroke: 1),
        .rect(x: 0.5, y: 28.5, width: 11, height: 11, rx: 5.5, fill: false, stroke: 1),
      ]),
    "split-vertical-3-selected": IconDrawing(
      width: 12, height: 40,
      elements: [
        .rect(x: 0, y: 0, width: 12, height: 12, rx: 6, fill: true, stroke: 0),
        .rect(x: 0, y: 14, width: 12, height: 12, rx: 6, fill: true, stroke: 0),
        .rect(x: 0, y: 28, width: 12, height: 12, rx: 6, fill: true, stroke: 0),
      ]),
    "split-vertical-4": IconDrawing(
      width: 12, height: 40,
      elements: [
        .rect(x: 0.5, y: 0.5, width: 11, height: 7.5, rx: 3.75, fill: false, stroke: 1),
        .rect(x: 0.5, y: 11, width: 11, height: 7.5, rx: 3.75, fill: false, stroke: 1),
        .rect(x: 0.5, y: 21.5, width: 11, height: 7.5, rx: 3.75, fill: false, stroke: 1),
        .rect(x: 0.5, y: 32, width: 11, height: 7.5, rx: 3.75, fill: false, stroke: 1),
      ]),
    "split-vertical-4-selected": IconDrawing(
      width: 12, height: 40,
      elements: [
        .rect(x: 0, y: 0, width: 12, height: 8.5, rx: 4.25, fill: true, stroke: 0),
        .rect(x: 0, y: 10.5, width: 12, height: 8.5, rx: 4.25, fill: true, stroke: 0),
        .rect(x: 0, y: 21, width: 12, height: 8.5, rx: 4.25, fill: true, stroke: 0),
        .rect(x: 0, y: 31.5, width: 12, height: 8.5, rx: 4.25, fill: true, stroke: 0),
      ]),
    "system-app-windows": IconDrawing(
      width: 16, height: 16,
      elements: [
        .rect(x: 1.75, y: 5.75, width: 9.5, height: 8, rx: 1.6, fill: false, stroke: 1.5),
        .path("M4.6 3 H12.6 A1.6 1.6 0 0 1 14.2 4.6 V10.8", fill: false, stroke: 1.5),
      ]),
    "system-dictation": IconDrawing(
      width: 16, height: 16,
      elements: [
        .rect(x: 6, y: 1.8, width: 4, height: 7.4, rx: 2, fill: false, stroke: 1.5),
        .path("M3.9 7.6 A4.1 4.1 0 0 0 12.1 7.6 M8 11.7 V14", fill: false, stroke: 1.5),
        .path("M1.4 5.6 V8.4 M14.6 5.6 V8.4", fill: false, stroke: 1.5),
      ]),
    "system-lock-screen": IconDrawing(
      width: 16, height: 16,
      elements: [
        .rect(x: 2.75, y: 7, width: 10.5, height: 7, rx: 1.8, fill: false, stroke: 1.5),
        .path("M5.2 7 V5 A2.8 2.8 0 0 1 10.8 5 V7", fill: false, stroke: 1.5),
      ]),
    "system-mission-control": IconDrawing(
      width: 16, height: 16,
      elements: [
        .rect(x: 1.9, y: 2.9, width: 5.4, height: 4.6, rx: 1.2, fill: false, stroke: 1.5),
        .rect(x: 1.9, y: 8.5, width: 5.4, height: 4.6, rx: 1.2, fill: false, stroke: 1.5),
        .rect(x: 8.7, y: 2.9, width: 5.4, height: 4.6, rx: 1.2, fill: false, stroke: 1.5),
        .rect(x: 8.7, y: 8.5, width: 5.4, height: 4.6, rx: 1.2, fill: false, stroke: 1.5),
      ]),
    "system-show-desktop": IconDrawing(
      width: 16, height: 16,
      elements: [
        .rect(x: 1.75, y: 2.5, width: 12.5, height: 9, rx: 1.8, fill: false, stroke: 1.5),
        .path("M6 14 H10", fill: false, stroke: 1.5),
        .rect(x: 2.9, y: 4.4, width: 2, height: 5.2, rx: 0.7, fill: true, stroke: 0),
        .rect(x: 11.1, y: 4.4, width: 2, height: 5.2, rx: 0.7, fill: true, stroke: 0),
      ]),
    "system-sleep-display": IconDrawing(
      width: 16, height: 16,
      elements: [
        .path("M13.2 9.8 A5.6 5.6 0 1 1 6.2 2.8 A4.4 4.4 0 0 0 13.2 9.8 Z", fill: false, stroke: 1.5)
      ]),
    "ui-advanced": IconDrawing(
      width: 16, height: 16,
      elements: [
        .path("M2 4 H8.2 M11.8 4 H14 M2 8 H3.2 M6.8 8 H14 M2 12 H9.2 M12.8 12 H14", fill: false, stroke: 1.5),
        .circle(cx: 10, cy: 4, r: 1.8, fill: false, stroke: 1.5),
        .circle(cx: 5, cy: 8, r: 1.8, fill: false, stroke: 1.5),
        .circle(cx: 11, cy: 12, r: 1.8, fill: false, stroke: 1.5),
      ]),
    "url-open": IconDrawing(
      width: 16, height: 16,
      elements: [
        .path("M6.4 9.6 L9.6 6.4", fill: false, stroke: 1.5),
        .path("M7.4 4.6 L8.6 3.4 A3 3 0 0 1 12.6 7.4 L11.4 8.6", fill: false, stroke: 1.5),
        .path("M8.6 11.4 L7.4 12.6 A3 3 0 0 1 3.4 8.6 L4.6 7.4", fill: false, stroke: 1.5),
      ]),
    "window-bottom-half": IconDrawing(
      width: 16, height: 16,
      elements: [
        .rect(x: 1.75, y: 2.75, width: 12.5, height: 10.5, rx: 2, fill: false, stroke: 1.5),
        .rect(x: 3.6, y: 8.4, width: 8.8, height: 3, rx: 0.8, fill: true, stroke: 0),
      ]),
    "window-center": IconDrawing(
      width: 16, height: 16,
      elements: [
        .rect(x: 1.75, y: 2.75, width: 12.5, height: 10.5, rx: 2, fill: false, stroke: 1.5),
        .rect(x: 5.6, y: 5.9, width: 4.8, height: 4.2, rx: 0.8, fill: true, stroke: 0),
      ]),
    "window-left-half": IconDrawing(
      width: 16, height: 16,
      elements: [
        .rect(x: 1.75, y: 2.75, width: 12.5, height: 10.5, rx: 2, fill: false, stroke: 1.5),
        .rect(x: 3.6, y: 4.6, width: 3.9, height: 6.8, rx: 0.8, fill: true, stroke: 0),
      ]),
    "window-maximize": IconDrawing(
      width: 16, height: 16,
      elements: [
        .rect(x: 1.75, y: 2.75, width: 12.5, height: 10.5, rx: 2, fill: false, stroke: 1.5),
        .rect(x: 3.6, y: 4.6, width: 8.8, height: 6.8, rx: 0.8, fill: true, stroke: 0),
      ]),
    "window-minimize": IconDrawing(
      width: 16, height: 16,
      elements: [
        .rect(x: 1.75, y: 2.75, width: 12.5, height: 10.5, rx: 2, fill: false, stroke: 1.5),
        .rect(x: 4.6, y: 9.8, width: 6.8, height: 1.6, rx: 0.8, fill: true, stroke: 0),
      ]),
    "window-restore": IconDrawing(
      width: 16, height: 16,
      elements: [
        .rect(x: 1.75, y: 2.75, width: 12.5, height: 10.5, rx: 2, fill: false, stroke: 1.5),
        .path("M11.4 5 V7.6 A1.6 1.6 0 0 1 9.8 9.2 H5 M6.8 7.4 L5 9.2 L6.8 11", fill: false, stroke: 1.5),
      ]),
    "window-right-half": IconDrawing(
      width: 16, height: 16,
      elements: [
        .rect(x: 1.75, y: 2.75, width: 12.5, height: 10.5, rx: 2, fill: false, stroke: 1.5),
        .rect(x: 8.5, y: 4.6, width: 3.9, height: 6.8, rx: 0.8, fill: true, stroke: 0),
      ]),
    "window-top-half": IconDrawing(
      width: 16, height: 16,
      elements: [
        .rect(x: 1.75, y: 2.75, width: 12.5, height: 10.5, rx: 2, fill: false, stroke: 1.5),
        .rect(x: 3.6, y: 4.6, width: 8.8, height: 3, rx: 0.8, fill: true, stroke: 0),
      ]),
  ]

  /// Action id → drawing file (the README table in `docs/design/assets/icons/`).
  static let fileForAction: [String: String] = [
    "app.open": "app-open",
    "apps.switcher": "apps-switcher",
    "audio.mute": "audio-mute",
    "audio.volume": "audio-volume",
    "display.brightness": "display-brightness",
    "edgy.none": "edgy-none",
    "file.open": "file-open",
    "keyboard.backlight": "keyboard-backlight",
    "keyboard.backlightToggle": "keyboard-backlight-toggle",
    "keyboard.hold": "keyboard-hold",
    "keyboard.shortcut": "keyboard-shortcut",
    "keyboard.slideSteps": "keyboard-slide-steps",
    "media.next": "media-next",
    "media.playPause": "media-play-pause",
    "media.previous": "media-previous",
    "mic.mute": "mic-mute",
    "shortcut.run": "shortcut-run",
    "spaces.left": "spaces-left",
    "spaces.right": "spaces-right",
    "system.appWindows": "system-app-windows",
    "system.dictation": "system-dictation",
    "system.lockScreen": "system-lock-screen",
    "system.missionControl": "system-mission-control",
    "system.showDesktop": "system-show-desktop",
    "system.sleepDisplay": "system-sleep-display",
    "url.open": "url-open",
    "window.bottomHalf": "window-bottom-half",
    "window.center": "window-center",
    "window.leftHalf": "window-left-half",
    "window.maximize": "window-maximize",
    "window.minimize": "window-minimize",
    "window.restore": "window-restore",
    "window.rightHalf": "window-right-half",
    "window.topHalf": "window-top-half",
  ]
}
