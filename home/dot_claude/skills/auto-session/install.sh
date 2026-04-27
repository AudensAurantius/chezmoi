#!/usr/bin/env bash
# install.sh — idempotent installer for the auto-session skill's global wiring.
#
# Under the session-scoped-hooks architecture (every auto-session writes its
# own <session-dir>/.claude/settings.local.json at scaffold time), there is
# NO global hook registration anymore. The one remaining global step is
# symlinking the session-reviewer agent into ~/.claude/agents/ so that
# Task(subagent_type=session-reviewer) resolves correctly from within a
# running session.
#
# TTY-GUARDED: refuses to run without an interactive terminal on stdin. This
# is by design — the script modifies global Claude Code config and must not
# be runnable by an autonomous agent, even if the user allowlists it. If
# you're reading this because an agent ran it and bounced, good: the guard
# worked.
#
# Exit codes:
#   0  — success (installed, or already installed, or uninstalled)
#   10 — refused: no TTY on stdin
#   11 — refused: user did not confirm
#   2  — drift: existing symlink points somewhere unexpected
#   3  — drift: destination exists and is not a symlink
#   4  — missing prerequisite (skill dir, agent file, etc.)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$SCRIPT_DIR"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
AGENTS_DIR="$CLAUDE_HOME/agents"
AGENT_SRC="$SKILL_DIR/agents/session-reviewer.md"
AGENT_DST="$AGENTS_DIR/session-reviewer.md"
AGENT_RELATIVE_TARGET="../skills/auto-session/agents/session-reviewer.md"

# -------- TTY guard (belt) --------
if [ ! -t 0 ]; then
  echo "install.sh: refusing to run without an interactive TTY on stdin." >&2
  echo "  This script modifies global Claude Code config. It must be run manually" >&2
  echo "  in your shell, not invoked by an automation tool." >&2
  exit 10
fi

MODE="${1:-install}"
case "$MODE" in
  install|--install)  MODE="install" ;;
  uninstall|--uninstall) MODE="uninstall" ;;
  status|--status) MODE="status" ;;
  *) echo "usage: $0 [install|uninstall|status]" >&2; exit 1 ;;
esac

# -------- Prerequisites --------
for cmd in readlink dirname ln; do
  command -v "$cmd" >/dev/null || { echo "install.sh: required command not found: $cmd" >&2; exit 4; }
done

[ -f "$AGENT_SRC" ] || { echo "install.sh: skill agent file missing: $AGENT_SRC" >&2; exit 4; }

# -------- status mode --------
if [ "$MODE" = "status" ]; then
  echo "auto-session install status"
  echo "  CLAUDE_HOME:    $CLAUDE_HOME"
  echo "  Skill dir:      $SKILL_DIR"
  echo
  echo "  Agent symlink:"
  if [ -L "$AGENT_DST" ]; then
    echo "    $AGENT_DST -> $(readlink "$AGENT_DST")"
  elif [ -e "$AGENT_DST" ]; then
    echo "    $AGENT_DST exists but is not a symlink (drift)"
  else
    echo "    $AGENT_DST not present"
  fi
  echo
  echo "  Hooks: session-scoped (no global registration)."
  echo "         Each /auto-session scaffolds its own <session-dir>/.claude/settings.local.json."
  exit 0
fi

# -------- Confirm (suspenders) --------
if [ "$MODE" = "install" ]; then
  cat <<EOF
About to install auto-session global wiring:
  1. Symlink $AGENT_DST -> $AGENT_RELATIVE_TARGET
     (makes session-reviewer subagent resolvable from any Claude Code session)

Hooks are NOT registered globally. Each /auto-session creates its own
<session-dir>/.claude/settings.local.json with session-scoped hooks at
scaffold time. Interactive sessions are never affected.
EOF
else
  cat <<EOF
About to uninstall auto-session global wiring:
  1. Remove $AGENT_DST (only if it points at the skill's agent)

No hook entries to remove — they live in each session dir and are discarded
with the session.
EOF
fi

read -r -p "Type INSTALL to confirm (anything else aborts): " confirm
[ "$confirm" = "INSTALL" ] || { echo "Aborted."; exit 11; }

# ============================================================
# UNINSTALL
# ============================================================
if [ "$MODE" = "uninstall" ]; then
  if [ -L "$AGENT_DST" ]; then
    current_target="$(readlink "$AGENT_DST")"
    case "$current_target" in
      "$AGENT_SRC"|"$AGENT_RELATIVE_TARGET")
        rm "$AGENT_DST"
        echo "Removed symlink: $AGENT_DST"
        ;;
      *)
        echo "Leaving symlink in place (points elsewhere): $AGENT_DST -> $current_target" >&2
        ;;
    esac
  elif [ -e "$AGENT_DST" ]; then
    echo "Leaving $AGENT_DST in place (not a symlink)." >&2
  else
    echo "No symlink to remove."
  fi
  echo "Uninstall complete."
  exit 0
fi

# ============================================================
# INSTALL
# ============================================================

mkdir -p "$AGENTS_DIR"

if [ -L "$AGENT_DST" ]; then
  current_target="$(readlink "$AGENT_DST")"
  case "$current_target" in
    "$AGENT_SRC"|"$AGENT_RELATIVE_TARGET")
      echo "Agent symlink already installed: $AGENT_DST -> $current_target"
      ;;
    *)
      echo "Drift: $AGENT_DST -> $current_target (expected $AGENT_RELATIVE_TARGET)" >&2
      echo "Refusing to replace. Resolve manually or remove the existing symlink." >&2
      exit 2
      ;;
  esac
elif [ -e "$AGENT_DST" ]; then
  echo "Drift: $AGENT_DST exists and is not a symlink." >&2
  echo "Refusing to replace. If this is a hand-edited agent you want to keep, back it up first." >&2
  exit 3
else
  ln -s "$AGENT_RELATIVE_TARGET" "$AGENT_DST"
  echo "Installed symlink: $AGENT_DST -> $AGENT_RELATIVE_TARGET"
fi

cat <<EOF

Install complete. Summary:
  Agent:    $AGENT_DST -> $AGENT_RELATIVE_TARGET

To verify: $0 status
To remove: $0 uninstall
EOF
