#!/usr/bin/env bash
# notify-dispatcher.sh — invoked by the Notification hook in the session's
# .claude/settings.local.json. Fires a soft toast and spawns a detached
# nag-repeater.
#
# Session-scoped hooks mean this only runs when Claude Code is launched from
# an autonomous session dir. No marker-gating needed — the hook's presence in
# the session's settings.local.json IS the signal that we're in an autonomous
# session.
#
# Input: Claude Code passes a JSON payload on stdin describing the event.
# Expected fields (per Claude Code hook docs):
#   .session_id      — per-invocation session UUID (for correlating with nag PID)
#   .message         — the notification message (optional)
#   .hook_event_name — "Notification"
#
# Environment:
#   AUTOSESSION_SLUG — session slug (set by run.sh)
#   AUTOSESSION_DIR  — session dir (set by run.sh)

set -euo pipefail

: "${AUTOSESSION_SLUG:?notify-dispatcher: AUTOSESSION_SLUG not set}"
: "${AUTOSESSION_DIR:?notify-dispatcher: AUTOSESSION_DIR not set}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$AUTOSESSION_DIR/state"
mkdir -p "$STATE_DIR"

# Read stdin JSON; tolerate missing fields.
payload="$(cat 2>/dev/null || true)"
session_id="$(echo "$payload" | jq -r '.session_id // empty' 2>/dev/null || true)"
message="$(echo "$payload" | jq -r '.message // "Claude Code needs your attention"' 2>/dev/null || echo "Claude Code needs your attention")"

# PID file keyed on the Claude Code session_id, not the autosession slug, so
# the preuse-cancel hook can target the right nag even if there are multiple
# autosessions running simultaneously (one-session-per-dir, but defensive).
pid_file="$STATE_DIR/nag-${session_id:-$AUTOSESSION_SLUG}.pid"

# Fire the initial (soft) toast.
# Sound: prefer IM (soft chime); fall back to Reminder if shim's ValidSet is narrower.
if ! wsl-notify-send --sound=IM "Claude Code [$AUTOSESSION_SLUG]: $message" 2>/dev/null; then
  wsl-notify-send --sound=Reminder "Claude Code [$AUTOSESSION_SLUG]: $message" 2>/dev/null || true
fi

# If a nag-repeater is already running for this session, leave it alone.
if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
  exit 0
fi

# Spawn a detached nag-repeater. It will re-fire the toast every 60s up to the
# hard cap (30 iterations). The PreToolUse hook kills it when the user responds.
nohup "$SCRIPT_DIR/nag-repeater.sh" "${session_id:-$AUTOSESSION_SLUG}" "$message" "$pid_file" \
  >/dev/null 2>&1 &
disown
