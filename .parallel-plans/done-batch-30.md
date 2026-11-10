# Done — batch 30 (EDGY-RELEASE: release pipeline up to notarization)

## Brief items
- [x] **1. One version source.** `scripts/bundle.sh` derives the version from the git tag and stamps only the copied `Info.plist` (`Resources/Info.plist` unchanged). `--print-version` prints `version build commit`; every bundle ends with `Edgy <version> (<build>) <commit>`. Demonstrated (scratch clone, throwaway tag, shared tags untouched):
  - off a tag: `0.5.0-dev+6d567e3 295 6d567e3`
  - on `v9.9.9`, clean: `9.9.9 295 6d567e3`
  - on `v9.9.9`, tracked file modified: `9.9.9-dev+6d567e3 295 6d567e3`
  - no `v*` tag at all falls back to `0.0.0-dev+<sha>` (code path; this repo has `v0.5.0`)
- [x] **2. `scripts/release.sh`.** Stages as functions, each with its own failure message: preflight → build/bundle unsigned → Developer ID sign (`--options runtime --timestamp`) + `codesign --verify --strict --deep` → zip, `notarytool submit --wait`, `stapler staple` app, `spctl --assess` → `make-dmg.sh` → sign DMG → notarize + staple + `stapler validate` + `spctl` DMG → SHA-256 (printed + `.sha256` file). `--dry-run` prints every command and runs none; `--skip-notarize` signs and packages only. Without a Developer ID identity it exits 1 with one line; never falls back to ad-hoc or development signing. A notarized run also requires a clean `vX.Y.Z` tag.
  - Order deviates slightly from the brief's list on purpose (it matches `release-plan-v1.md` § P2.2): the app is notarized and stapled **before** it goes into the DMG, then the DMG is notarized separately. Stapling the local app after making the DMG would leave the copy inside the DMG unstapled. `spctl --assess` runs only after stapling because it rejects a Developer ID app that isn't notarized yet.
- [x] **3. `scripts/make-dmg.sh`.** `hdiutil` only (plus `ditto`, `xattr`): writable HFS+ image → volume icon (`.VolumeIcon.icns` from `Resources/AppIcon.icns` + custom-icon Finder flag) → UDZO. Contents: `Edgy.app`, `Applications -> /Applications`. Volume name "Edgy". No background image (optional; listed under "not automated yet" in RELEASING.md).
- [~] **4. Hardened runtime, proven not assumed.** `scripts/smoke-hardened.sh` written and its build step run here: `build/release/Edgy.app` signed with the development identity shows `flags=0x10000(runtime)`, entitlements empty. **The behavioural checks are unverified; they need the human** (quit Edgy, launch the hardened build; I may not). No entitlements file was added because no check has failed yet. Expectation: none needed (all private frameworks and the XPC helper come from `/System`, which library validation allows; event taps are TCC, not hardened runtime).
- [x] **5. `Makefile`.** `make app` (dev identity, else ad-hoc with the re-grant note; output `build/release/Edgy.app`; never installs or launches), `make dmg`, `make release`, `make clean` (removes `build/release/` only).
- [x] **6. `docs/RELEASING.md`.** Prerequisites (Developer ID, `notarytool store-credentials` with placeholders, `EDGY_NOTARY_PROFILE`), version table, release steps, verify on a clean Mac, rollback, hardened runtime + entitlements table (empty), free path, not automated yet (update feed, Accessibility across updates, upload, DMG background).

## What ran here
- `scripts/release.sh --dry-run` → full plan, exit 0 (no Developer ID on this Mac, so placeholders are printed).
- `EDGY_NOTARY_PROFILE=x scripts/release.sh` and `scripts/release.sh --skip-notarize` → `error: no "Developer ID Application" signing identity in the keychain (see docs/RELEASING.md).`, exit 1.
- `make dmg` (runs `make app`) → `build/release/Edgy.app` (signed with Apple Development, version 0.5.0-dev+8fed0ef build 294) and `build/release/Edgy-0.5.0-dev+8fed0ef.dmg`. Mounted with `hdiutil attach -nobrowse -readonly -mountpoint <tmp>`: `.VolumeIcon.icns`, `Applications -> /Applications`, `Edgy.app` (signature verifies), volume "Edgy", HFS+, custom-icon flag set; detached.
- `scripts/smoke-hardened.sh` build + signature steps (above).
- `bash -n` on all four scripts (shellcheck not installed); `set -euo pipefail` everywhere; no hard-coded home paths; bash 3.2 compatible.
- `swift build && swift test && swift format lint --strict -r Sources Tests Package.swift` → pass (303 tests). No Swift changed.
- Denylist grep → nothing.
- `build/Edgy.app` and the running Edgy were never touched. Bare `bundle.sh` (what `run-dev.sh` calls) behaves as before: `build/Edgy.app`, Apple Development, loud failure without it, plus the version stamp.

## Needs the Developer ID (not run)
Everything after preflight in a real `scripts/release.sh`: Developer ID signing, both notarytool submissions, stapling, `spctl` on notarized artifacts, DMG signing, checksum of a signed DMG. Also P2 step 5 (Accessibility survives an update between two notarized builds).

Note: on this macOS, `hdiutil attach` prints a deprecation warning pointing at `diskutil image attach`; it still works.

## Smoke-hardened checklist (for Gabriel)
Run `scripts/smoke-hardened.sh`, quit Edgy, `open build/release/Edgy.app`, watch `/usr/bin/log stream --predicate 'subsystem == "com.garavit.edgy"' --info`:
- [ ] Touch input: mirror shows fingers; touch `device <id> registered`, `first frame received` (fail: `multitouch unavailable`)
- [ ] Event taps: pointer `pointer guard: event tap installed` (fail: `event tap unavailable`, typing `typing monitor could not be installed`)
- [ ] A gesture fires: engine `Gesture <kind> <phase> at <zone> → <action>`, no `Action … failed`
- [ ] Volume + native indicator (fail: actions `HUD unavailable`)
- [ ] Brightness + native indicator (fail: actions `brightness unavailable`)
- [ ] Hold Keys: engine `Releasing hold …` on lift
- [ ] Switch Apps: actions `app switcher: selecting (…)`
- [ ] Key recorder (fail: `key recorder: cannot create a listen-only event tap`)
- [ ] Displays: displays `display <id> <kind> controllable=true` (fail: `display brightness unavailable` / `external brightness unavailable`)
Then quit it and run `scripts/run-dev.sh` to get back to the usual build. Any failure → narrowest entitlement in `Resources/Edgy.entitlements`, recorded in RELEASING.md.
