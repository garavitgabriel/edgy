#!/usr/bin/env bash
# Build a release Edgy.app, stamp its version, and sign it.
#
# With no arguments (what run-dev.sh uses) this builds build/Edgy.app and signs it with the
# local "Apple Development" identity, so Accessibility grants survive rebuilds. No identity
# means a loud failure, never an ad-hoc signature.
#
# Usage: scripts/bundle.sh [--out PATH] [--sign dev|dev-or-adhoc|none] [--runtime]
#        scripts/bundle.sh --print-version
#   --out PATH       where to put the app (default: build/Edgy.app)
#   --sign dev       sign with "Apple Development"; fail without it (default)
#   --sign dev-or-adhoc
#                    as dev, but fall back to an ad-hoc signature with a printed note
#                    (the free `make app` path only)
#   --sign none      leave the app unsigned (release.sh signs it with Developer ID)
#   --runtime        sign with the hardened runtime (--options runtime)
#   --print-version  print "version build commit" for the checkout and exit
#
# Version: one source, the git tag. HEAD exactly on vX.Y.Z with a clean tree reads X.Y.Z;
# anything else reads X.Y.Z-dev+<short sha> from the nearest v* tag (0.0.0 with none).
# The build number is the commit count (monotonic). Only the copied Info.plist is stamped.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP="$ROOT/build/Edgy.app"
SIGN="dev"
RUNTIME=0

die() {
  echo "error: $*" >&2
  exit 1
}

# Prints "version build commit" for the checkout at $ROOT.
edgy_version() {
  local commit build tag dirty=0
  commit="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)" || die "not a git checkout: $ROOT"
  build="$(git -C "$ROOT" rev-list --count HEAD)"
  [[ -n "$(git -C "$ROOT" status --porcelain --untracked-files=no)" ]] && dirty=1
  if tag="$(git -C "$ROOT" describe --tags --exact-match --match 'v[0-9]*' HEAD 2>/dev/null)" && ((dirty == 0)); then
    echo "${tag#v} $build $commit"
    return
  fi
  tag="$(git -C "$ROOT" describe --tags --abbrev=0 --match 'v[0-9]*' HEAD 2>/dev/null || echo v0.0.0)"
  echo "${tag#v}-dev+$commit $build $commit"
}

while (($# > 0)); do
  case "$1" in
    --out)
      [[ $# -ge 2 ]] || die "--out needs a path"
      APP="$2"
      shift 2
      ;;
    --sign)
      [[ $# -ge 2 ]] || die "--sign needs dev, dev-or-adhoc or none"
      SIGN="$2"
      shift 2
      ;;
    --runtime)
      RUNTIME=1
      shift
      ;;
    --print-version)
      edgy_version
      exit 0
      ;;
    -h | --help)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) die "unknown option: $1 (see --help)" ;;
  esac
done

case "$SIGN" in dev | dev-or-adhoc | none) ;; *) die "--sign must be dev, dev-or-adhoc or none" ;; esac
[[ "$APP" == *.app ]] || die "--out must end in .app: $APP"
[[ "$APP" == /* ]] || APP="$ROOT/$APP"

read -r VERSION BUILD COMMIT <<<"$(edgy_version)"

echo "==> Building release binary"
swift build -c release --product Edgy
BIN_DIR="$(swift build -c release --product Edgy --show-bin-path)"

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Edgy" "$APP/Contents/MacOS/Edgy"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
# SwiftPM resource bundles (e.g. EdgyUI's glyph PDFs); Bundle.module finds them in Contents/Resources.
for bundle in "$BIN_DIR"/*.bundle; do
  [[ -e "$bundle" ]] && cp -R "$bundle" "$APP/Contents/Resources/"
done

echo "==> Stamping version"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist" >/dev/null

SIGN_FLAGS=(--force)
((RUNTIME == 1)) && SIGN_FLAGS+=(--options runtime)

if [[ "$SIGN" == "none" ]]; then
  echo "==> Leaving the app unsigned"
else
  echo "==> Signing"
  IDENTITY="$(security find-identity -v -p codesigning | awk '/"Apple Development/ { print $2; exit }')"
  if [[ -n "$IDENTITY" ]]; then
    codesign "${SIGN_FLAGS[@]}" --sign "$IDENTITY" "$APP"
  elif [[ "$SIGN" == "dev-or-adhoc" ]]; then
    echo "note: no \"Apple Development\" identity found; signing ad-hoc." >&2
    echo "      macOS ties the Accessibility grant to the signature, so re-grant Accessibility" >&2
    echo "      (System Settings > Privacy & Security > Accessibility) after every rebuild." >&2
    codesign "${SIGN_FLAGS[@]}" --sign - "$APP"
  else
    echo "error: no valid \"Apple Development\" code-signing identity found." >&2
    echo "       Sign in to Xcode with your Apple ID (Settings > Accounts) to create one." >&2
    echo "       Refusing to sign ad-hoc: Accessibility grants would not survive rebuilds." >&2
    exit 1
  fi
  codesign --verify --strict --verbose=2 "$APP"
fi

echo "==> Done: $APP"
echo "Edgy $VERSION ($BUILD) $COMMIT"
