import EdgyCore

/// Action identifiers the registry knows.
public enum BuiltInAction {
  public static let volume: ActionID = "audio.volume"
  public static let mute: ActionID = "audio.mute"
  public static let brightness: ActionID = "display.brightness"
  public static let micMute: ActionID = "mic.mute"
  public static let playPause: ActionID = "media.playPause"
  public static let next: ActionID = "media.next"
  public static let previous: ActionID = "media.previous"
  public static let runShortcut: ActionID = "shortcut.run"

  public static let keyboardShortcut: ActionID = "keyboard.shortcut"
  public static let keyboardSlideSteps: ActionID = "keyboard.slideSteps"

  public static let openApp: ActionID = "app.open"
  public static let openURL: ActionID = "url.open"
  public static let openFile: ActionID = "file.open"

  public static let missionControl: ActionID = "system.missionControl"
  public static let appWindows: ActionID = "system.appWindows"
  public static let showDesktop: ActionID = "system.showDesktop"
  public static let spaceLeft: ActionID = "spaces.left"
  public static let spaceRight: ActionID = "spaces.right"
  public static let lockScreen: ActionID = "system.lockScreen"
  public static let sleepDisplay: ActionID = "system.sleepDisplay"

  public static let windowLeftHalf: ActionID = "window.leftHalf"
  public static let windowRightHalf: ActionID = "window.rightHalf"
  public static let windowTopHalf: ActionID = "window.topHalf"
  public static let windowBottomHalf: ActionID = "window.bottomHalf"
  public static let windowMaximize: ActionID = "window.maximize"
  public static let windowCenter: ActionID = "window.center"
  public static let windowMinimize: ActionID = "window.minimize"
  public static let windowRestore: ActionID = "window.restore"

  // v0.3
  public static let appSwitcher: ActionID = "apps.switcher"
  public static let keyboardHold: ActionID = "keyboard.hold"
  public static let dictation: ActionID = "system.dictation"
  public static let keyboardBacklight: ActionID = "keyboard.backlight"
  public static let keyboardBacklightToggle: ActionID = "keyboard.backlightToggle"
}

/// Parameter keys and values the built-in actions read from `Binding.parameters`.
public enum ActionParameterKey {
  public static let shortcutName = "name"
  public static let keys = "keys"
  public static let upKeys = "upKeys"
  public static let downKeys = "downKeys"
  public static let step = "step"
  public static let bundleID = "bundleID"
  public static let whenFrontmost = "whenFrontmost"
  public static let url = "url"
  public static let path = "path"

  /// `whenFrontmost` values for `app.open`.
  public static let frontmostStay = "stay"
  public static let frontmostHide = "hide"
}

enum ActionCatalog {
  static let stepRange: ClosedRange<Double> = 0.02...0.5
  static let defaultStep = 0.0625
  /// `apps.switcher`: slide travel per app.
  static let switcherStepRange: ClosedRange<Double> = 0.04...0.5
  static let defaultSwitcherStep = 0.1

