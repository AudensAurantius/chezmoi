#!/usr/bin/env bash
# post-compact-rehydrate.sh — fired by SessionStart:compact hook in a session.
#
# Emits an "additionalContext" payload instructing the coordinator to re-read
# prompt.md. This survives compaction because it's injected by the hook after
# the compaction has already completed — the instruction to rehydrate is NOT
# part of the compacted context, so it can't itself be paraphrased away.
#
# Reads session context from the environment (set by run.sh) rather than the
# cwd, to be robust against hook invocations that might run from a different
# directory than the session root.

set -euo pipefail

: "${AUTOSESSION_SLUG:?post-compact-rehydrate: AUTOSESSION_SLUG not set}"
: "${AUTOSESSION_DIR:?post-compact-rehydrate: AUTOSESSION_DIR not set}"

# The additionalContext string is consumed by Claude Code's SessionStart hook
# contract; it appears in the coordinator's context as a system reminder.
ADDITIONAL_CONTEXT=$(cat <<EOF
[AUTOSESSION REHYDRATE — compaction just completed]

Your session brief lives at ${AUTOSESSION_DIR}/prompt.md. The compaction that
just finished may have stripped verbatim policy text. Before your next
substantive action:

1. Re-read ${AUTOSESSION_DIR}/prompt.md end-to-end.
2. Re-read ${AUTOSESSION_DIR}/CLAUDE.md if you do not recall the compaction-resilience rule.
3. If uncertainty persists after re-reading, fire a decision_block notification
   and halt rather than re-reading a second time or guessing.

Session slug: ${AUTOSESSION_SLUG}
Session dir:  ${AUTOSESSION_DIR}
EOF
)

# Emit via the Claude Code SessionStart hook response protocol.
# The schema: { "hookSpecificOutput": { "additionalContext": "..." } }
jq -n --arg ctx "$ADDITIONAL_CONTEXT" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: $ctx
  }
}'
