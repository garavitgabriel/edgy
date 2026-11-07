# Edgy brief

## Design

This section was locked on 2026-11-07 by a three-round design sprint. The full record is in `docs/design/`:
- the bones
- the prompts for every round
- the critiques
- the final reference renders in `docs/design/final/26F-1TVB-A..F.png`

The editable canvas is the claude.ai Design artifact "Edgy final · 26F-1TVB" (owner-private). When this section and a render disagree, **this section wins**; the render shows the feel.

### The look in one line

**Warm glass that borrows your desktop's colour, with one rust accent that means "live".** The window, popover and plates are translucent material tinted by what's behind them. Every line of text sits on enough opacity to read. The app owns no palette, only an ink colour and one accent.

Why this look: the owner picked it on taste in every round (rounds 1, 2 and 3; the other directions were killed or parked). It is a warm, friendly object you like seeing, on a utility you must trust. The critic score went from 5/10 (round 2) to 7/10 (final v2), with 0 bone FAILs from round 3 onward.

### Tokens

| Token | Light | Dark | Use |
|---|---|---|---|
| `ink` | `#3B2219` | `#FBEADB` | primary text, selection ring, glyph |
| `ink2` | `#6B4A3B` | `#D9BFAE` | secondary text (must still be ≥4.5:1 on its actual background) |
| `accent` / live | `#B4542B` | `#B4542B` | **only:** recognized touch, the live zone, ON switches, the icon dot |
| `bar` (mapped edge) | `#D9AE8C` | `#7A5646` | mapped zone fill |
| `line` (outlines) | `#8E6B58` | `#A58676` | unmapped hairlines, dashed pass-through (≥3:1 on the pad) |
| pad slab | `#F8E3CE → #EFCCAB` | `#4A3026 → #3A251D` | the mirror's surface, top-left lit |
| window material | warm translucent, ~0.8 opacity over blur | `rgba(42,27,21,.82)` | system window material tinted warm; never let text drop below 4.5:1 |