  /// Every action, in the order the settings UI lists them within a category.
  static let all: [ActionDescriptor] = [
    // Sound, display, media, Shortcuts (v0.1).
    ActionDescriptor(id: BuiltInAction.volume, shape: .continuous, displayName: "Volume", category: .sound),
    ActionDescriptor(id: BuiltInAction.mute, shape: .trigger, displayName: "Mute", category: .sound),
    ActionDescriptor(
      id: BuiltInAction.brightness, shape: .continuous, displayName: "Brightness", category: .display),
    ActionDescriptor(id: BuiltInAction.micMute, shape: .trigger, displayName: "Microphone Mute", category: .sound),
    ActionDescriptor(id: BuiltInAction.playPause, shape: .trigger, displayName: "Play / Pause", category: .media),
    ActionDescriptor(id: BuiltInAction.next, shape: .trigger, displayName: "Next Track", category: .media),
    ActionDescriptor(id: BuiltInAction.previous, shape: .trigger, displayName: "Previous Track", category: .media),
    ActionDescriptor(
      id: BuiltInAction.runShortcut, shape: .trigger, displayName: "Run Shortcut", category: .shortcuts,
      parameters: [
        ActionParameter(
          key: ActionParameterKey.shortcutName, kind: .text, required: true, displayName: "Shortcut Name")
      ]),

    // Display, continued (v0.3): the built-in keyboard's backlight, through the private
    // brightness framework. Unavailable on Macs without a backlit keyboard.
    ActionDescriptor(
      id: BuiltInAction.keyboardBacklight, shape: .continuous, displayName: "Keyboard Brightness",
      category: .display),
    // Off, or back to the last non-zero level.
    ActionDescriptor(
      id: BuiltInAction.keyboardBacklightToggle, shape: .trigger, displayName: "Keyboard Backlight On / Off",
      category: .display),

    // Keyboard.
    ActionDescriptor(
      id: BuiltInAction.keyboardShortcut, shape: .trigger, displayName: "Keyboard Shortcut", category: .keyboard,
      parameters: [ActionParameter(key: ActionParameterKey.keys, kind: .keyCombo, required: true, displayName: "Keys")]
    ),
    // One key press per `step` of slide travel (scaled by the binding's sensitivity): toward
    // top/right presses `upKeys`, the other way `downKeys`.
    ActionDescriptor(
      id: BuiltInAction.keyboardSlideSteps, shape: .continuous, displayName: "Slide to Repeat Keys",
      category: .keyboard,
      parameters: [
        ActionParameter(
          key: ActionParameterKey.upKeys, kind: .keyCombo, required: true, displayName: "Up / Right Keys"),
        ActionParameter(
          key: ActionParameterKey.downKeys, kind: .keyCombo, required: true, displayName: "Down / Left Keys"),
        ActionParameter(
          key: ActionParameterKey.step, kind: .number(stepRange), required: false,
          defaultValue: String(defaultStep), displayName: "Step"),
      ]),
    // Holds the combo down for as long as the finger stays (long-press): the push-to-talk key a
    // dictation app asks the user to hold.
    ActionDescriptor(
      id: BuiltInAction.keyboardHold, shape: .hold, displayName: "Hold Keys", category: .keyboard,
      parameters: [ActionParameter(key: ActionParameterKey.keys, kind: .keyCombo, required: true, displayName: "Keys")]
    ),

    // Apps.
    ActionDescriptor(
      id: BuiltInAction.openApp, shape: .trigger, displayName: "Open App", category: .apps,
      parameters: [
        ActionParameter(key: ActionParameterKey.bundleID, kind: .appBundleID, required: true, displayName: "App"),
        ActionParameter(
          key: ActionParameterKey.whenFrontmost,
          kind: .choice([ActionParameterKey.frontmostStay, ActionParameterKey.frontmostHide]), required: false,
          defaultValue: ActionParameterKey.frontmostHide, displayName: "When Already in Front"),
      ]),
    ActionDescriptor(
      id: BuiltInAction.openURL, shape: .trigger, displayName: "Open URL", category: .apps,
      parameters: [ActionParameter(key: ActionParameterKey.url, kind: .url, required: true, displayName: "URL")]),
    ActionDescriptor(
      id: BuiltInAction.openFile, shape: .trigger, displayName: "Open File or Folder", category: .apps,
      parameters: [
        ActionParameter(key: ActionParameterKey.path, kind: .filePath, required: true, displayName: "File or Folder")
      ]),
    // The command-tab app switcher, driven by a slide: opens on the next app, one app per `step`
    // of travel (toward top/right = forward), selects on lift, cancels on a cancelled gesture.
    ActionDescriptor(
      id: BuiltInAction.appSwitcher, shape: .continuous, displayName: "Switch Apps", category: .apps,
      parameters: [
        ActionParameter(
          key: ActionParameterKey.step, kind: .number(switcherStepRange), required: false,
          defaultValue: String(defaultSwitcherStep), displayName: "Step")
      ]),

    // System. See `LiveSystemOutput` for how each one is done and why.
    ActionDescriptor(
      id: BuiltInAction.missionControl, shape: .trigger, displayName: "Mission Control", category: .system),
    // Windows of the frontmost app.
    ActionDescriptor(id: BuiltInAction.appWindows, shape: .trigger, displayName: "App Windows", category: .system),
    ActionDescriptor(id: BuiltInAction.showDesktop, shape: .trigger, displayName: "Show Desktop", category: .system),
    // Depends on a user-changeable system shortcut: posts ctrl+left ("Move left a space").
    // Does nothing if that shortcut is turned off or rebound in Keyboard Shortcuts settings.
    ActionDescriptor(
      id: BuiltInAction.spaceLeft, shape: .trigger, displayName: "Space Left", category: .system),
    // Depends on a user-changeable system shortcut: posts ctrl+right ("Move right a space").
    ActionDescriptor(
      id: BuiltInAction.spaceRight, shape: .trigger, displayName: "Space Right", category: .system),
    // Depends on a user-changeable system shortcut: posts ctrl+cmd+q ("Lock Screen").
    ActionDescriptor(id: BuiltInAction.lockScreen, shape: .trigger, displayName: "Lock Screen", category: .system),
    ActionDescriptor(
      id: BuiltInAction.sleepDisplay, shape: .trigger, displayName: "Sleep Display", category: .system),
    // Starts / stops macOS Dictation. See `LiveDictationOutput` for what it depends on.
    ActionDescriptor(id: BuiltInAction.dictation, shape: .trigger, displayName: "Dictation", category: .system),

    // Windows (the frontmost app's focused window).
    ActionDescriptor(
      id: BuiltInAction.windowLeftHalf, shape: .trigger, displayName: "Left Half", category: .windows),
    ActionDescriptor(
      id: BuiltInAction.windowRightHalf, shape: .trigger, displayName: "Right Half", category: .windows),
    ActionDescriptor(id: BuiltInAction.windowTopHalf, shape: .trigger, displayName: "Top Half", category: .windows),
    ActionDescriptor(
      id: BuiltInAction.windowBottomHalf, shape: .trigger, displayName: "Bottom Half", category: .windows),
    ActionDescriptor(id: BuiltInAction.windowMaximize, shape: .trigger, displayName: "Maximize", category: .windows),
    ActionDescriptor(id: BuiltInAction.windowCenter, shape: .trigger, displayName: "Center", category: .windows),
    ActionDescriptor(id: BuiltInAction.windowMinimize, shape: .trigger, displayName: "Minimize", category: .windows),
    // Back to the frame the window had before Edgy last snapped it; no-op if it never did.
    ActionDescriptor(
      id: BuiltInAction.windowRestore, shape: .trigger, displayName: "Restore Window", category: .windows),
  ]

  static let systemCommands: [ActionID: SystemCommand] = [
    BuiltInAction.missionControl: .missionControl,
    BuiltInAction.appWindows: .appWindows,
    BuiltInAction.showDesktop: .showDesktop,
    BuiltInAction.spaceLeft: .spaceLeft,
    BuiltInAction.spaceRight: .spaceRight,
    BuiltInAction.lockScreen: .lockScreen,
    BuiltInAction.sleepDisplay: .sleepDisplay,
  ]

  static let windowSnaps: [ActionID: WindowSnap] = [
    BuiltInAction.windowLeftHalf: .leftHalf,
    BuiltInAction.windowRightHalf: .rightHalf,
    BuiltInAction.windowTopHalf: .topHalf,
    BuiltInAction.windowBottomHalf: .bottomHalf,
    BuiltInAction.windowMaximize: .maximize,
    BuiltInAction.windowCenter: .center,
  ]
}
