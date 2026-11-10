#!/usr/bin/env bash
# Build a drag-to-Applications disk image for Edgy with hdiutil only.
# The image holds the app and an Applications alias, is named "Edgy", and carries the app
# icon as its volume icon. It does not sign anything: release.sh signs the DMG.
#
# Usage: scripts/make-dmg.sh [APP] [DMG]
#   APP  the app to package (default: build/release/Edgy.app)
#   DMG  the image to write (default: build/release/Edgy-<version>.dmg, version read from APP)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

die() {
  echo "error: $*" >&2
  exit 1
}

APP="${1:-$ROOT/build/release/Edgy.app}"
[[ -d "$APP" ]] || die "no app at $APP (run 'make app' first)"
[[ "$APP" == /* ]] || APP="$ROOT/$APP"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="${2:-$ROOT/build/release/Edgy-$VERSION.dmg}"
[[ "$DMG" == /* ]] || DMG="$ROOT/$DMG"
ICON="$ROOT/Resources/AppIcon.icns"
VOLNAME="Edgy"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/edgy-dmg.XXXXXX")"
MOUNT="$WORK/mount"
ATTACHED=0
cleanup() {
  if ((ATTACHED == 1)); then hdiutil detach "$MOUNT" -quiet || hdiutil detach "$MOUNT" -force -quiet || true; fi
  rm -rf "$WORK"
}
trap cleanup EXIT

echo "==> Staging $(basename "$APP")"
mkdir -p "$WORK/stage" "$MOUNT"
ditto "$APP" "$WORK/stage/Edgy.app"
ln -s /Applications "$WORK/stage/Applications"

echo "==> Creating a writable image"
hdiutil create -quiet -volname "$VOLNAME" -srcfolder "$WORK/stage" -fs HFS+ -format UDRW \
  -ov "$WORK/rw.dmg"

echo "==> Setting the volume icon"
hdiutil attach -quiet -nobrowse -noautoopen -readwrite -mountpoint "$MOUNT" "$WORK/rw.dmg"
ATTACHED=1
cp "$ICON" "$MOUNT/.VolumeIcon.icns"
# FinderInfo with the kHasCustomIcon flag (0x0400) set: Finder then shows .VolumeIcon.icns.
xattr -wx com.apple.FinderInfo \
  "0000000000000000040000000000000000000000000000000000000000000000" "$MOUNT"
sync
hdiutil detach -quiet "$MOUNT"
ATTACHED=0

echo "==> Compressing to $DMG"
mkdir -p "$(dirname "$DMG")"
rm -f "$DMG"
hdiutil convert -quiet "$WORK/rw.dmg" -format UDZO -imagekey zlib-level=9 -o "$DMG"

echo "==> Done: $DMG"
