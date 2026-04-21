---
name: switch
description: Switch Timewarrior tracking to a different bead — composes /stop then /start so /start's post-hooks (task-dir scaffold, proceed to implementation) apply
argument-hint: <bead-id>
author: Michael Haynes
scope: global
tags: [time-tracking, beads, timewarrior]
timestamps:
  - action: created
    at: 2026-04-20T00:35:06-05:00
    actor: Michael Haynes
  - action: edited
    at: 2026-04-20T20:48:00-05:00
    actor: Michael Haynes
comments:
  - "Source: J121-9kp.1 Wave 1 time-tracking bundle (2026-04-20). Companion to /start, /stop, /status."
  - "Motivation: stopping the current interval and starting a new one were two commands with a window for forgetting the second step. /switch fuses the pair."
  - "Projected use: invoke when pivoting focus from one bead to another within the same session. Common pattern: /start epic → triage → /switch to chosen child bead when implementation begins."
  - "Refactor 2026-04-20 (J121-yxc): rewrote from `bd-timew switch` wrapper to a composition of /stop + /start at the slash-command layer. The bridge's `switch` subcommand is literally `cmd_stop() + cmd_start()` under the hood (bd-timew lines 168-175) — no atomic primitive was lost. Compositional rewrite means /start's post-hooks (task-dir scaffold prompt, proceed-to-implementation) propagate to /switch automatically instead of needing duplication."
related: [/start, /stop, /status, /time-report]
---

# /switch — Switch Timewarrior tracking to a different bead

Pivot focus from the current bead to another one. Implemented as composition of `/stop` + `/start`, so /start's post-hooks (task-dir scaffold prompt, auto-proceed to implementation) apply on the new bead.

Bead argument: $ARGUMENTS

## Instructions

1. **Require an argument.** If `$ARGUMENTS` is empty or whitespace, print:

   ```
   /switch: missing bead id
   usage: /switch <bead-id>   (e.g. /switch J121-abc)
   ```

   and stop. Same rule as `/start`: never guess the target bead.

2. **Stop the current interval.** Follow the instructions of `/stop` — specifically, run `bd-timew stop` via Bash and report the output. If there is no active interval, `/stop`'s own instructions say to treat that as a normal state (no error). This is the expected no-op path when `/switch` is invoked with nothing running.

3. **Start the new interval.** Follow the instructions of `/start` with `$ARGUMENTS` as its input. This means the full /start flow: bridge invocation, tuple-correctness check, task-dir scaffold prompt, and proceed-to-implementation. If /start fails (unknown bead id, missing workspace, etc.), surface the error — the old interval has already been stopped, so no interval is now running. Suggest `/start <corrected-bead>` to recover. Same non-transactional behavior as the previous `bd-timew switch` wrapper.

4. **Don't double-claim.** /start already issues `bd update --claim` on the new bead through the bridge. Do not add a separate claim call here.

## When to use `/switch` vs `/stop` then `/start`

- `/switch` — single conversational refocus. You save the two-command ritual.
- `/stop` then later `/start` — when there's a real gap (break, meeting, end-of-day). The intervening untracked time is meaningful and shouldn't be hidden behind one command.

## Related

- `/start`, `/stop`, `/status` — the rest of the time-tracking family.
