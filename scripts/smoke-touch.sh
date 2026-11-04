#!/usr/bin/env bash
# Manual smoke test for live touch input. Run by a human on real hardware — never from CI/tests.
#
#   scripts/smoke-touch.sh            # devices + 15 s of live frames
#   LIVE_SECONDS=30 scripts/smoke-touch.sh
#   scripts/smoke-touch.sh start-check  # answers "is the device-start call required?"
set -euo pipefail
cd "$(dirname "$0")/.."

LIVE_SECONDS="${LIVE_SECONDS:-15}"

echo "== Permission checklist =="
cat <<'EOF'
  [ ] Reading raw touches needs no permission (if `live` shows no frames, see the start-check below).
  [ ] Pointer guard (event tap) + typing monitor need Accessibility:
      System Settings → Privacy & Security → Accessibility → enable the signed Edgy build
      (and your terminal app, when running edgy-trace from it).
  [ ] Dev builds must be signed with the local "Apple Development" identity so the grant survives rebuilds.
EOF
echo

echo "== Build =="
swift build --product edgy-trace
BIN="$(swift build --show-bin-path)/edgy-trace"
echo

echo "== Devices =="
"$BIN" devices
echo

if [[ "${1:-}" == "start-check" ]]; then
  echo "== Start check: WITH the device-start call (default) — touch the trackpad for 8 s =="
  "$BIN" live --seconds 8 | tail -n 5
  echo
  echo "== Start check: WITHOUT the device-start call — touch the trackpad for 8 s =="
  EDGY_MT_SKIP_START=1 "$BIN" live --seconds 8 | tail -n 5
  echo
  echo "If the second run printed no frame lines, the start call is required. Note the answer in the done report."
  exit 0
fi

echo "== Live frames for ${LIVE_SECONDS}s — touch, slide, rest a palm; ctrl-c to stop early =="
echo "   Each line: time #frame dev n=<contacts> [id state (x,y) v(dx,dy) major×minor mm]"
"$BIN" live --seconds "$LIVE_SECONDS"
echo
echo "== Also check by hand =="
cat <<'EOF'
  [ ] Unplug + replug an external trackpad while `edgy-trace live` runs → "devices changed" printed twice, frames resume.
  [ ] Sleep + wake the Mac while `edgy-trace live` runs → frames resume after wake without restarting.
  [ ] A resting finger shows ~8–15 mm major axis; a resting palm noticeably larger (validates the mm conversion).
EOF
