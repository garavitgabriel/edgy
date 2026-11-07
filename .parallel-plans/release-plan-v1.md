# Edgy v1 release plan (chief, 2026-11-07)

From "v0.5 signed off" to "public launch". It builds on Gabriel's GTM decisions (vault `ventures/active/edgy/gtm/README.md`): MIT source on GitHub, free to build yourself; **signed + notarized DMG with auto-updates = $5 lifetime** on `edgy.to` (bought); payments via the existing Stripe account (Payment Link → download page); no licence key at v1. Same app, same features on both paths.

## Where we are
- v0.5 build complete through batch 24. Batch 25 (final design polish) and batch 26 (Switch Apps opens on travel) are running.
- Packaging today: `scripts/bundle.sh` builds release + signs with the local **Apple Development** identity (dev only). `Info.plist` says `0.1.0` / build `1`. No hardened runtime, no entitlements file, no DMG, no updater, no LICENSE.
- Repo `garavitgabriel/edgy` is **private**.

## Decisions for Gabriel (one at a time, in this order)
| # | Decision | Recommendation | Why it matters |
|---|---|---|---|
| D1 | **Apple Developer Program** ($99/yr) — enrol now | Enrol now | Critical path: no Developer ID cert → no notarization → no paid DMG. Approval can take days. Also unblocks the Agent Charm Watch provisioning. |
| D2 | Auto-update: the standard open-source updater framework vs our own | The standard framework, pinned | Update code is security-critical (signed feeds, EdDSA verification, safe replace-and-relaunch). "Build our own tools" is right for scripts, wrong for this. It adds the only third-party dependency, which is a `Package.swift` change (chief) and needs a denylist check on its name. |
| D3 | Payments: Stripe (06 decision) vs a merchant of record (05 detail text) | Stripe Payment Link + Stripe Tax; check whether the account offers managed payments (MoR) first | The GTM file says both; the 11-06 decision wins unless MoR is available cheaply. VAT/sales tax is ours with plain Stripe. |
| D4 | Version for launch | `1.0.0` (build numbers monotonic from 100) | v0.5 → 1.0 says "finished, signed, supported". Pre-release DMGs for testers as `0.9.x`. |
| D5 | Launch date | After G1 + traces; set once D1 is approved | Everything else is under our control; D1 isn't. |

## Phases

### P0 — Close v0.5 (now → next 1–2 days)
1. Merge batches 25 + 26; rsync + relaunch on the MacBook Pro; Gabriel retests the Switch Apps top edge.
2. Design sign-off (design session reviews batch-25 shots).
3. **G1 device check** with the design session, on the MacBook Pro:
   - [ ] Menu-bar glyph V3 "Lit strip" at true size next to the real battery icon (watch: reads as a second battery → widen the strip gap)
   - [ ] Pad slab depth in the settings window
   - [ ] Glass over Gabriel's real wallpapers (light + dark)
   - [ ] Onboarding step 4 switch colour; Done → popover; live Accessibility flip
   - [ ] System volume indicator beside the step-2 mirror
   - [ ] Real app icons on tabs/chips (critique 22 must-fix) + an iconless app
   - [ ] Title-bar centring against real traffic lights; hover feel in the popover
   - [ ] Switch Apps: rest / tap / small drift open nothing; one step opens it
   - [ ] Gut check on split diagrams S9–S12 ("OO / OOO"?)
4. `/end-ship-train`-style integrated check on `main`; tag `v0.5.0`.

### P1 — Pre-launch engineering (batches 27–29, parallel where globs allow)
| Batch | Scope | Owner globs |
|---|---|---|
| 27 EDGY-TRACES | Gabriel records the 10 priority scenarios (`scripts/record-traces.md`); builder tunes hold stillness, swipe thresholds, end band against them, before/after per change | Gestures, Fixtures/traces, scripts/record-traces.md |
| 28 EDGY-KEYS | Right-hand modifiers (`KeyCombo` contract change — chief first), recorder swallows keys while recording (active tap) | Actions, EdgyRuntime, EdgyUI/Inspector recorder |
| 29 EDGY-HONEST | External brightness honesty ("Did the screen change?", per-display memory); `GestureContext.swipeZones` (contract, chief first); `showMenuBarIcon=false` needs a way back in (reopen settings by launching the app again) | Displays, EdgyRuntime, Gestures (after 27 merges) |
- Plus MacBook smoke runs (`smoke-actions` 17–28, `smoke-displays`) — Gabriel, ~20 min.

### P2 — Release pipeline (batch 30; runs in parallel with P1, needs D1 for the last step)
1. **Hardened runtime + entitlements**: `codesign --options runtime`. First verify every private-framework path still works under hardened runtime (multitouch, display services, native HUD, event taps); add only the entitlements a failure proves are needed, each documented.
2. `scripts/release.sh`: release build → bundle → sign with **Developer ID Application** → `notarytool submit --wait` → `stapler staple` → DMG (drag-to-Applications background from `docs/design/assets/`) → sign + notarize + staple the DMG → checksum. Credentials from the keychain profile, never in the repo.
3. Version from one source (`Info.plist` stamped by the script from a git tag).
4. Updater (per D2): feed on `edgy.to/appcast.xml`, EdDSA signing key in the keychain, "Check for Updates…" in the popover's menu (design session specs the row), quiet daily check.
5. Accessibility survives updates: confirm the designated requirement is stable across two notarized builds (install 1.0.0-rc1 → grant → update to rc2 → still granted).
6. Free path: `make app` (ad-hoc local build, documented trade-off: re-grant Accessibility after rebuilds).

### P3 — Public-readiness (Claude + Gabriel; parallel with P1–P2)
- Repo: README (two install paths, screenshots from build-shots/renders, "Edgy" name + icon not MIT note), `LICENSE` (MIT), CONTRIBUTING, issue templates, denylist check over full history before flipping public (`git log -p | grep -niE -f …`).
- Site `edgy.to`: landing per `docs/BRAND.md` § "Applying it outside the app" (GTM workstream 9), download page behind the Stripe Payment Link, appcast + DMG hosting.
- Launch copy: r/macapps, Show HN, LinkedIn; launch video (style pick pending in `gtm/video-styles.md`).

### P4 — Launch
Order (GTM): notarized build on edgy.to → repo public → same-day posts → Product Hunt a week later. Rollback: the updater feed can pull a bad build; keep the previous DMG live.

## Critical path
D1 (Apple approval) → P2 step 2 (notarize) → P2 step 5 (update keeps Accessibility) → launch. Everything else can run in parallel. **Enrolling today is the single highest-leverage action.**
