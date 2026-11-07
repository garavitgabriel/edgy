# Edgy settings reference

Every setting Edgy keeps, its range and default, and the `SettingsEditor` method the settings window
uses to change it. Everything here lives in `~/Library/Application Support/Edgy/config.json`
(`EdgyConfig`, schema version 1) unless marked *not persisted*.

`Tests/EdgyRuntimeTests/SettingsAuditTests.swift` keeps this page honest. It walks every `AppSettings`
and `GestureSettings` field, every catalog parameter kind and every profile feature through
`SettingsEditor`, checks each one survives a save and reload, and checks this page names each field
and validation code.

All edits go through `SettingsEditor` (`@MainActor`). Each edit validates the new config, saves it,
applies it to the engine and notifies observers (`observe`). Each edit is one undo step
(`undo` / `redo`, up to 50 steps). A slider drag is one step: `beginContinuousEdit(key)` …
`endContinuousEdit()`. An edit that would introduce an error throws `SettingsEditorError.invalid` and
changes nothing.

## App settings: `AppSettings`

Change with `updateAppSettings { $0.<field> = … }`.

| Field | Type / range | Default | What it does |
|---|---|---|---|
| `enabled` | Bool | `true` | Master switch. Off: no gesture runs anything (the engine stays running). Also in the menu. |
| `showMenuBarIcon` | Bool | `true` | Shows the menu-bar item. |
| `hud` | `native` / `none` | `native` | Volume and brightness show the system on-screen indicator, or nothing. |
| `haptics` | Bool | `true` | Master haptics switch. Off silences every haptic, whatever `hapticEvents` says. |
| `hapticEvents` | set of `slideSteps`, `slideLimits`, `gestureCaught`, `actionFired` | all four | Which moments tick. `slideSteps`: every 1/16 of a level. `slideLimits`: a level reaches 0 or 1. `gestureCaught`: Edgy takes hold of a slide (and every recognized gesture in Test Mode). `actionFired`: a tap, double-tap, swipe or long-press runs its action. |
| `hapticTickStrength` | Int 1…6 (`AppSettings.hapticStrengthRange`) | 6 | Strength of light ticks (slide steps, gesture caught). Clamped on edit and on load. |
| `hapticClickStrength` | Int 1…6 | 6 | Strength of clicks (slide limits, action fired). Clamped. |
| `launchAtLogin` | Bool | `false` | Start Edgy at login. |
| `unresponsiveDisplays` | Set of display keys | empty | External displays the user said ignore brightness commands ("No, turn off for this display"); brightness skips them (unavailable, "Turned off for this display."). Set by `answerDisplayCheck(key:responds: false)`; `turnDisplayBackOn(key:)` removes one. |
| `confirmedDisplays` | Set of display keys | empty | External displays the user confirmed respond (`answerDisplayCheck(key:responds: true)`); never asked again. |
| `displayCheckAsks` | Display key → count | empty | How often Edgy asked about an unconfirmed display (at most 3; `countDisplayCheckAsk(key:)`). |

### The display check ("Did this screen change brightness?")

A display key is `DisplayInfo.key`: the display's vendor and model in lowercase hex, plus its serial
when it reports one (`"4c2d-7154-9"`), so it survives reconnects. A display with no identity is keyed
by its name.

- **Availability.** A monitor driven over DDC (a third-party display) can accept a brightness command
  without applying it. While any such monitor is unconfirmed, `display.brightness` is
  `limited("May not respond: some monitors accept brightness commands without applying them.")`.
  Displays in `unresponsiveDisplays` are skipped as if unplugged; when nothing else takes brightness
  the action is unavailable with "Turned off for this display.". Apple displays and the built-in
  panel are never checked.
- **When it's asked.** A brightness slide that changed the level on an unconfirmed, not-turned-off DDC
  monitor asked fewer than 3 times ends with a `displayCheckDue(key:name:)` feed decision. The UI
  shows the plate, calls `countDisplayCheckAsk(key:)`, and records the answer with
  `answerDisplayCheck(key:responds:)`.
- **Editor API** (each one undo step, through `updateAppSettings`):

| Method | Effect |
|---|---|
| `displayCheckDue(key:)` | Whether the question is still due for that display. |
| `countDisplayCheckAsk(key:)` | One more ask, capped at 3 (`SettingsEditor.displayCheckMaxAsks`). |
| `answerDisplayCheck(key:responds:)` | Yes → `confirmedDisplays`. No → `unresponsiveDisplays`. Each removes the key from the other set. |
| `turnDisplayBackOn(key:)` | Removes the key from `unresponsiveDisplays` ("Turn back on"). Not confirmed, so it may ask again while asks remain. |

