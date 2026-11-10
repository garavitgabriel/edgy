#!/usr/bin/env bash
# Manual smoke test: does Edgy still work under the hardened runtime?
#
# Notarization requires the hardened runtime. Edgy loads private frameworks by name at runtime,
# talks to the system HUD over XPC and installs event taps, so this proves each path still works
# before a Developer ID build ships. A human runs it; it only builds and prints instructions.
# It never quits, launches or replaces a running Edgy, and never touches build/Edgy.app.
#
# Usage: scripts/smoke-hardened.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/release/Edgy.app"

echo "Step 1. Build $APP, signed with your Apple Development identity plus --options runtime."
echo "        Same bundle ID and certificate as the dev build, so the Accessibility grant carries over."
"$ROOT/scripts/bundle.sh" --out "$APP" --sign dev --runtime

echo
echo "Step 2. Confirm the hardened runtime flag is on (look for 'flags=0x10000(runtime)'):"
codesign --display --verbose=2 "$APP" 2>&1 | grep -E '^(Identifier|flags|CodeDirectory)' || true
echo "        Entitlements on the app (expected: none):"
codesign --display --entitlements - "$APP" 2>/dev/null || true

cat <<EOF

Step 3. You do this part:
  a. Quit the running Edgy (menu bar icon > Quit).
  b. Launch the hardened build:   open "$APP"
  c. In a second terminal, watch the log:
       /usr/bin/log stream --predicate 'subsystem == "com.garavit.edgy"' --info
     or afterwards:
       /usr/bin/log show --last 10m --predicate 'subsystem == "com.garavit.edgy"' --info

Step 4. Check each item. The log line in quotes is the proof; a line under "fails if" means
        the hardened runtime blocked that path.

  [ ] Touch input (private multitouch framework, loaded by name)
      Touch the trackpad; the mirror in Settings shows your fingers.
      proof:    touch  "device <id> registered (...)" and "device <id>: first frame received"
      fails if: touch  "multitouch unavailable: ..." or "multitouch: symbol ... not found"

  [ ] Pointer guard and typing monitor (event taps)
      proof:    pointer "pointer guard: event tap installed"
      fails if: pointer "pointer guard: event tap unavailable ..." / typing "typing monitor could not be installed"

  [ ] A gesture fires
      Tap a bound corner.
      proof:    engine "Gesture <kind> <phase> at <zone> → <action>" (no "Action ... failed" after it)

  [ ] Volume, with the native indicator (system HUD over XPC)
      Slide a volume edge; the system volume indicator appears.
      fails if: actions "HUD unavailable: ..."

  [ ] Brightness, with the native indicator (private display framework, loaded by name)
      Slide a brightness edge; the screen dims and the indicator appears.
      fails if: actions "brightness unavailable: ..."

  [ ] Hold Keys
      Bind a long-press to Hold Keys (e.g. a modifier); hold, then lift. The key releases.
      proof:    engine "Releasing hold ..." on lift; no actions "hold: ... failed"

  [ ] Switch Apps
      Slide the switcher edge; the app switcher opens, follows your finger, selects on lift.
      proof:    actions "app switcher: selecting (...)"

  [ ] Key recorder (listen-only event tap)
      Settings > a binding > record a shortcut; the keys you press appear.
      fails if: actions "key recorder: cannot create a listen-only event tap ..."

  [ ] Displays (built-in + external brightness, display registry)
      Settings shows your displays; external brightness works where it did before.
      proof:    displays "display <id> <kind> controllable=true ..."
      fails if: displays "display brightness unavailable: ..." / "external brightness unavailable: ..."

Step 5. When you're done, quit this build and relaunch your usual one (scripts/run-dev.sh).

If a check fails only in this build: add the narrowest entitlement that fixes it to
Resources/Edgy.entitlements, sign with --entitlements, re-run this script, and write the
entitlement and the failure it fixes in docs/RELEASING.md. Until then Edgy ships with none.
EOF
