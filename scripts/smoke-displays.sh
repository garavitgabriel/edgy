#!/usr/bin/env bash
# Manual smoke test for display brightness. HUMAN-RUN ONLY — never from CI or an agent.
#
# Builds edgy-displays, lists every display, then for each controllable one reads its brightness,
# nudges it down 10% and back, and confirms the read-back. Asks before every step that changes
# anything, and restores each display's original brightness on exit (including Ctrl-C).
#
# Record in the done report: the monitor model, how it is connected (port, cable, adapter or dock),
# and whether DDC/CI worked.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ask() {
  local answer
  read -r -p "$1 [y/N] " answer
  [[ "$answer" == [yY]* ]]
}

echo "Edgy displays smoke test"
echo "This reads and changes real display brightness (and puts it back)."
ask "Continue?" || exit 0

swift build --product edgy-displays
BIN="$ROOT/.build/debug/edgy-displays"

echo
echo "== Displays"
"$BIN" list

# Original levels of every display we touch, restored on exit.
RESTORE_IDS=()
RESTORE_LEVELS=()
restore() {
  local i
  for i in "${!RESTORE_IDS[@]}"; do
    "$BIN" set "${RESTORE_IDS[$i]}" "${RESTORE_LEVELS[$i]}" >/dev/null 2>&1 || true
  done
}
trap restore EXIT

controllable=$("$BIN" list | awk -F'\t' '$4 == "controllable" { print $1 }')
if [[ -z "$controllable" ]]; then
  echo
  echo "No controllable displays. The reasons above are what the settings screen will show."
  exit 0
fi

for id in $controllable; do
  echo
  echo "== Display $id"
  level=$("$BIN" get "$id")
  echo "current brightness: $level"
  RESTORE_IDS+=("$id")
  RESTORE_LEVELS+=("$level")

  if ask "Nudge display $id down 10% and back? Watch the screen."; then
    "$BIN" nudge "$id"
    echo "read-back: $("$BIN" get "$id")"
    ask "Did you see it dim and come back?" && echo "  ok" || echo "  NOT SEEN — note it in the report"
  fi

  if ask "Set display $id to 30% for two seconds, then restore?"; then
    "$BIN" set "$id" 0.3
    sleep 2
    "$BIN" set "$id" "$level"
    echo "restored to $level"
  fi
done

if ask "Show the active display (move the pointer to another screen first if you have one)?"; then
  "$BIN" list | grep '(active)' || echo "no active display reported"
fi

echo
echo "Done. Brightness restored."