## Gesture tuning: `GestureSettings`

Change with `updateGestureSettings { $0.<field> = … }`. The editor clamps every value into
`GestureSettingsLimits`. A non-finite value falls back to the default. An out-of-range value in a
hand-edited file shows a `settingOutOfRange` warning. Geometry is in millimetres (the sensor size comes
from the device), time in milliseconds.

| Field | Range | Default | What it does |
|---|---|---|---|
| `edgeWidthMM` | 3…20 mm | 8 | Depth of each edge strip, measured from the physical edge. |
| `cornerSizeMM` | 5…30 mm | 10 | Side of each corner square. A mapped corner wins over the edges inside its square. |
| `dwellMS` | 0…1000 ms | 120 | How long a finger rests (or moves along the edge) before Edgy claims a slide. |
| `palmMajorAxisMM` | 10…40 mm | 18 | Contacts wider than this are palms and never gestures. |
| `typingSuppressionMS` | 0…3000 ms | 500 | Edge gestures are ignored this long after a key press (0 = off). |
| `doubleTapWindowMS` | 150…800 ms | 300 | Longest gap between the two taps of a double-tap. In a zone with both a tap and a double-tap, a single tap waits this long before it runs. |
| `longPressMS` | 250…2000 ms | 500 | Hold time for a long-press. |
| `fingers` | 1…2 | 1 | Fingers a slide uses. |

## Profiles

A **profile** is a list of bindings. Each binding maps a zone and a gesture to an action plus its
parameters, with at most one binding per zone + gesture (a `BindingKey`). The **default profile**
applies everywhere. An **app profile** is keyed by the app's bundle identifier and applies while that
app is frontmost.

