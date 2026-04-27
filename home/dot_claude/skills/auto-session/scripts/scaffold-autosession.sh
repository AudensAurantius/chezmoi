#!/usr/bin/env bash
# scaffold-autosession.sh — materialize a new auto-session directory.
#
# Invoked by the /auto-session skill during Step 3 (directory + scaffold).
# Given a target session dir and a session slug, creates the full directory
# tree, copies/renders CLAUDE.md + run.sh + settings.local.json, and primes
# the state/ subdir. Idempotent — re-running on an existing session dir
# refuses rather than overwriting.
#
# Usage:
#   scaffold-autosession.sh --session-dir <absolute-path> --slug <slug> [--force]
#
# Options:
#   --session-dir <path>   Absolute path to the new session dir (created if absent)
#   --slug <slug>          Session slug; appears in CLAUDE.md, run.sh, log records
#   --force                Permit scaffolding over an existing non-empty dir
#                          (DANGEROUS — only for recovery from interrupted runs)
#
# Exit codes:
#   0  — success
#   1  — argument parse error
#   2  — session dir already populated (use --force to override)
#   3  — template missing (skill is corrupt)
#   4  — required command missing (jq)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

TEMPLATE_CLAUDE_MD="$SKILL_DIR/templates/session-claude-md.md"
TEMPLATE_RUN_SH="$SKILL_DIR/templates/run.sh.j2"
TEMPLATE_SETTINGS_FRAGMENT="$SKILL_DIR/hooks/settings-fragment.json"
HOOK_WRAPPER="$SKILL_DIR/scripts/lib/hook-wrapper.sh"

# ─── Arg parsing ──────────────────────────────────────────────────────────────
SESSION_DIR=""
SLUG=""
FORCE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --session-dir) SESSION_DIR="${2:?--session-dir requires a value}"; shift 2 ;;
    --slug)        SLUG="${2:?--slug requires a value}"; shift 2 ;;
    --force)       FORCE=1; shift ;;
    --help|-h)     sed -n '1,30p' "$0" >&2; exit 0 ;;
    *) echo "scaffold-autosession: unknown argument: $1" >&2; exit 1 ;;
  esac
done

[ -n "$SESSION_DIR" ] || { echo "scaffold-autosession: --session-dir required" >&2; exit 1; }
[ -n "$SLUG" ]        || { echo "scaffold-autosession: --slug required" >&2; exit 1; }

