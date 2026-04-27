#!/usr/bin/env bash
# nag-repeater.sh — detached background process that re-fires a category-(a)
# toast every 60s while the user is blocked, up to a hard cap. Killed by
# preuse-cancel-nag.sh when the user responds to Claude Code.
#
# Usage: nag-repeater.sh <session-id> <message> <pid-file>
#
# Writes its own PID to <pid-file> on start; removes it on exit.

set -euo pipefail

SESSION_ID="${1:?session-id required}"
MESSAGE="${2:?message required}"
PID_FILE="${3:?pid-file required}"

MAX_ITERATIONS="${AUTO_SESSION_NAG_MAX:-30}"
INTERVAL_SECONDS="${AUTO_SESSION_NAG_INTERVAL:-60}"
SLUG="${AUTOSESSION_SLUG:-autosession}"

echo $$ > "$PID_FILE"
trap 'rm -f "$PID_FILE"' EXIT INT TERM

for i in $(seq 1 "$MAX_ITERATIONS"); do
  sleep "$INTERVAL_SECONDS"

  # If the PID file no longer exists or has been taken over by another process,
  # bail. (preuse-cancel-nag.sh removes the PID file as part of its kill.)
  if [ ! -f "$PID_FILE" ] || [ "$(cat "$PID_FILE" 2>/dev/null || echo "")" != "$$" ]; then
    exit 0
  fi

  prefix="Still waiting ($((i * INTERVAL_SECONDS / 60))m)"
  if ! wsl-notify-send --sound=IM "Claude Code [$SLUG]: $prefix — $MESSAGE" 2>/dev/null; then
    wsl-notify-send --sound=Reminder "Claude Code [$SLUG]: $prefix — $MESSAGE" 2>/dev/null || true
  fi
done

wsl-notify-send --sound=Reminder "Claude Code [$SLUG]: nag cap reached; waiting silently from here." 2>/dev/null || true
