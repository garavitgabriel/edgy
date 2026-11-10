#!/usr/bin/env bash
# Build, sign, notarize and staple a distributable Edgy: build/release/Edgy.app and
# build/release/Edgy-<version>.dmg, plus its SHA-256. See docs/RELEASING.md.
#
# Usage: scripts/release.sh [--dry-run] [--skip-notarize]
#   --dry-run        print every step's command; run nothing
#   --skip-notarize  sign and package only (no upload); for testing the signature locally
#
# Needs: a "Developer ID Application" identity in the keychain, and (unless --skip-notarize)
# EDGY_NOTARY_PROFILE naming a notarytool keychain profile. Never signs ad-hoc or with the
# development identity. A notarized release must be built from a clean tree on a vX.Y.Z tag.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DRY_RUN=0
NOTARIZE=1
OUT="build/release"
APP="$OUT/Edgy.app"

while (($# > 0)); do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --skip-notarize) NOTARIZE=0 ;;
    -h | --help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "error: unknown option: $1 (see --help)" >&2
      exit 2
      ;;
  esac
  shift
done

fail() {
  echo "error: $*" >&2
  exit 1
}

# Prints a command, and runs it unless this is a dry run.
run() {
  printf '  +'
  printf ' %q' "$@"
  printf '\n'
  ((DRY_RUN == 1)) || "$@"
}

stage() { echo "==> $*"; }

read -r VERSION BUILD COMMIT <<<"$("$ROOT/scripts/bundle.sh" --print-version)"
DMG="$OUT/Edgy-$VERSION.dmg"
ZIP="$OUT/Edgy-$VERSION-notarize.zip"
IDENTITY=""
PROFILE="${EDGY_NOTARY_PROFILE:-}"

preflight() {
  stage "Preflight"
  IDENTITY="$(security find-identity -v -p codesigning | awk -F'"' '/"Developer ID Application:/ { print $2; exit }')"
  if [[ -z "$IDENTITY" ]]; then
    ((DRY_RUN == 1)) || fail "no \"Developer ID Application\" signing identity in the keychain (see docs/RELEASING.md)."
    IDENTITY="Developer ID Application: <not found in keychain>"
    echo "  (dry run) no Developer ID Application identity; a real run stops here"
  fi
  if ((NOTARIZE == 1)) && [[ -z "$PROFILE" ]]; then
    ((DRY_RUN == 1)) || fail "EDGY_NOTARY_PROFILE is not set; name your notarytool keychain profile (see docs/RELEASING.md)."
    PROFILE="<EDGY_NOTARY_PROFILE>"
    echo "  (dry run) EDGY_NOTARY_PROFILE is not set; a real run stops here"
  fi
  if ((NOTARIZE == 1)) && [[ "$VERSION" == *-dev+* ]]; then
    ((DRY_RUN == 1)) || fail "HEAD is not a clean vX.Y.Z tag (version reads $VERSION); tag the release commit first."
    echo "  (dry run) version $VERSION is not a release tag; a real run stops here"
  fi
  echo "  Edgy $VERSION ($BUILD) $COMMIT"
}

build_app() {
  stage "Building and bundling (unsigned) into $APP"
  run "$ROOT/scripts/bundle.sh" --out "$APP" --sign none
}

sign_app() {
  stage "Signing the app with Developer ID, hardened runtime"
  local flags=(--force --options runtime --timestamp)
  # Entitlements only if one has been proven necessary (see docs/RELEASING.md); none by default.
  [[ -f Resources/Edgy.entitlements ]] && flags+=(--entitlements Resources/Edgy.entitlements)
  run codesign "${flags[@]}" --sign "$IDENTITY" "$APP" ||
    fail "codesign of the app failed."
  run codesign --verify --strict --deep --verbose=2 "$APP" ||
    fail "the app's signature does not verify."
}

notarize_app() {
  stage "Notarizing and stapling the app"
  run ditto -c -k --keepParent "$APP" "$ZIP" || fail "could not zip the app for notarization."
  run xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait ||
    fail "notarization of the app failed (xcrun notarytool log <submission id> --keychain-profile \"$PROFILE\")."
  run rm -f "$ZIP"
  run xcrun stapler staple "$APP" || fail "stapling the app failed."
  run spctl --assess --type execute --verbose=2 "$APP" || fail "Gatekeeper rejects the stapled app."
}

make_dmg() {
  stage "Building the disk image"
  run "$ROOT/scripts/make-dmg.sh" "$APP" "$DMG" || fail "make-dmg.sh failed."
}

sign_dmg() {
  stage "Signing the disk image"
  run codesign --force --timestamp --sign "$IDENTITY" "$DMG" || fail "codesign of the DMG failed."
  run codesign --verify --strict --verbose=2 "$DMG" || fail "the DMG's signature does not verify."
}

notarize_dmg() {
  stage "Notarizing and stapling the disk image"
  run xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait ||
    fail "notarization of the DMG failed (xcrun notarytool log <submission id> --keychain-profile \"$PROFILE\")."
  run xcrun stapler staple "$DMG" || fail "stapling the DMG failed."
  run xcrun stapler validate "$DMG" || fail "the DMG's ticket does not validate."
  run spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG" ||
    fail "Gatekeeper rejects the stapled DMG."
}

checksum() {
  stage "Checksum"
  if ((DRY_RUN == 1)); then
    run shasum -a 256 "$DMG"
  else
    (cd "$OUT" && shasum -a 256 "$(basename "$DMG")" | tee "$(basename "$DMG").sha256")
  fi
}

((DRY_RUN == 1)) && echo "Dry run: printing the plan; nothing is built, signed or uploaded."
preflight
build_app
sign_app
if ((NOTARIZE == 1)); then notarize_app; else stage "Skipping notarization (--skip-notarize)"; fi
make_dmg
sign_dmg
if ((NOTARIZE == 1)); then notarize_dmg; else
  echo "  note: not notarized; Gatekeeper will refuse this build on other Macs."
fi
checksum
echo "==> Done: $DMG"
echo "Edgy $VERSION ($BUILD) $COMMIT"
