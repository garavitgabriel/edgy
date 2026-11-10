#!/bin/bash
# Measures the running Edgy's idle cost: CPU % and idle wakeups/s averaged over a window (default
# 20 s) with `top -l`. Exits 1 when either is over the budget given.
#
#   scripts/measure-idle.sh [max-cpu-%] [max-wakeups-per-s] [seconds]
#   scripts/measure-idle.sh 0.5 50        # no window open
#   scripts/measure-idle.sh 3 150         # popover / Settings / onboarding open and idle
#
# Leave the trackpad and keyboard alone while it runs. Reads only; changes nothing.
set -euo pipefail

max_cpu="${1:-}"
max_wakeups="${2:-}"
seconds="${3:-20}"

pid="$(pgrep -x Edgy | head -n 1 || true)"
if [[ -z "$pid" ]]; then
  echo "Edgy is not running" >&2
  exit 2
fi

# One sample per second; the first sample has no delta, so take seconds+1 and drop it.
samples="$(top -l "$((seconds + 1))" -s 1 -pid "$pid" -stats pid,cpu,idlew 2>/dev/null |
  awk -v pid="$pid" '$1 == pid { print $2, $3 }' | tail -n "$seconds")"

read -r cpu wakeups <<<"$(echo "$samples" | awk '{ c += $1; w += $2; n++ } END { if (n) printf "%.2f %.0f", c / n, w / n; else print "nan nan" }')"

echo "Edgy pid $pid over ${seconds}s: CPU ${cpu}% · idle wakeups ${wakeups}/s"

status=0
if [[ -n "$max_cpu" ]] && awk -v a="$cpu" -v b="$max_cpu" 'BEGIN { exit !(a > b) }'; then
  echo "over budget: CPU ${cpu}% > ${max_cpu}%" >&2
  status=1
fi
if [[ -n "$max_wakeups" ]] && awk -v a="$wakeups" -v b="$max_wakeups" 'BEGIN { exit !(a > b) }'; then
  echo "over budget: wakeups ${wakeups}/s > ${max_wakeups}/s" >&2
  status=1
fi
exit "$status"
