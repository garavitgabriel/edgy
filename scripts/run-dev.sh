#!/usr/bin/env bash
# Bundle, sign and launch the dev build. Quits a running copy first so the new build takes over.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/bundle.sh"

if pgrep -x Edgy >/dev/null; then
  echo "==> Quitting running Edgy"
  osascript -e 'tell application id "com.garavit.edgy" to quit' >/dev/null 2>&1 || pkill -x Edgy || true
  sleep 1
fi

echo "==> Launching"
open "$ROOT/build/Edgy.app"
echo "Logs: log stream --predicate 'subsystem == \"com.garavit.edgy\"' --level debug"
