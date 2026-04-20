---
name: start
description: Begin work on a Beads issue — claim it and start a Timewarrior interval tagged with its billing tuple
author: Michael Haynes
scope: global
tags: [time-tracking, beads, timewarrior]
timestamps:
  - action: created
    at: 2026-04-20T00:35:06-05:00
    actor: Michael Haynes
comments:
  - "Source: J121-9kp.1 Wave 1 time-tracking bundle (2026-04-20). Companion to /stop, /switch, /status and the bd-timew bridge script at ~/.local/bin/bd-timew."
  - "Motivation: claiming a bead and starting time tracking were two separate rituals (bd update --claim + timew start) that were easy to skip. One command enforces the pairing."
  - "Projected use: invoke when starting work on a specific bead. Epic-level /start is OK for triage/refinement; /switch to a child bead as soon as concrete work begins so billing tuple resolves correctly."
related: [/stop, /switch, /status, /time-report]
---

# /start — Begin work on a Beads issue

Claim a Beads issue and start a Timewarrior interval tagged with its resolved billing tuple. Thin wrapper over `bd-timew start`.

Bead argument: $ARGUMENTS

## Instructions

1. **Require an argument.** If `$ARGUMENTS` is empty or whitespace, print:

   ```
   /start: missing bead id
   usage: /start <bead-id>   (e.g. /start J121-abc)
   ```

   and stop. Do **not** try to infer a bead from `bd ready`, in-progress lists, or context. Starting the timer on the wrong bead corrupts billing.

2. **Run the bridge.** Execute `bd-timew start $ARGUMENTS` via a Bash tool call. Report the full stdout (it shows the issue, labels, and resolved `(client, case, svc)` tuple) and any stderr.

3. **On failure** (non-zero exit), surface the error verbatim. Common causes:
   - No active beads workspace (`bd where` fails): tell the user to `cd` into a project that has `.beads/`.
   - Unknown bead id: check spelling with `bd list`.
   - `PyYAML` missing: the script's error message explains the fix.

4. **Do not change bead status yourself.** `bd-timew start` already calls `bd update --claim` when appropriate. Don't double up.

5. **Post-action:** no additional commentary unless the tuple looks wrong (e.g. `Svc: (none)` on what should be a billable bead) — in that case, flag it briefly and point at `.beads/bd-timew.yaml`.

## Related

- `/stop`, `/switch`, `/status` — the rest of the time-tracking family.
- The `time-tracking` skill has the full ritual, tuple resolution order, and reporting pointers.