| Feature | Stored as | How the UI changes it |
|---|---|---|
| Bind a gesture | `Binding` in `bindings` | `setBinding(_:in:replacing:)`. `replacing:` moves a binding to another slot in one step. |
| Unbind | — | `removeBinding(_:from:)` |
| Add an app profile | `appProfiles[bundleID]` | `addAppProfile(bundleID:startingAs:)`. `.inheriting` (default), `.copyOfDefault` or `.empty`. The old `addAppProfile(bundleID:copyingDefault:)` still makes a full-replace profile. |
| Remove an app profile | — | `removeAppProfile(bundleID:)` |
| Turn Edgy off in an app | `disabled` | `setProfileDisabled(_:for:)` |
| Inherit the default | `inheritsDefault` | Set by `addAppProfile` (`.inheriting`) or `convertToInheriting(bundleID:)` |
| Override one gesture for an app | a binding in the app profile | `overrideBinding(_:forApp:)`. Creates an inheriting profile if the app has none. |
| Turn one gesture off for an app | a binding to `edgy.none` (`ActionID.doNothing`) | `turnOff(_:forApp:)` |
| Revert to the default | — (removes the app's binding) | `revertToDefault(_:forApp:)` |
| Convert an old copied profile | — | `convertToInheriting(bundleID:)`. Bindings equal to the default are dropped, default slots the app lacked become "do nothing", and the app behaves exactly as before. |
| Reset | — | `resetProfile(_:)`. Default profile → built-in preset. Inheriting app → no overrides. Full-replace app → a copy of the default. `resetAll()` → `EdgyConfig.defaults`. |

### Presets (onboarding step 3)

`Presets` (EdgyRuntime) holds three whole configs; only their default profile matters.
`applyPreset(_ preset: Presets.Preset)` replaces the default profile with the preset's, run through
`MachineDefaults` for this Mac (unavailable actions substituted or dropped). App settings, gesture
tuning and app profiles stay. One undo step.

| Preset | Bindings (zone, gesture → action) |
|---|---|
| `Presets.media` (= `EdgyConfig.defaults`) | right slide → `audio.volume` · left slide → `display.brightness` · bottom swipe left → `media.previous` · bottom swipe right → `media.next` · bottom double-tap → `media.playPause` · top-right double-tap → `audio.mute` · top-left double-tap → `mic.mute` |
| `Presets.windows` | right slide → `audio.volume` · left slide → `display.brightness` · bottom swipe left → `window.leftHalf` · bottom swipe right → `window.rightHalf` · bottom long-press → `window.maximize` · bottom double-tap → `window.center` · top double-tap → `system.missionControl` · top-left double-tap → `system.showDesktop` · top-right double-tap → `audio.mute` |
| `Presets.minimal` | right slide → `audio.volume` · left slide → `display.brightness` |

Every binding validates with no issue at all (`PresetTests`).

**Inheriting vs. full-replace.** For an inheriting app profile (`inheritsDefault: true`), the app's
bindings are overrides. A binding replaces the default's binding on the same slot, and `edgy.none`
turns that slot off. Default edits still reach the app. A full-replace profile
(`inheritsDefault: false`, the pre-v0.4 behaviour and what older config files decode to) replaces
the default entirely.

**What the window shows.** `effectiveBindings(forApp:)` lists one row per slot for an app, each with
its source: `inherited`, `overridden`, `turnedOff` or `appOnly`. Overrides and turned-off rows include
the default binding they replace. `bindingsByZone(in:)` lists a profile's own bindings by zone.
`effectiveProfile(for:)` names the profile in effect.

## Actions

The picker uses `catalogByCategory` (grouped, sorted by name, without "do nothing"). For one slot it
uses `compatibleActions(zone:gesture:)`, which lists the actions that fit the gesture and then "do
nothing" last. `availability(of:)` says whether an action works on this Mac: unavailable actions are
greyed out with their reason. `refreshAvailability()` re-checks after a display or keyboard is
attached or removed. When anything changed, observers get a `SettingsChange` with cause
`.availability`.

Shapes: **continuous** actions fit a slide only, **hold** actions fit a long-press only, and
**trigger** actions fit every gesture except a slide. "Do nothing" fits every gesture.

### Parameters on every binding

| Key | Values | Applies to | Effect |
|---|---|---|---|
| `haptics` | `"off"` | every binding | Silences this binding's haptics. |
| `sensitivity` | number | continuous actions | Scales slide travel. |

Set them as binding parameters with `setBinding` (or `overrideBinding`).

### Catalog

A parameter with no default is required.

| id | Name | Shape | Category | Parameters (key: kind, default, label) |
|---|---|---|---|---|
| `audio.volume` | Volume | continuous | sound | — |
| `audio.mute` | Mute | trigger | sound | — |
| `mic.mute` | Microphone Mute | trigger | sound | — |
| `display.brightness` | Brightness | continuous | display | — (availability depends on the displays) |
| `keyboard.backlight` | Keyboard Brightness | continuous | display | — (unavailable without a backlit keyboard) |
| `keyboard.backlightToggle` | Keyboard Backlight On / Off | trigger | display | — (unavailable without a backlit keyboard) |
| `media.playPause` | Play / Pause | trigger | media | — |
| `media.next` | Next Track | trigger | media | — |
| `media.previous` | Previous Track | trigger | media | — |
| `system.missionControl` | Mission Control | trigger | system | — |
| `system.appWindows` | App Windows | trigger | system | — |
| `system.showDesktop` | Show Desktop | trigger | system | — |
| `spaces.left` | Space Left | trigger | system | — (limited: uses the system Control–Left shortcut) |
| `spaces.right` | Space Right | trigger | system | — (limited: uses the system Control–Right shortcut) |
| `system.lockScreen` | Lock Screen | trigger | system | — (limited: uses the system Control–Command–Q shortcut) |
| `system.sleepDisplay` | Sleep Display | trigger | system | — |
| `system.dictation` | Dictation | trigger | system | — (limited: needs Dictation on, with the microphone key as its shortcut) |
| `window.leftHalf` | Left Half | trigger | windows | — |
| `window.rightHalf` | Right Half | trigger | windows | — |
| `window.topHalf` | Top Half | trigger | windows | — |
| `window.bottomHalf` | Bottom Half | trigger | windows | — |
| `window.maximize` | Maximize | trigger | windows | — |
| `window.center` | Center | trigger | windows | — |
| `window.minimize` | Minimize | trigger | windows | — |
| `window.restore` | Restore Window | trigger | windows | — |
| `app.open` | Open App | trigger | apps | `bundleID`: app bundle ID, required, "App"; `whenFrontmost`: choice `stay` / `hide`, default `hide`, "When Already in Front" |
| `url.open` | Open URL | trigger | apps | `url`: URL with a scheme, required, "URL" |
| `file.open` | Open File or Folder | trigger | apps | `path`: absolute or `~` path, required, "File or Folder" |
| `apps.switcher` | Switch Apps | continuous | apps | `step`: number 0.04…0.5, default 0.1, "Step" |
| `keyboard.shortcut` | Keyboard Shortcut | trigger | keyboard | `keys`: key combo, required, "Keys" |
| `keyboard.slideSteps` | Slide to Repeat Keys | continuous | keyboard | `upKeys`: key combo, required, "Up / Right Keys"; `downKeys`: key combo, required, "Down / Left Keys"; `step`: number 0.02…0.5, default 0.0625, "Step" |
| `keyboard.hold` | Hold Keys | hold | keyboard | `keys`: key combo, required, "Keys". Modifiers alone (`fn`, `ctrl+opt`) are allowed, for push-to-talk. |
| `shortcut.run` | Run Shortcut | trigger | shortcuts | `name`: text, required, "Shortcut Name" |
| `edgy.none` | Do nothing | any | — | — (only meaningful in an inheriting app profile; never performed) |

The catalog is defined in `Sources/Actions/ActionCatalog.swift`. Add new actions there first, then
list them here.

Parameter kinds and how they are checked: **text** (anything); **key combo** (`KeyCombo` syntax such
as `cmd+shift+4`, with modifiers `ctrl opt shift cmd fn`; a combo of modifiers alone is valid only on a
hold action); **app bundle ID** (contains a dot, no spaces); **URL** (has a scheme); **file path**
(starts with `/` or `~`); **number** (within its range); **choice** (one of the listed values).

## Validation codes

`issues` holds every validation problem in the current config. `validate(_:in:)` checks one binding
before it is set. Severities: **error** (blocks an edit that would introduce it), **warning** (shown,
never blocks), and **info** (a conflict note: how two bindings interact, never a problem). Raw values
are stable.

| Code | Severity | Meaning |
|---|---|---|
| `unknownAction` | error | The action isn't in the catalog. |
| `shapeMismatch` | error | The action's shape doesn't fit the gesture. |
| `gestureNotSupported` | error | The zone can't produce the gesture (e.g. a slide in a corner). |
| `segmentOutOfRange` | error | Edge split outside 1…4 segments, or a segment index outside it. |
| `missingParameter` | error | A required parameter is empty. |
| `invalidKeyCombo` | error | Unparseable combo, or modifiers alone on a non-hold action (`detail` says so). |
| `invalidURL` | error | A URL without a scheme. |
| `notANumber` | error | A number parameter that isn't a number. |
| `numberOutOfRange` | error | A number outside its range. |
| `invalidChoice` | error | Not one of the choices. |
| `invalidBundleID` | error | An app parameter that isn't a bundle ID. |
| `invalidFilePath` | error | A path that's neither absolute nor `~`. |
| `unknownParameter` | warning | A parameter the action doesn't read. |
| `duplicateBinding` | error | Two bindings on one slot in one profile (an inheriting app's override of a default slot is not a duplicate). |
| `overlappingZones` | warning | Overlapping parts of one edge bound to the same gesture, including an app override overlapping an inherited default. |
| `invalidProfileID` | error | An app profile key that isn't a bundle ID. |
| `settingOutOfRange` | warning | A gesture setting outside its limits. |
| `actionUnavailable` | warning | The action can't work on this Mac right now; the binding is kept. |
| `tapWaitsForDoubleTap` | info | The zone has a tap and a double-tap, so a tap waits `doubleTapWindowMS` (`detail`, in ms) before it runs. |

## A broken config file

When the file on disk stops decoding or validating on reload, Edgy keeps running the last working
settings:

- `configProblem` (`ConfigProblem`: `message`, and `line` when the parser gave one) is set and
  observers get a change with cause `.configProblem`.
- Every edit, `undo` and `redo` throws `SettingsEditorError.readOnly(problem)`, so nothing
  overwrites the user's file. A drag in progress is closed without saving.
- `replaceFileWithCurrentSettings()` writes the running config over the file and clears the problem
  (the UI confirms first).
- It clears by itself when a reload reads a good file (`.external`, or `.configProblem` when the fixed
  file equals the running config).

Where it comes from: `reloadFromDisk()` (Reload Config; it also rethrows), `adoptExternal(_:)` (a
file that *introduces* validation errors is not adopted; errors the running config already had stay
exposed and never block), and `reportConfigProblem(_:)`, which the app calls from the watcher's new
`ConfigStore.startWatching(onChange:onFailure:)`.

There's no "hold and trigger on one long-press" note. A zone has one long-press slot, so a hold and a
trigger can't share it.

## Runtime (not persisted)

These live on `Engine`, not in the config.

| Feature | API | Notes |
|---|---|---|
| Pause | `pause(until:)` / `resume()` | Timed pauses are driven by the app. |
| Test Mode | `setTestMode(_:)`, `isTestMode`, `EngineStatus.testMode` | Gestures are recognized and routed, but no action runs. Each would-be action gives the "caught" haptic and a `wouldRun` feed decision. Switching either way drops in-flight gestures safely. |
| Live feed | `observeFeed(on:_:)` / `removeFeedObserver(_:)` | Normalized touches per device (`down` / `claimed` / `rejected`), at most 60 Hz. Decisions as they happen: recognized, rejected (with the zone it landed in and its `measure`), action ran (with its `outcome`) / updated / failed / unavailable / would run, and `displayCheckDue(key:name:)`. Runs only while someone observes and the engine is active. |

### Feed decisions with numbers (v0.5)

- `rejected(…, measure:)` carries the recognizer's `rejectionMeasures` entry for that contact.
- `actionRan(…, outcome:)` carries what the action reported (`performReporting`): a level slide's
  level at its first step, the held combo of `keyboard.hold` ("fn"), the display's name for external
  brightness. `nil` for actions with nothing to show.
- `actionUpdated(id, zone:, kind:, outcome:)` follows a slide after its first step, sent only when the
  whole-percent level or the detail changes.
- `displayCheckDue(key:name:)`: see "The display check" above.

| Action | `level` | `detail` | `systemHUDShown` |
|---|---|---|---|
| `audio.volume` | after the change | — | true while `hud` is `native` |
| `display.brightness`, built-in | after the change | — | true while `hud` is `native` |
| `display.brightness`, external | after the change | the display's name | false (Edgy draws the level plate) |
| `keyboard.backlight` | after the change | — | false |
| `keyboard.hold` | — | the combo as read: "fn", "⌃⌥ Space", "⇧⌘ 4" | false |
| `apps.switcher` | — | — | true (the system's switcher is the feedback) |
| everything else | `nil` outcome | | |

How the display-check request crosses modules: `ActionOutcome` is frozen and the runtime can't import
Actions, so the external-brightness `detail` is "name" + `\u{1E}displayCheck:` + "key" when a check is
due. The router splits it; the feed only ever shows the plain name.

### Rejection measures (`GestureOutput.rejectionMeasures`)

What each `RejectionReason` really measures in the pipeline, in `RejectionMeasure` units. "Limit" is
the setting or threshold the touch crossed.

| Reason | Where it's decided | `measured` | `limit` | Unit |
|---|---|---|---|---|
| `palm` | contact shape, at landing or as it spreads | major axis | `palmMajorAxisMM` (18) | mm |
| `palm` (round blob) | same | minor axis | fixed 14 mm | mm |
| `palm` (size / density only) | same | — (unitless device readings) | — | none |
| `typing` | at landing, and while unclaimed | time since the last key | `typingSuppressionMS` (500) | ms |
| `tooManyContacts` | every frame | non-palm contacts on the pad | `fingers` (1…2) | fingers |
| `offAxisMotion`, corner | corner touch moving | travel from landing | fixed 3 mm | mm |
| `offAxisMotion`, edge, outward | before the claim | sideways travel toward the edge | fixed 2.5 mm | mm |
| `offAxisMotion`, edge, diagonal | before the claim, no axis dominant | total travel | fixed 3 mm | mm |
| `offAxisMotion`, swipe that veered | swipe candidate lifting | travel across the edge | travel along it | mm |
| `tooFast`, held too long | swipe candidate still down | time since landing | swipe limit: 350 ms (600 ms where no slide is bound) | ms |
| `tooFast`, too short | swipe candidate lifting | travel along the edge | fixed 6 mm | mm |
| `tooFast`, no clear axis at lift | swipe candidate lifting | — | — | none |
| `startedOutsideZone` | a touch drifting into a mapped zone | how far in from that edge it landed | `edgeWidthMM`, or `cornerSizeMM` for a corner | mm |
| `disabledZone` | landing in an unmapped part | — | — | none |
| `systemGestureHandoff` | inward motion before the claim | — | — | none |
| `physicalClick` | the button went down | — | — | none |

`tooFast` never measures speed or dwell: a touch fast enough to be a swipe candidate is rejected
when it then stays down past the swipe time limit or lifts too short. The feed doesn't report
`startedOutsideZone` (ordinary pointer use), so its measure stays in the recognizer output.
