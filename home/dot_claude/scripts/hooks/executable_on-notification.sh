#!/usr/bin/env bash
# on-notification.sh — Claude Code Notification hook.
#
# Reads a hook event JSON payload on stdin. If a notification config sentinel
# exists for the current session at
#   ~/.local/state/claude/notifications/<session-id>.jq
# evaluates it as a jq expression against the payload, then pipes the result
# to wsl-notify-send via --config -. Sentinels are absent by default; sessions
# opt in via `claude-notify enable`.
#
# Failures are silent (exit 0) so the harness's notification UX isn't
# interrupted by hook errors.

set -uo pipefail  # no -e: best-effort, no aborts on missing pieces

payload=$(cat)
session_id=$(jq -r '.session_id // empty' <<<"$payload" 2>/dev/null)
[ -z "$session_id" ] && exit 0

sentinel="$HOME/.local/state/claude/notifications/${session_id}.jq"
[ ! -f "$sentinel" ] && exit 0

config=$(jq -f "$sentinel" <<<"$payload" 2>/dev/null)
[ -z "$config" ] && exit 0

# wsl-notify-send is only meaningful under WSL2; gracefully no-op elsewhere.
command -v wsl-notify-send >/dev/null 2>&1 || exit 0

wsl-notify-send --config - <<<"$config" 2>/dev/null || true
