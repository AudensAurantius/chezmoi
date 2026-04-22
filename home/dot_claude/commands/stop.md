---
name: stop
description: Stop the current Timewarrior interval, optionally transitioning the active bead to a target status
argument-hint: "[--status <state>]"
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
  - action: updated
    at: 2026-04-21T23:00:00-05:00
    actor: Michael Haynes
    note: "Added --status <state> flag to transition the active bead to a target status (e.g. review, testing, blocked) in the same action as stopping the timer. Motivated by custom status additions (review, testing) on 2026-04-21."
comments:
  - "Source: J121-9kp.1 Wave 1 time-tracking bundle (2026-04-20). Companion to /start, /switch, /status."
  - "Motivation: breaks, end-of-day, context-switching to non-bead work all need a clean timer stop. Independent of bead status so that in-progress beads stay in-progress when the user steps away. --status added 2026-04-21 for the common pattern 'this chunk of work is done, move it to review/testing' — previously required a separate bd update after /stop."
  - "Projected use: invoke at breaks, end of session, when switching to untracked work, or when finishing a unit of work that needs review/testing before close."
related: [/start, /switch, /status, /time-report]
---

# /stop — Stop the current Timewarrior interval

Thin wrapper over `bd-timew stop`. Ends the active interval. With `--status <state>`, also transitions the active bead to the given status in the same action.

Arguments: $ARGUMENTS

## Instructions

1. **Parse arguments.** Recognize `--status <state>` (or `--status=<state>`). Any other tokens → print:
   ```
   /stop: unrecognized argument
   usage: /stop [--status <state>]
   ```
   and stop. If no arguments, proceed to step 3 with `target_status` unset.

2. **Resolve the active bead (only if `--status` was given).** Run `bd-timew status` via Bash and parse the `Tracking:` line to extract the bead ID. If the output is `bd-timew: no active timew interval.` or the ID can't be parsed, print:
   ```
   /stop: --status requires an active timew interval with a bead tag.
   ```
   and stop. Do not guess the bead from recent activity.

3. **Stop the interval.** Run `bd-timew stop` via Bash. Report the output (timew shows the interval summary — start, end, duration, tags). If stdout is empty and exit is non-zero, surface stderr. If timew reports "There is no active time tracking", say so plainly — normal state, no error.

4. **Transition the bead (only if `--status` was given and step 2 found a bead).** Run `bd update <resolved_id> --status=<state>` via Bash. Report the output. If bd rejects the status (invalid for this workspace — e.g., not a built-in and not in `status.custom`), surface the error verbatim so the user can correct it or register the custom status. Do not retry with a fallback.

5. **Do not claim or close the bead automatically.** `--status` only performs the one transition the user asked for. If the user wants `closed`, they can pass `--status=closed`; the command treats it like any other status.

## What this does *not* do

- **Does not close the bead by default.** Without `--status`, the bead stays claimed and `in_progress`.
- **Does not validate the status locally.** bd is the source of truth for which statuses are valid (built-in plus `status.custom` config). The command passes `--status` through and surfaces any rejection.
- **Does not update memory or generate a checkpoint.** Those are separate commands.

## Examples

- `/stop` — plain stop; no bead change.
- `/stop --status=review` — stop the timer and move the active bead to `review`.
- `/stop --status blocked` — same, space-separated form.
- `/stop --status=closed` — stop and close in one step (equivalent to `/stop` + `bd close`).

## Related

- `/start`, `/switch`, `/status` — the rest of the time-tracking family.
- `/switch <bead> --status <state>` — same status-transition flag on the outgoing bead when switching.
- `bd config set status.custom <csv>` — register custom statuses accepted by `--status`.
