# Releasing Edgy

How a signed, notarized Edgy gets built. Everything lands in `build/release/`; nothing here touches the dev build at `build/Edgy.app`.

## Prerequisites (once per Mac)

1. **Developer ID Application certificate** in the login keychain (Apple Developer Program → Certificates → Developer ID Application). Check:
   ```bash
   security find-identity -v -p codesigning | grep "Developer ID Application"
   ```
2. **A notary keychain profile.** Create an app-specific password at account.apple.com, then:
   ```bash
   xcrun notarytool store-credentials "<profile-name>" \
     --apple-id "<your Apple ID email>" \
     --team-id "<your 10-character team ID>" \
     --password "<app-specific password>"
   ```
   The credentials stay in your keychain. Tell the scripts which profile to use:
   ```bash
   export EDGY_NOTARY_PROFILE="<profile-name>"
   ```
3. Xcode command-line tools (`swift`, `codesign`, `xcrun notarytool`, `xcrun stapler`, `hdiutil`).

Never commit a certificate hash, team ID, Apple ID or password to this repo.

## Version

One source: the git tag. `scripts/bundle.sh` stamps the *copied* `Info.plist`, never `Resources/Info.plist`.

| Checkout | `CFBundleShortVersionString` | `CFBundleVersion` |
|---|---|---|
| clean tree, HEAD exactly on `v1.2.0` | `1.2.0` | commit count |
| anything else (after a tag, or dirty) | `1.2.0-dev+<short sha>` (nearest `v*` tag) | commit count |
| no `v*` tag at all | `0.0.0-dev+<short sha>` | commit count |

`scripts/bundle.sh --print-version` prints `version build commit` for the current checkout. Every bundle ends with `Edgy <version> (<build>) <commit>`.

## Release steps

1. Merge to `main`; `swift build && swift test && swift format lint --strict -r Sources Tests Package.swift` passes.
2. Tag and push the tag: `git tag v1.2.0 && git push origin v1.2.0`.
3. Rehearse: `scripts/release.sh --dry-run` prints every command and runs none.
4. Release: `make release` (or `scripts/release.sh`). Stages, each stopping with a clear message on failure:
   1. preflight: Developer ID identity, `EDGY_NOTARY_PROFILE`, a clean `vX.Y.Z` tag
   2. release build, bundled unsigned into `build/release/Edgy.app`, version stamped
   3. sign the app: Developer ID, `--options runtime --timestamp`; `codesign --verify --strict --deep`
   4. zip with `ditto`, `notarytool submit --wait`, `stapler staple` the app, `spctl --assess`
   5. `scripts/make-dmg.sh`: `Edgy-<version>.dmg` with the app and an Applications alias
   6. sign the DMG, `notarytool submit --wait`, `stapler staple`, `stapler validate`, `spctl --assess`
   7. SHA-256, printed and written to `Edgy-<version>.dmg.sha256`

   The app is notarized and stapled *before* it goes into the DMG, so the copy a user drags out carries its own ticket and opens offline.
5. Upload the DMG and its checksum; keep the previous DMG available.

`scripts/release.sh --skip-notarize` signs and packages without uploading; Gatekeeper refuses that build on other Macs, so it is for checking the signature only.

## Verify a download on a clean Mac

```bash
shasum -a 256 Edgy-1.2.0.dmg                     # matches the published checksum
xcrun stapler validate Edgy-1.2.0.dmg            # "The validate action worked!"
spctl --assess --type open --context context:primary-signature -v Edgy-1.2.0.dmg   # accepted, Notarized Developer ID
hdiutil attach -nobrowse -readonly Edgy-1.2.0.dmg  # note the mount point it prints
xcrun stapler validate "/Volumes/Edgy/Edgy.app"
spctl --assess --type execute -v "/Volumes/Edgy/Edgy.app"  # accepted, Notarized Developer ID
codesign --display --verbose=2 "/Volumes/Edgy/Edgy.app"     # flags=0x10000(runtime)
hdiutil detach "/Volumes/Edgy"
```
Then drag to Applications, open it, and confirm the first launch shows no "unidentified developer" warning.

## Rollback

- Put the previous DMG back on the download page; the old tag still rebuilds it exactly.
- Never reuse a version number: fix forward with a new tag (`v1.2.1`). The build number (commit count) only goes up.
- A notarized build can't be un-notarized by us; if a build is dangerous, ask Apple to revoke the ticket and ship a fixed version.

## Hardened runtime and entitlements

Notarization requires the hardened runtime. Edgy loads private frameworks by name at runtime (touch input, display brightness), talks to the system indicator over XPC and installs event taps. All of that comes from `/System`, which library validation allows, so **Edgy currently ships with no entitlements**.

That is to be proven, not assumed: `scripts/smoke-hardened.sh` builds `build/release/Edgy.app` with the development identity plus `--options runtime` and lists each check with the log line that proves it. If a check fails, the fix goes in `Resources/Edgy.entitlements` (both `bundle.sh` and `release.sh` sign with it whenever it exists), and the entitlement is recorded here as *entitlement → the failure it fixes*.

| Entitlement | Failure it fixes |
|---|---|
| (none yet) | |

## Free path

`make app` builds `build/release/Edgy.app` without a paid account: signed with your Apple Development identity if you have one, otherwise ad-hoc. With an ad-hoc signature macOS treats every rebuild as a new app, so Accessibility has to be granted again after each one. `make dmg` wraps it in an unsigned disk image. Neither installs nor launches anything. `make clean` removes `build/release/`.

## Not automated yet

- **Auto-update feed.** No in-app updater or update feed exists yet; users download new versions by hand.
- **Accessibility across updates.** Confirming the grant survives an update between two notarized builds (same designated requirement) is a manual check on the first two release candidates.
- **Upload.** Putting the DMG and checksum on the website is manual.
- **DMG background.** The disk image has no custom background or window layout.