case "$SESSION_DIR" in
  /*) ;;
  *) echo "scaffold-autosession: --session-dir must be absolute, got: $SESSION_DIR" >&2; exit 1 ;;
esac

case "$SLUG" in
  *[!a-zA-Z0-9_-]*) echo "scaffold-autosession: slug must match [A-Za-z0-9_-]+, got: $SLUG" >&2; exit 1 ;;
esac

# ─── Prereqs ──────────────────────────────────────────────────────────────────
command -v jq >/dev/null || { echo "scaffold-autosession: jq not found" >&2; exit 4; }

for f in "$TEMPLATE_CLAUDE_MD" "$TEMPLATE_RUN_SH" "$TEMPLATE_SETTINGS_FRAGMENT" "$HOOK_WRAPPER"; do
  [ -f "$f" ] || { echo "scaffold-autosession: template/script missing: $f" >&2; exit 3; }
done

# ─── Pre-flight: refuse to overwrite an existing session ──────────────────────
if [ -d "$SESSION_DIR" ] && [ -n "$(ls -A "$SESSION_DIR" 2>/dev/null || true)" ]; then
  if [ "$FORCE" != "1" ]; then
    echo "scaffold-autosession: session dir $SESSION_DIR is non-empty; refusing to scaffold." >&2
    echo "  Use --force to override (only safe for resuming an interrupted scaffold)." >&2
    exit 2
  fi
  echo "scaffold-autosession: --force given; proceeding over existing $SESSION_DIR" >&2
fi

# ─── Build the tree ───────────────────────────────────────────────────────────
mkdir -p \
  "$SESSION_DIR" \
  "$SESSION_DIR/.claude" \
  "$SESSION_DIR/.claude/agents" \
  "$SESSION_DIR/state" \
  "$SESSION_DIR/clones" \
  "$SESSION_DIR/agents" \
  "$SESSION_DIR/execution-log"

# ─── Render CLAUDE.md ─────────────────────────────────────────────────────────
# Simple sed-based substitution. Slugs and session dirs contain only
# [A-Za-z0-9_-/] so no escaping needed.
sed \
  -e "s|{{session_slug}}|$SLUG|g" \
  -e "s|{{session_dir}}|$SESSION_DIR|g" \
  "$TEMPLATE_CLAUDE_MD" > "$SESSION_DIR/CLAUDE.md"

# ─── Render run.sh ────────────────────────────────────────────────────────────
sed \
  -e "s|{{session_slug}}|$SLUG|g" \
  -e "s|{{session_dir}}|$SESSION_DIR|g" \
  "$TEMPLATE_RUN_SH" > "$SESSION_DIR/run.sh"
chmod +x "$SESSION_DIR/run.sh"

# ─── Render session-scoped settings.local.json ────────────────────────────────
# Take the template fragment, strip the _comment/_env_contract keys, and
# replace each "<WRAPPED>$SKILL_DIR/path/to/script.sh</WRAPPED>" placeholder
# with a real wrapper-invocation command string.
#
# The rendered command looks like:
#   <HOOK_WRAPPER> <real-hook-absolute-path>
# hook-wrapper.sh takes the real hook path as $1 and passes stdin / stdout
# through unchanged. AUTOSESSION_SLUG / AUTOSESSION_DIR come from run.sh.

render_wrapped() {
  # $1 = raw inner path (e.g., $SKILL_DIR/scripts/lib/notify-dispatcher.sh)
  local inner="$1"
  # Substitute $SKILL_DIR → actual skill dir.
  inner="${inner//\$SKILL_DIR/$SKILL_DIR}"
  printf '%s %s' "$HOOK_WRAPPER" "$inner"
}

# Use jq to walk the template, replace each <WRAPPED>…</WRAPPED> command, and
# strip the documentation keys. The transform function runs per hook command
# string and produces the wrapped form.
jq --arg skill_dir "$SKILL_DIR" --arg wrapper "$HOOK_WRAPPER" '
  def rewrap:
    if type == "string" and startswith("<WRAPPED>") and endswith("</WRAPPED>") then
      (.[9:-10] | gsub("\\$SKILL_DIR"; $skill_dir)) as $inner
      | ($wrapper + " " + $inner)
    else . end;

  del(._comment, ._env_contract)
  | .hooks |= (
      to_entries
      | map(
          .value |= map(
            .hooks |= map(.command |= rewrap)
          )
        )
      | from_entries
    )
' "$TEMPLATE_SETTINGS_FRAGMENT" > "$SESSION_DIR/.claude/settings.local.json"

# ─── Symlink the session-reviewer agent into the session's local agents dir ───
# This lets Task(subagent_type=session-reviewer) resolve without requiring a
# global install. If the user has also run install.sh, the global symlink is
# harmless — Claude Code's agent resolver dedupes by name.
AGENT_SRC="$SKILL_DIR/agents/session-reviewer.md"
if [ -f "$AGENT_SRC" ]; then
  ln -sf "$AGENT_SRC" "$SESSION_DIR/.claude/agents/session-reviewer.md"
fi

# ─── Seed state dir with an empty hook log + README ──────────────────────────
: > "$SESSION_DIR/hook.log"
cat > "$SESSION_DIR/state/README.md" <<EOF
# state/

Per-session runtime state. Safe to inspect; do not hand-edit while the
session is running.

- \`nag-<session-id>.pid\` — PID file for an active nag-repeater. Created
  by scripts/lib/notify-dispatcher.sh, removed by scripts/lib/preuse-cancel-nag.sh
  or on nag-cap.
- Additional files may accumulate as features land.

Cleared by \`/auto-session --shutdown\` as part of shutdown hygiene.
EOF

# ─── Done ─────────────────────────────────────────────────────────────────────
cat <<EOF
Scaffolded auto-session:
  Dir:       $SESSION_DIR
  Slug:      $SLUG
  Launcher:  $SESSION_DIR/run.sh
  Settings:  $SESSION_DIR/.claude/settings.local.json
  CLAUDE.md: $SESSION_DIR/CLAUDE.md
  State:     $SESSION_DIR/state/

Next: write prompt.md into $SESSION_DIR, then launch via:
  cd "$SESSION_DIR" && ./run.sh
EOF
