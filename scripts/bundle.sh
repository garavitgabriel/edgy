#!/usr/bin/env bash
# Build a release Edgy.app into build/ and sign it with the local "Apple Development" identity,
# so Accessibility grants survive rebuilds. Never signs ad-hoc: no identity means a loud failure.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP="$ROOT/build/Edgy.app"

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
plutil -lint "$APP/Contents/Info.plist" >/dev/null

echo "==> Signing"
IDENTITY="$(security find-identity -v -p codesigning | awk '/"Apple Development/ { print $2; exit }')"
if [[ -z "$IDENTITY" ]]; then
  echo "error: no valid \"Apple Development\" code-signing identity found." >&2
  echo "       Sign in to Xcode with your Apple ID (Settings > Accounts) to create one." >&2
  echo "       Refusing to sign ad-hoc: Accessibility grants would not survive rebuilds." >&2
  exit 1
fi
codesign --force --sign "$IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"

echo "==> Done: $APP"