- **One hue.** No second colour anywhere: no blue selection, no amber warnings, no red errors. Warnings use weight plus an icon. The window buttons are neutral.
- **Type:** the system font only. One scale: **11** (picker group headers only) / **13** (everything else, the floor) / **17** (plate values, Continue) / **26** (the one confident line: the selected zone's name or the onboarding headline). Weights are regular and semibold. Use proportional figures everywhere, with no space before % ("64%").
- **Radii:** the window has the system radius; controls 6–8; plates 12–14; zone bars fully rounded ends. Never one radius for everything, and never a radius nested inside a radius.
- **Gesture icons:** one family, one stroke weight and one grid. Swipe up and swipe down must differ clearly.

### Bones (hard rules; every PR touching UI is checked against these)

The full text and evidence are in `docs/design/bones.md` and `docs/design/canvas-prompts-r3.md` § BONES.

1. **The mirror is the pad.**
   - It is to scale, from the device's real sensor size.
   - It uses the trackpad's orientation.
   - No rulers, dimension lines or mm callouts.
2. **Zone states by shape** (the build must match the final render):
   - **Mapped edge:** a solid inset bar with rounded ends.
   - **Unmapped edge:** a hairline outline.
   - **Mapped corner:** a solid rounded square with its action icon inside.
   - **Pass-through corner:** a dashed rounded square. Dashed means pass-through and nothing else.
   - **Selected:** an `ink` ring around the zone.
   - **Live:** the accent contact, plus a thin accent border on the lit bar.
   - Selection and live never look alike.
3. **Labels are joined to their zone.**
   - Side strips are 8 mm, about 30 pt, too narrow for text. Their labels are tabs growing from the strip's inner side, in the same fill and with no gap.
   - Top and bottom labels sit inside the bar.
   - Corner labels are tabs flush to the corner tile.
   - Labels are never floating pills, never rotated, and ≥13 pt.
   - The selected zone needs no chip, because the inspector names it.
4. **Recognized vs rejected by shape.**
   - **Recognized:** a filled accent contact.
   - **Rejected:** a hollow, struck circle.
   - A rejection states the measured value against the limit: **"Ignored: palm, 21 mm wide, limit 18 mm"**. This plate was every critic's KEEP; build it exactly like that.
   - **Copy pattern for every reason:** "Ignored: <reason>, <measured>, limit <limit>". Use the setting's own unit (mm or ms). When no number means anything, stop after the reason.

     | Reason | Plate copy |
     |---|---|
     | palm | Ignored: palm, 21 mm wide, limit 18 mm |
     | typing | Ignored: typing, last key 200 ms ago, limit 500 ms |
     | too many contacts | Ignored: 3 fingers, set to 1 |
     | off-axis motion | Ignored: off-axis, 38° from the edge, limit 25° *(use the runtime's real measure; if it has none, "Ignored: off-axis")* |
     | too fast (dwell) | Ignored: too quick, 60 ms, needs 120 ms |
     | started outside a zone | Ignored: started 14 mm in, edge is 8 mm |
     | handed off to a system gesture | Ignored: system gesture |
     | click | Ignored: click |
     | zone disabled / Edgy off in app | Ignored: Edgy is off in Huddle *(or "Ignored: zone off")* |
   - Recognized is louder.
5. **You map on the pad.**
   - Clicking a zone selects it.
   - The action picker is a popover anchored to that zone on the mirror, with an arrow.
   - It has a header naming what it sets ("Tap, bottom edge"), a search field and grouped rows.
   - **Build it as a single-column list that scrolls if needed.** The render's two columns were a canvas-space workaround that the critic marked down.
   - Actions that can't take the gesture are dimmed, with **one** group note ("These need a slide.").
   - The picker never covers its trigger or the neighbouring zones, and never leaves the window.
6. **The inspector:**
   - It shows the selected zone's name (26), "Split into 1 2 3 4" (the runtime allows 1…4 segments), and **only the mapped gestures** with their actions in plain text.
   - It ends with "Add gesture…".
   - Clicking a row opens the same pad popover. There is one place to map, not two.
   - While the picker is open, the row's value is blank (the popover header already says it).
7. **Interaction notes are named with their fix** (since v0.4 they inform; they don't warn):
   - A tap on a zone that also has a double-tap **waits out the double-tap window**, so nothing misfires. The note is informational: **"Tap waits 300 ms here to tell it from a double-tap."** (use the real `doubleTapWindowMS` value).
   - One inline fix: **"Use long-press instead"**.
   - It keeps the icon plus inline-fix shape, but uses an **info** icon in `ink2`, not a warning triangle. It must never read as an error.
   - It doesn't repeat the zone name. *(Render B's copy, "fires the tap action first", and its "Delay tap by 300 ms" button are out of date. Follow this text, not the render.)*
8. **Each status is said once, next to the thing it describes.**
   - Live feedback appears on the mirror at the touch.
   - In onboarding, the system's own volume indicator carries "64%"; Edgy doesn't repeat it.
   - In Test Mode, the menu glyph's dot is the only "test mode is on" marker. **Drop the "Test mode" pill shown in render D.**
9. **The overlay (Test Mode):**
   - It is a click-through, non-activating panel that never takes focus and never sits over the text being worked on.
   - Each element is its own plate, docked to the screen edge or corner of the touched zone and fully on-screen.
   - Plate text is ≥13 pt at ≥4.5:1, readable over light and dark documents.
   - **One plate component** is shared by the overlay and the onboarding feedback: same radius, same 17/13 type pair, same inset. In the render, C and D look like two products; don't build that.
10. **The menu-bar popover** (not a plain menu):
    - **Top half:** a live mini mirror (zones of the active profile plus the last touch where it landed), profile chips, and **Enabled** and **Test Mode** switches.
    - **Profile chips don't select anything.** Profiles follow the frontmost app automatically. The chip of the profile in effect is filled; the others are outlined. Clicking a chip opens Settings on that profile's tab. If the frontmost app has its own profile, its chip comes first.
    - **Two trackpads attached:** the mirrors (window, popover, onboarding) show **the pad touched last**, with no picker. Its outline follows that device's real proportions. When it switches, the outline cross-fades (150 ms).
    - **Bottom half:** a plain list with the system highlight: Pause for 1 hour, Settings… ⌘,, Open config file, Reload config ⌘R, About Edgy, Quit Edgy ⌘Q.
    - No power button, hero numeral or cards on cards.

### Surfaces

| Surface | Reference | Notes for the build |
|---|---|---|
| Settings editor, light | `final/26F-1TVB-A.png` | No sidebar. Profile tabs sit top centre (Default, then per-app tabs with small monochrome app marks, then "+"), with Enabled at top right. The mirror is on the left, the inspector on the right, and a footer row holds Haptics, Launch at login, HUD and Advanced…. The pad slab has subtle depth: a soft lower edge, top-left light, and a touch that presses in slightly with no glow halo. |
| Settings editor, dark, picker + conflict | `final/26F-1TVB-B.png` | A and B are deliberately different states: B shows the right edge split into 2. In demo data, avoid mapping Brightness twice (left edge and lower right). The critic read that as incoherent. |
| Onboarding, step 2 "Try it" | `final/26F-1TVB-C.png` | Four steps: Accessibility ✓, Try it, Pick a preset, Launch at login. The live mirror and the system volume indicator appear side by side. One round Continue, the only chunky round control in the app. Headline: one clause, no colon. |
| Test Mode overlay | `final/26F-1TVB-D.png` | It's entered from the popover's Test Mode switch. Its plates dock at the touched edge. Remove the pill under the glyph (rule 8). |
| Menu-bar popover | `final/26F-1TVB-E.png` | Shows Test Mode being switched on. |
| Icon + glyph | `final/26F-1TVB-F.png` | See below. |

### Menu glyph and app icon

- **Glyph: "Lit edge" (01a, with 01b's wider gap).**
  - A rounded-rectangle outline of the pad, open on the right, with a separate heavy vertical bar standing for the lit right edge.
  - It's a monochrome template image, about 16 × 11 pt.
  - In Test Mode it adds a small solid dot inside the outline. **Make that dot ≥2 pt at 1×**, because the render's ~1.5 pt dot disappears.
  - Note for the G1 device check: one critic read it as the letters "CI" before reading it as a pad. Judge it at real size in the real menu bar before freezing it.
- **App icon: "Exact".**
  - A pale-stone rounded tile with a gentle light-to-shade gradient.
  - A graphite line drawing of the pad at true proportion, with a heavy right edge (the glyph, enlarged).
  - At ≥128 px, add one rust contact dot on the heavy edge. Leave the dot off at 32 px and below.
  - No banding at the tile edge.

### Kill list (never ship these)

- Tracked micro-caps eyebrow labels.
- A grey rounded rectangle with a drop shadow as the trackpad, or brushed metal.
- A sidebar.
- N equal cards, one per zone.
- Gradient blobs, neon glow, or halos on the touch dot.
- Emoji or Unicode arrows as gesture icons.
- Middot-chained metadata strings.
- Dimension lines or rulers.
- A space before %.
- More than one typeface family.
- Rotated labels.
- Hero numerals.
- A launcher grid of round buttons.
- Filler or roadmap copy ("more actions coming").
- Generic coloured squares as app icons.
- A second hue.
- Any third-party product name or look-alike.

### Copy voice

Plain, specific and measured. Name the thing, the number and the limit.
- "Ignored: palm, 21 mm wide, limit 18 mm."
- "These need a slide."
- "Run one finger up the right edge."

Use one clause, no slogans, and no two-part oracular lines.

### App profiles (spec, 2026-11-07; renders to follow)

The runtime API is in `SettingsEditor`: `effectiveBindings(forApp:)` with sources, `overrideBinding`, `turnOff`, `revertToDefault`, `addAppProfile(startingAs:)`, `setProfileDisabled`, `convertToInheriting`.

**Tabs.** The order is Default, then app tabs alphabetically (app mark + name), then "+". A tab whose app has Edgy turned off shows its name in `ink2` with a small slashed-circle mark; there's no other colour.

**The top-right switch follows the tab.**
- On Default it is **Enabled** (global).
- On an app tab it is **"On in Huddle"** (`setProfileDisabled`).
- Global Enabled is still in the popover. Each status is said once, where it applies.

**The mirror on an app tab shows the *effective* bindings,** meaning what will actually happen in that app, drawn with the normal zone shapes. Two source marks appear on the pad:
- **Overridden:** the zone's label tab gets a small solid `ink` dot before its text.
- **Turned off here:** the zone is drawn as unmapped (hairline), and its tab reads "Off here" in `ink2`.
- Inherited and app-only zones look normal. Inherited is the expected case, so it isn't marked.

**Inspector rows on an app tab**, one per slot, from `effectiveBindings`:

| Source | Row |
|---|---|
| inherited | Gesture · action in `ink2` · trailing caption "from Default" (13, `ink2`). Clicking opens the pad picker, and choosing creates an override. |
| overridden | Gesture · **action** in `ink`, preceded by the dot · trailing text button **Revert**. A second line in `ink2`: "Default: Volume". |
| turned off | Gesture · "Off here" in `ink2` · trailing **Revert**. Second line: "Default: Play/Pause". |
| app-only | Gesture · **action** in `ink`. No caption (the default has nothing on this slot). |

Every row has a "…" menu with Change action…, Turn off here and Revert to Default (each greyed out when it doesn't apply). There's no extra colour; the source is carried by the text and the dot.

**"Edgy is off in this app".**
- The mirror fades to 40% with every zone as a hairline.
- One line is centred on the pad: "Edgy is off in Huddle", with a **Turn on** button.
- The inspector stays empty; there's nothing else to say.
- The popover's mini mirror shows the same faded pad while that app is in front.

**The add-app flow ("+").** A popover anchored to "+", single column:
1. Header "Add an app" · a search field · a **Running** section (apps open now) · an **All apps** section (alphabetical). Rows show the real app icon and name. Apps that already have a profile are listed but disabled, with "Has a profile".
2. Choosing an app turns the same popover into its second step: "Start from", with three radio rows:
   - **"Default, with changes"**, preselected. Its sub-line: "Follows Default; change only what's different."
   - **"A copy of Default"**, sub-line "Starts the same, then goes its own way."
   - **"Empty"**, sub-line "Nothing mapped until you add it."
3. Then **Add** (the default button) and Back.
4. The new tab opens selected.

**Removing and resetting.** The tab's context menu has "Reset Huddle to Default" and "Remove Huddle profile…". Remove asks for confirmation in a standard sheet.

**Legacy (full-replace) profile.**
- A one-line info note sits at the top of the inspector, with an info icon in `ink2`: "This profile doesn't follow Default."
- Text button: **Follow Default**. Under it in `ink2`: "It keeps working exactly as it does now."
- The rows show no source marks; a full-replace profile has no inheritance.

### Binding parameters (spec, 2026-11-07; renders to follow)

**One rule.**
- The parameters sit directly under their binding row in the inspector, indented 24 pt.
- Each takes one 28 pt row: the label on the left (13, `ink2`), the control on the right.
- Validation text sits under its control (13, `ink`, with a small error icon). It is never red or accent.
- A required parameter that's still empty leaves the binding row reading "Needs keys" / "Needs an app" in `ink2`. The pad tab shows the action name with "…".

**Key-combo recorder** (`keys`, `upKeys`, `downKeys`):
- **Idle:** a field showing the combo as system key symbols plus the key name ("⌃⌥ Space", "⌘⇧ 4"). Empty, it reads "Click to record" in `ink2`.
- **Recording:**
  - The field gets a 2 pt **accent** ring (recording is live) and reads "Press keys…".
  - Modifiers you're holding appear live in `ink2` as you press them, and turn `ink` when the combo commits.
  - Esc cancels. ⌫ while idle clears. Recording swallows the keys, so nothing reaches the app.
- **Right-hand modifiers** show as "Right ⌘" or "Right ⌥" when the runtime distinguishes them.
- **Modifiers alone:**
  - On a **hold** action (push-to-talk), releasing all held modifiers after holding them ≥0.6 s commits them ("fn", "⌃⌥").
  - On a trigger action, the same gesture shows: "Add a key. Modifiers alone work only on Hold Keys."

**App chooser** (`bundleID`):
- A pop-up button showing the app icon and name. It opens the same list popover as add-app: search, Running first, then All apps.
- `whenFrontmost` sits under it as a two-option segmented control: **Hide it** / **Stay**, labelled "If already in front".

**URL** (`url`): a text field with the placeholder "https://…". Validation: "Needs a scheme, like https://".

**File or folder** (`path`): a text field with the placeholder "~/Documents", plus a **Choose…** button that opens the system panel. Validation: "Use a full path or start with ~".

**Number** (`step`, `sensitivity`): a slider with its value as text on the right, in proportional figures.

**Choice:** a segmented control for ≤3 options; otherwise a pop-up.

**Text** (`name` for Run Shortcut): a pop-up of the user's shortcuts if the runtime can list them; otherwise a text field.

**Per-binding haptics:** the last parameter row of every binding is a checkbox, "Haptics for this gesture", on by default.

### Level plate and display check (spec)

- **External display brightness and keyboard backlight.** The system draws no indicator for these, so Edgy uses **the one plate component**:
  - The value line (17) reads "Brightness 40%" or "Keyboard 60%".
  - The second line (13, `ink2`) names the device: the display's name, or "Keyboard".
  - A slim level bar uses the accent fill.
  - It docks at the screen edge of the touched zone, on the display being changed, and fades 1.2 s after the slide ends. It shows whether or not Test Mode is on, because it replaces a system HUD.
- **"Did the screen change?"** This is asked once per external display, the first time brightness is used on it:
  - It's a small plate beside the level plate. It **does** accept clicks (a non-activating panel that never takes focus) and is the only clickable plate.
  - Copy: "Did this screen change brightness?" with **Yes** and **No, turn off for this display**.
  - Unanswered, it fades after 15 s and asks again next time, at most 3 times.
  - When the user says No, the inspector's brightness binding gets a second line in `ink2` with a re-enable path: "Off for Desk 34: it ignores brightness commands." · **Turn back on**.

### Test Mode: what it does (decided; two behaviours)

The owner wants both. The runtime has both (`Engine.setTestMode`, the `wouldRun` feed decision).

**Control: in the popover only.**
- Under the Test Mode switch, indented 24 pt, there's a checkbox: **"Don't run actions"**.
- It's visible only while Test Mode is on, off by default, and **not persisted**: it resets when Test Mode turns off or Edgy quits. That way no one is left with an Edgy that silently does nothing.
- No other surface gets a control for it.

**1. Test Mode (default): actions run, and the overlay shows real results.** These are the plates as designed: "Volume 64%" / "Right edge, slide", rejections with their measures, and holds.

**2. Dry run ("Don't run actions" checked): gestures are recognized, nothing runs, and the overlay shows what would have run.**
- **Mark:** the recognized contact in **outline**: a 2 pt accent stroke, no fill.
  - It stays distinct from the rejection mark (a hollow `ink2` circle **with a strike**) by colour role *and* by the strike.
  - It's still the one accent, because it means a live, recognized gesture (bone 4).
- **Copy:** the value line (17) starts with **"Would"** and carries no level, because nothing changed. The second line (13, `ink2`) is unchanged.

  | Kind | Value line | Second line |
  |---|---|---|
  | continuous | Would set Volume | Right edge, slide |
  | trigger | Would run Play/Pause | Bottom edge, double-tap |
  | with a parameter | Would open Quillpad | Bottom-right corner, double-tap |
  | hold | Would hold fn (while held) → "Would release fn" on release, then the same 0.6 s + 200 ms fade | Bottom edge, long-press |
  | rejection | unchanged ("Ignored: palm, 21 mm wide, limit 18 mm") | — |

- **What dry run doesn't show:** the level plate for external brightness or the keyboard, and the system HUD. Nothing changed, so there's no level to show (bone 9).
- **Glyph:** unchanged. The Test Mode dot is enough; the "Would" plates say the rest once, where it happens.

### System states (spec, 2026-11-07)

**Each state is said once per surface, and never in colour.** The glyph changes its *shape*. The popover and the window say it in words, once, beside the thing it affects.

| State | Menu glyph (16 pt template) | Popover | Settings window |
|---|---|---|---|
| Normal | Outline plus the heavy right bar | as designed | as designed |
| Test Mode | + a solid dot inside the outline (≥2 pt) | the Test Mode switch is on | — |
| **Disabled** (Enabled off) | The whole glyph at 40% opacity (template "off" look) | The mini mirror fades to 40%; the Enabled switch, off, is the statement. No extra line. | The Default tab's Enabled switch is off and the mirror fades to 40%. Editing still works. |
| **Paused** | The heavy bar becomes two short stacked dashes (a pause shape inside the glyph) | Under the mini mirror, one line: "Paused, 47 min left" with a **Resume** text button. While paused, the list's "Pause for 1 hour" row is hidden. | The mirror fades to 40%, with one line centred on the pad: "Paused, 47 min left" · **Resume**. |
| **No Accessibility** | The heavy bar becomes a drawn exclamation (a short bar plus a dot) | The top half is replaced by one block: "Edgy needs Accessibility access to run actions." · **Open Settings**. Below it in `ink2`: "Touches still show in Test Mode." The list below is unchanged. | A one-line strip under the tabs, full width, with an info icon in `ink`: the same sentence plus **Open Settings**. It disappears the moment access is granted (the runtime polls). |
| **No trackpad** | 40% opacity, like Disabled; nothing can fire, so it reads the same | The mini mirror becomes a dashed pad outline at the default proportion, with one line inside: "No trackpad connected". | The mirror becomes the same dashed outline, with "Connect a trackpad to see it here." Bindings stay editable; the pad's zones still draw from the last-known size. |

- **Precedence when several apply:** No Accessibility > No trackpad > Paused > Disabled > Test Mode. The glyph shows the top one only.
- **Copy:** time left counts down in whole minutes ("47 min left"). Under 1 minute it reads "less than a minute left". There's no clock time, to avoid a 12/24-hour mismatch.

### Onboarding (spec, 2026-11-07; step 2 is in render C)

The same 640 × 520 glass window, with a step row at the top ("1 Accessibility ✓  2 Try it  3 Pick a preset  4 Launch at login"; done steps take a ✓, the current one is semibold). One 26 pt headline (one clause, no colon), at most one body sentence, and the round primary at the bottom right. That round button is the only chunky round control in the app.

**Step 1: Accessibility.**
- Headline: "Let Edgy run your actions".
- Body (one sentence): "Edgy uses it to keep the pointer still while you slide and to send the keys most actions need." *(Checked against the code on 2026-11-07: media, volume with the native HUD, shortcuts, holds, window moves, Spaces and the pointer hold all need it; only opening apps, URLs and files doesn't.)*
- Primary: **Open Settings**, which opens the system privacy pane.
- The window watches the permission live. When it turns granted, the step row shows ✓, the body becomes "Access granted.", and the primary becomes **Continue**.
- A quiet text button, **Skip for now**, continues without access; the No Accessibility state above then applies.

**Step 3: Pick a preset.** The headline is "Pick a starting point". Three radio rows, each with a 120 pt mini mirror showing that preset's zones (normal zone shapes), the name, and one line:

| Preset | Line | Bindings (zone, gesture → action id) |
|---|---|---|
| **Media** (preselected; = `EdgyConfig.defaults`) | "Volume, brightness and music on the edges." | right slide → `audio.volume` · left slide → `display.brightness` · bottom swipe left → `media.previous` · bottom swipe right → `media.next` · bottom double-tap → `media.playPause` · top-right double-tap → `audio.mute` · top-left double-tap → `mic.mute` |
| **Windows** | "Volume and brightness, plus window moves on the bottom edge." | right slide → `audio.volume` · left slide → `display.brightness` · bottom swipe left → `window.leftHalf` · bottom swipe right → `window.rightHalf` · bottom long-press → `window.maximize` · bottom double-tap → `window.center` · top double-tap → `system.missionControl` · top-left double-tap → `system.showDesktop` · top-right double-tap → `audio.mute` |
| **Minimal** | "Just volume and brightness." | right slide → `audio.volume` · left slide → `display.brightness` |

Primary: **Continue**. One line in `ink2` under the rows: "You can change any of it in Settings." *(MachineDefaults substitutes unavailable actions on this Mac, per the build chief. **Build chief: run every preset binding through `validate`; if a gesture isn't supported on that zone, swap it for a supported one and tell design.** Top and bottom edges take only left/right swipes; fixed 2026-11-07.)*

**Step 4: Launch at login.**
- Headline: "Keep Edgy running".
- One switch row: "Open Edgy when you log in". It is **on** in onboarding (an explicit choice here; the runtime default stays off for config files).
- Primary: **Done**.
- On Done, the window closes and the menu-bar popover opens once, pointing at the glyph, so the user sees where Edgy lives. There's no separate "find me in the menu bar" step.

### Issue states (spec, 2026-11-07)

**Errors, warnings and info are told apart by icon and wording, never by colour** (one hue). Error = an error icon plus `ink` text. Warning = a warning icon plus `ink2`. Info = an info icon plus `ink2`.

- **Error (it blocks the edit):** the edit doesn't apply. The message sits directly under the control that caused it ("Needs a scheme, like https://"). The control keeps the user's input so they can fix it.
- **`actionUnavailable` (warning; the binding is kept):**
  - The pad tab shows the action name in `ink2` with a small slashed-circle mark.
  - The inspector row gets a second line with the availability reason ("Needs a backlit keyboard").
  - The popover's mini mirror draws that zone as unmapped.
- **`overlappingZones` (warning):** one line under the split control: "Upper and lower halves both use Swipe up." · **Show**, which selects the second zone.
- **`settingOutOfRange` (warning):** beside that field in Advanced…: "The config file said 90 mm; using 30 mm."
- **`tapWaitsForDoubleTap` (info):** the interaction note in bone 7.
- **The config file is broken when it is reloaded** (this one comes first: put it above No Accessibility in the glyph precedence):
  - Edgy keeps running the last working settings.
  - **Glyph:** the exclamation shape.
  - **Popover:** the top block reads "config.json has an error on line 14: <parser message>. Edgy kept the last working settings." · **Open config file** · **Reload**.
  - **Window:** a strip under the tabs with the same sentence, plus **Open config file** and **Replace with current settings** (writes the last working config, after a confirm sheet). **The window is read-only while the file is broken**, so nothing silently overwrites the user's edit.

### Picker at catalog scale (spec, 2026-11-07)

- **Layout:**
  - Single column, at most 420 pt wide, and **at most the mirror's height − 16 pt tall** (it never covers the pad's other bars). The header ("Tap, bottom edge") and the search field stay pinned, and the list scrolls.
  - The search field is focused on open. Arrows and Return work; typing filters.
- **Groups, in catalog order:** Sound, Display, Media, System, Windows, Apps, Keyboard, Shortcuts. The group headers are the only 11 pt type.
- **Actions that don't fit the gesture's shape are not listed in their groups.** They collapse into one disclosure row at the end in `ink2`, "6 more need a slide", which expands in place. The search covers them too.
- **Actions unavailable on this Mac** stay in their group, dimmed (`ink2`, still ≥4.5:1), with the reason as a 13 pt second line ("Needs a backlit keyboard"). They stay selectable, and the binding then carries the `actionUnavailable` warning above.
- **Limited actions** carry their note as a second line ("Uses the system Control–Left shortcut").
- **Actions with parameters** end in "…" ("Open App…", "Keyboard Shortcut…"). Choosing one closes the picker and opens its parameter rows in the inspector, with the first field focused or recording.
- **"Do nothing"** appears only on app tabs, last, after a separator, labelled "Do nothing here".

### Hold actions in Test Mode (spec, 2026-11-07)

- **While held:**
  - A plate docks at the touched edge: value line (17) "Holding fn", second line (13, `ink2`) "Bottom edge, long-press".
  - The contact icon is the filled accent contact, static, with no pulse and no glow.
- **On release:** the value line reads "Released fn" for 0.6 s, then the plate fades out over 200 ms.
- **If the hold is cancelled** (the finger slides off the zone), the plate reads "Released fn, finger left the zone" and fades the same way.

### Not yet designed (the sprint drew 8 actions; the real catalog is bigger)

The sprint's renders assumed 8 actions and simple app profiles. The runtime (`docs/settings-reference.md`) has more, and these surfaces still need design. They must follow every rule above:

1. ~~The picker at catalog scale~~ (specced above). Originally: **The picker at catalog scale:** 34 actions in 8 categories (sound, display, media, system, windows, apps, keyboard, shortcuts), unavailable actions greyed out with their reason, and "Do nothing" last in app profiles.
2. ~~Binding parameter editors~~ (specced above). Originally: **Binding parameter editors** in the inspector: a key-combo recorder (including modifier-only for holds), an app chooser, URL and file-path fields, number and choice controls, a shortcut name, a per-binding haptics toggle, and sensitivity.
3. ~~App profiles~~ (specced above). Originally: **App profiles:**
   - Inheriting rows showing their source (inherited / overridden / turned off / app-only), with Turn off and Revert actions.
   - The "Edgy off in this app" state.
   - The add-app flow (choose the app; inherit / copy default / empty).
   - Converting a legacy full-replace profile.
4. **The Advanced… sheet:** gesture tuning (edge width, corner size, dwell, palm size, typing suppression, double-tap window, long-press, fingers) and haptics (events, tick and click strength).
5. ~~Issue states~~ (specced above). Originally: **Issue states:** errors that block an edit, warnings (`actionUnavailable`, `overlappingZones`, `settingOutOfRange`), info notes (`tapWaitsForDoubleTap`, already designed as the conflict note), and a broken config file on reload.
6. ~~System states~~ (specced above). Originally: **System states:** missing Accessibility permission, paused (with the time left), no trackpad attached, and disabled. Each appears in the popover, the glyph and the window.
7. ~~Onboarding steps 1, 3 and 4~~ (specced above). Originally: **Onboarding steps 1, 3 and 4:** the permission grant, picking a preset, launch at login.
8. ~~A hold action in Test Mode~~ (specced above). Originally: **A hold action in Test Mode and the overlay:** long-press push-to-talk (down/up).

### Open for the G1 cut list (decide on the device)

- Glyph legibility at 16 pt in the real menu bar, light and dark (the "CI" risk).
- The amount of slab depth on a real display (subtle, or flat).
- Window material over busy or very dark wallpapers. The full-bleed direction was parked on exactly this risk. Check text contrast on the owner's real wallpapers.
- What ships in v1: per-app profile tabs, the edge split (1–4), the onboarding flow, Test Mode, and the popover's mini mirror.
