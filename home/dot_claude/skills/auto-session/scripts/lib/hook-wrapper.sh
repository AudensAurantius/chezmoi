#!/usr/bin/env bash
# hook-wrapper.sh — two-record watchdog wrapper around a "real" hook executable.
#
# Design goals:
# - Write TWO log records per hook invocation (hook_started, hook_ended) so a
#   hung hook is detectable by absence of an ended record correlated with the
#   started record.
# - Preserve Claude Code's hook-response protocol: the real hook's stdout must
#   reach Claude Code unaltered (so JSON like {"continue":true,"suppressOutput":true}
#   flows through). Stderr is captured into the log, not mirrored to Claude.
# - Watchdog timeout: if the hook doesn't return within AUTOSESSION_HOOK_TIMEOUT
#   seconds (default 30), SIGTERM the hook and record the timeout in the ended record.
# - Serialize log writes via flock so concurrent hook invocations don't interleave.
# - Release lock and kill the watchdog cleanly on all exit paths (including traps).
#
# Invocation contract:
#   hook-wrapper.sh <real-hook-path> [real-hook-args...]
#
# Environment:
#   AUTOSESSION_SLUG         — session slug (set by run.sh; used in log records)
#   AUTOSESSION_DIR          — session dir (set by run.sh; logs land at $DIR/hook.log)
#   AUTOSESSION_HOOK_TIMEOUT — watchdog timeout in seconds (default 30)
#
# stdin:
#   Claude Code's hook payload (JSON). Passed through to the real hook verbatim.

set -euo pipefail

readonly REAL_HOOK="${1:?hook-wrapper: real hook path required as $1}"
shift

: "${AUTOSESSION_SLUG:?hook-wrapper: AUTOSESSION_SLUG must be set (run.sh exports it)}"
: "${AUTOSESSION_DIR:?hook-wrapper: AUTOSESSION_DIR must be set (run.sh exports it)}"

readonly HOOK_NAME="$(basename "$REAL_HOOK")"
readonly LOGFILE="$AUTOSESSION_DIR/hook.log"
readonly LOCKFILE="$AUTOSESSION_DIR/hook.log.lock"
readonly TIMEOUT="${AUTOSESSION_HOOK_TIMEOUT:-30}"
readonly CORR_ID="$(date +%s%N)-$$"
readonly START_TS="$(date -Iseconds)"

# Temp files for capturing the hook's stderr (stdout passes through untouched).
readonly ERR_CAPTURE="$(mktemp -t "autosession-hook-err.XXXXXX")"
trap 'rm -f "$ERR_CAPTURE"' EXIT

# ─── Log helpers ──────────────────────────────────────────────────────────────
log_record() {
  # $1 = JSON record; single-line append under flock.
  # FD 9 pattern: opens lockfile once, flock -x blocks until exclusive hold.
  (
    flock -x 9
    printf '%s\n' "$1" >> "$LOGFILE"
  ) 9>"$LOCKFILE"
}

json_escape() {
  # Minimal JSON string escaper — backslash, double-quote, control chars.
  # For full correctness a jq invocation would be safer but adds a process.
  # This is sufficient for our known-shape inputs (paths, names, exit codes).
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

# ─── Start record ─────────────────────────────────────────────────────────────
start_json=$(printf '{"ts":"%s","corr":"%s","event":"hook_started","slug":"%s","hook":"%s","pid":%d}' \
  "$START_TS" \
  "$CORR_ID" \
  "$(json_escape "$AUTOSESSION_SLUG")" \
  "$(json_escape "$HOOK_NAME")" \
  "$$")
log_record "$start_json"

# ─── Run the hook with watchdog ───────────────────────────────────────────────
# Background the hook; stderr → capture file; stdout passes through untouched
# so Claude Code receives the real hook's response payload.
"$REAL_HOOK" "$@" 2> "$ERR_CAPTURE" &
HOOK_PID=$!

# Watchdog: background a killer that fires after $TIMEOUT unless cancelled.
(
  sleep "$TIMEOUT"
  # If the hook is still alive, SIGTERM it. Redirect stderr so we don't leak
  # "kill: (pid) - No such process" when the hook already exited normally.
  kill -TERM "$HOOK_PID" 2>/dev/null || true
  sleep 2
  kill -KILL "$HOOK_PID" 2>/dev/null || true
) &
WATCHDOG_PID=$!

# Ensure the watchdog doesn't outlive us under any exit path.
trap 'kill "$WATCHDOG_PID" 2>/dev/null || true; rm -f "$ERR_CAPTURE"' EXIT INT TERM HUP

# Wait for the hook. `wait` returns the hook's exit code (or 143/137 if killed).
set +e
wait "$HOOK_PID"
HOOK_EXIT=$?
set -e

# Cancel watchdog (the hook returned normally or via its own exit).
kill "$WATCHDOG_PID" 2>/dev/null || true

# ─── End record ───────────────────────────────────────────────────────────────
END_TS="$(date -Iseconds)"

# Read captured stderr (truncate at 1KB to keep records bounded).
STDERR_SNIPPET=""
if [ -s "$ERR_CAPTURE" ]; then
  STDERR_SNIPPET="$(head -c 1024 < "$ERR_CAPTURE")"
fi

# Classify exit: timeout (SIGTERM = 143 typically) vs normal.
TIMED_OUT="false"
if [ "$HOOK_EXIT" = "143" ] || [ "$HOOK_EXIT" = "137" ]; then
  TIMED_OUT="true"
fi

end_json=$(printf '{"ts":"%s","corr":"%s","event":"hook_ended","slug":"%s","hook":"%s","exit":%d,"timed_out":%s,"stderr":"%s"}' \
  "$END_TS" \
  "$CORR_ID" \
  "$(json_escape "$AUTOSESSION_SLUG")" \
  "$(json_escape "$HOOK_NAME")" \
  "$HOOK_EXIT" \
  "$TIMED_OUT" \
  "$(json_escape "$STDERR_SNIPPET")")
log_record "$end_json"

# Exit with the real hook's exit code so Claude Code sees what it would have seen.
exit "$HOOK_EXIT"
