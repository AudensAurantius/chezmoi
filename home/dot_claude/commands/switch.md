---
name: switch
description: Switch Timewarrior tracking to a different bead in a single operation
argument-hint: <bead-id>
author: Michael Haynes
scope: global
tags: [time-tracking, beads, timewarrior]
timestamps:
  - action: created
    at: 2026-04-20T00:35:06-05:00
    actor: Michael Haynes
comments:
  - "Source: J121-9kp.1 Wave 1 time-tracking bundle (2026-04-20). Companion to /start, /stop, /status."
  - "Motivation: stopping the current interval and starting a new one were two commands with a window for forgetting the second step. /switch fuses the pair."
  - "Projected use: invoke when pivoting focus from one bead to another within the same session. Common pattern: /start epic → triage → /switch to chosen child bead when implementation begins."
related: [/start, /stop, /status, /time-report]
---

# /switch — Switch Timewarrior tracking to a different bead

Stop the current interval and immediately start a new one on another bead. Thin wrapper over `bd-timew switch`.

Bead argument: $ARGUMENTS

## Instructions

1. **Require an argument.** If `$ARGUMENTS` is empty or whitespace, print:

   ```
   /switch: missing bead id
   usage: /switch <bead-id>   (e.g. /switch J121-abc)
   ```

   and stop. Same rule as `/start`: never guess the target bead.

2. **Run the bridge.** Execute `bd-timew switch $ARGUMENTS`. Report the output — timew will print a stop summary for the old interval, then the resolution + start line for the new one.

3. **Non-transactional.** If the stop succeeds but the start fails (e.g. unknown bead id), no interval will be running. Surface the error and suggest `/start <bead>` once the bead id is corrected.

4. **Don't double-claim.** `bd-timew switch` handles `bd update --claim` on the new bead. Don't issue a separate claim.

## When to use `/switch` vs `/stop` then `/start`

- `/switch` — single atomic refocus to a different bead. Preferred in conversation.
- `/stop` then later `/start` — when there's a real gap (break, meeting, end-of-day). The intervening untracked time is meaningful.

## Related

- `/start`, `/stop`, `/status` — the rest of the time-tracking family.
