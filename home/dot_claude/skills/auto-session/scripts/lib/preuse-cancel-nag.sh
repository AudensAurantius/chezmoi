#!/usr/bin/env bash
# preuse-cancel-nag.sh — invoked by the PreToolUse hook in the session's
# .claude/settings.local.json. If a nag-repeater is active for this session,
# kills it (= user has responded, tool call is about to proceed).
#
# Session-scoped: only fires in autonomous sessions, so no marker gating.
#
# Input: Claude Code passes a JSON payload on stdin describing the event.
# Expected: .session_id — per-invocation session UUID
#
# Environment:
#   AUTOSESSION_SLUG — session slug (set by run.sh)
#   AUTOSESSION_DIR  — session dir (set by run.sh)

set -euo pipefail

: "${AUTOSESSION_SLUG:?preuse-cancel-nag: AUTOSESSION_SLUG not set}"
: "${AUTOSESSION_DIR:?preuse-cancel-nag: AUTOSESSION_DIR not set}"

STATE_DIR="$AUTOSESSION_DIR/state"
[ -d "$STATE_DIR" ] || exit 0

payload="$(cat 2>/dev/null || true)"
session_id="$(echo "$payload" | jq -r '.session_id // empty' 2>/dev/null || true)"

pid_file="$STATE_DIR/nag-${session_id:-$AUTOSESSION_SLUG}.pid"
[ -f "$pid_file" ] || exit 0

pid="$(cat "$pid_file" 2>/dev/null || true)"
if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
  kill "$pid" 2>/dev/null || true
  sleep 0.2
  kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null || true
fi
rm -f "$pid_file"
