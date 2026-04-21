---
name: stop
description: Stop the current Timewarrior interval without changing any bead's status
argument-hint: ""
author: Michael Haynes
scope: global
tags: [time-tracking, timewarrior]
timestamps:
  - action: created
    at: 2026-04-20T00:35:06-05:00
    actor: Michael Haynes
  - action: updated
    at: 2026-04-21T12:30:00-05:00
    actor: Michael Haynes
    note: "Added argument-hint: \"\" (no-argument command; consistency pass)"
comments:
  - "Source: J121-9kp.1 Wave 1 time-tracking bundle (2026-04-20). Companion to /start, /switch, /status."
  - "Motivation: breaks, end-of-day, context-switching to non-bead work all need a clean timer stop. Independent of bead status so that in-progress beads stay in-progress when the user steps away."
  - "Projected use: invoke at breaks, end of session, or when switching to untracked work. Does NOT close the bead — use bd close explicitly when work is complete."
related: [/start, /switch, /status, /time-report]
---

# /stop — Stop the current Timewarrior interval

Thin wrapper over `bd-timew stop`. Ends the active interval without changing any bead's status in Beads.

## Instructions

1. Run `bd-timew stop` via a Bash tool call.
2. Report the output (timew shows the interval summary — start, end, duration, tags).
3. If stdout is empty and the exit code is non-zero, surface stderr. If timew reports "There is no active time tracking", say so plainly — no error, that's a normal state.

## What this does *not* do

- **Does not close the bead.** The bead stays claimed and `in_progress`. Use `bd close <id>` explicitly when the work is finished.
- **Does not update memory or generate a checkpoint.** Those are separate commands.

## Related

- `/start`, `/switch`, `/status` — the rest of the time-tracking family.
- `bd close <id>` — mark work complete once you're actually done.
