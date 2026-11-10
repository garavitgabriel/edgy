import Displays
import EdgyCore

/// Batch EDGY-ACTIONS owns this module.
public enum ActionsInfo {
  public static let module = "Actions"
}

// FROZEN FACTORY SIGNATURE — the app calls this. Replace the body, never the signature.

/// The live action registry, backed by real system outputs. Only the app may call this;
/// tests must build registries from mock outputs.
///
/// Building the registry has no side effects on the system: every output connects or loads on
/// first use. The one exception is listen-only: the Last App tracker starts observing the
/// workspace's did-activate notification at once (event-driven, never polling), because it needs
/// the apps used before its first trigger.
/// The returned object is an `ActionRegistry`; the app can cast to it to update `settings`.
public func makeLiveActionRegistry(settings: AppSettings) -> ActionPerforming {
  let keyboard = LiveKeyboardOutput()
  return ActionRegistry(
    settings: settings, audio: LiveAudioOutput(), display: LiveBrightnessOutput(),
    media: LiveMediaKeyOutput(), hud: LiveHUDOutput(), haptics: LiveHapticOutput(),
    shortcuts: LiveShortcutRunner(), keyboard: keyboard, workspace: LiveWorkspaceOutput(),
    windows: LiveWindowOutput(), system: LiveSystemOutput(keyboard: keyboard), levelKeys: LiveLevelKeyOutput(),
    displays: makeLiveDisplayBrightness(), backlight: LiveKeyboardBacklightOutput(),
    dictation: LiveDictationOutput(), waiter: LiveTransitionWaiter(),
    scheduler: LiveActionScheduler(), switcherInput: LiveSwitcherInputMonitor(),
    apps: LiveAppActivations())
}
