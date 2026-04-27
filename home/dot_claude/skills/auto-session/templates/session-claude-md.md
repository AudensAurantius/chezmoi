# Session CLAUDE.md — {{session_slug}}

You are the coordinator of an autonomous auto-session. This file is the always-on
stack of instructions that every turn of this session will see, including after
context compaction. Your full session brief lives at `prompt.md` in this directory.

## Context compaction resilience

**Context compaction strips the session brief.** `prompt.md` is a file on disk —
you can re-read it any time. But after a compaction, only this CLAUDE.md and your
latest messages are guaranteed to survive; the verbatim contents of `prompt.md`
will not.

Rule: **if any of the following is true, re-read `prompt.md` end-to-end before
taking your next substantive action.**

- You just handled a SessionStart:compact hook.
- Your recent context contains paraphrased references to sandbox rules, repo
  templates, conventions, decision-log shape, or bead mutation policy, but no
  verbatim quotations from them.
- You are about to make a decision that hinges on a convention or policy you
  can only vaguely recall.

**Anti-loop clause:** if uncertainty about the brief persists after re-reading
`prompt.md`, halt and request user clarification via a `decision_block`
notification rather than re-reading a second time or guessing. Re-reading
`prompt.md` more than once in a single compaction cycle is a sign the brief is
unclear, not that you need to try harder.

## Working directory invariant

This coordinator must only run when the Claude Code session's working directory
is the session dir (`{{session_dir}}`). If `pwd` does not match, refuse to
proceed and surface the mismatch to the user — hooks, CLAUDE.md, and bead paths
all resolve relative to the cwd, and running from the wrong dir produces silent
misbehavior.

## Single-writer invariants (non-negotiable)

- **Timewarrior:** only you (the coordinator) invoke `bd-timew start/stop/switch`
  or `bd update --status` or `bd close`. Subagents never touch timew or bead
  state. Concurrent writes corrupt the interval log.
- **Notes field for bd updates:** every `bd update --status` must pair with
  `--append-notes "[autosession/{{session_slug}} <ISO-8601>] <from> -> <to>; <rationale>"`
  in a single invocation. This is the transition-attribution audit trail since
  bd has no native per-transition metadata. See `prompt.md` §"Bead mutation
  policy" for the full rule set.

## Bead mutation policy — summary

The full policy is in `prompt.md` §"Bead mutation policy". Quick summary:

- **Metadata (cardinality-1):** set `agent=claude` and `autosession_slug={{session_slug}}`
  on every claim. Queryable via `bd list --metadata-field`.
- **Labels (transient markers only):** `autosession-deferred` / `autosession-blocked`
  added on defer/block, removed on next claim. No accumulating source-attribution
  labels — the notes trail is the history.
- **Custom statuses respected:** `on_finish` maps to `review`, not `closed`,
  because the user set `bd config set status.custom review,testing`.

## Notifications

Two categories, separately triggered (see `prompt.md` §"Notifications" for full
detail):

- **io_block:** fired automatically by the session's Notification hook. Soft sound.
  Re-nags every 60s up to 30 iterations until you resume.
- **decision_block:** fired by you directly when logging a blocking decision:
  `wsl-notify-send --urgent --sound=Alarm "Decision needed: <short title>"`.
  Persistent on-screen. Halt after firing; resume only when the user has written
  `Resolution:` into the decision-log entry.

## Pointers — do not duplicate here

Everything else (full sandbox table, scope, conventions, permissions granted,
subagent patterns, shutdown checklist) lives in `prompt.md`. This file is
deliberately short so it survives compaction as a navigational index, not a
duplicate of the brief.
