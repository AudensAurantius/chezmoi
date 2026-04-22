---
name: switch
description: Switch Timewarrior tracking to a different bead — composes /stop then /start so /start's post-hooks (task-dir scaffold, proceed to implementation) apply. Optional --status transitions the outgoing bead.
argument-hint: "<bead-id> | --jira <JIRA-KEY> [--status <state>]"
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
  - action: updated
    at: 2026-04-21T11:30:00-05:00
    actor: Michael Haynes
    note: "Added --jira <KEY> as alternative to positional bead ID; delegates resolution to /start's Jira key resolution procedure"
  - action: updated
    at: 2026-04-21T23:00:00-05:00
    actor: Michael Haynes
    note: "Added --status <state> flag; transitions the OUTGOING bead (the one the interval is being stopped on) before starting the new interval. Mirrors the new flag on /stop."
comments:
  - "Source: J121-9kp.1 Wave 1 time-tracking bundle (2026-04-20). Companion to /start, /stop, /status."
  - "Motivation: stopping the current interval and starting a new one were two commands with a window for forgetting the second step. /switch fuses the pair."
  - "Projected use: invoke when pivoting focus from one bead to another within the same session. Common pattern: /start epic → triage → /switch to chosen child bead when implementation begins. With --status, common pattern: /switch --status=review <next-bead> to move the just-finished bead to review as part of the switch."
  - "Refactor 2026-04-20 (J121-yxc): rewrote from `bd-timew switch` wrapper to a composition of /stop + /start at the slash-command layer. The bridge's `switch` subcommand is literally `cmd_stop() + cmd_start()` under the hood (bd-timew lines 168-175) — no atomic primitive was lost. Compositional rewrite means /start's post-hooks (task-dir scaffold prompt, proceed-to-implementation) propagate to /switch automatically instead of needing duplication."
  - "2026-04-21: Added --jira <JIRA-KEY> as alternative to positional bead ID. Resolution is fully delegated to /start's Jira key resolution procedure — /switch passes the bead-identification portion of $ARGUMENTS through to /start unchanged."
  - "2026-04-21 (second edit): Added --status <state> as an outgoing-bead transition applied between the /stop and /start phases. Kept the flag on the *outgoing* side because the incoming bead is always going to be claimed (in_progress) by /start's bridge — transitioning it to anything else would race with the claim."
related: [/start, /stop, /status, /time-report]
---

# /switch — Switch Timewarrior tracking to a different bead

Pivot focus from the current bead to another one. Implemented as composition of `/stop` + `/start`, so /start's post-hooks (task-dir scaffold prompt, auto-proceed to implementation) apply on the new bead. With `--status <state>`, the outgoing bead is transitioned to the given status between the stop and start phases.

Arguments: $ARGUMENTS

## Instructions

1. **Parse and validate arguments.** Split `$ARGUMENTS` into two groups:
   - **Bead identification** (required): a bare positional bead ID, OR `--jira <KEY>`. Mutually exclusive with each other.
   - **Status flag** (optional): `--status <state>` or `--status=<state>`.

   If neither bead identification is present, print:
   ```
   /switch: missing bead id
   usage: /switch <bead-id>                  (e.g. /switch J121-abc)
          /switch --jira <KEY>               (e.g. /switch --jira BOCO-18077)
          /switch <bead-id> --status review  (move outgoing bead to review)
   ```
   and stop. Same rule as `/start`: never guess the target bead.

   If both positional ID and `--jira` are present → usage error and stop. If any unrecognized tokens remain after removing the above → usage error and stop.

2. **Stop the current interval, with optional status transition.** Follow the instructions of `/stop`, passing through `--status <state>` if the user supplied it. Specifically:
   - If `--status` was **not** given: run `bd-timew stop` via Bash and report.
   - If `--status` **was** given: resolve the active bead (via `bd-timew status`), run `bd-timew stop`, then `bd update <outgoing-id> --status=<state>`.
   - Treat "no active interval" as a normal no-op **only if `--status` was not given**. If `--status` was given but nothing is running, print:
     ```
     /switch: --status requires an active timew interval with a bead tag.
     ```
     and stop — do not proceed to start the new interval. Otherwise the user would have a status flag that silently did nothing and a timer that started anyway, hiding the mistake.

3. **Start the new interval.** Follow the instructions of `/start` with the bead-identification portion of `$ARGUMENTS` (strip out `--status <state>` / `--status=<state>` before delegating — /start doesn't recognize it). This means the full /start flow: Jira key resolution (if `--jira` was given), bridge invocation, tuple-correctness check, task-dir scaffold prompt, and proceed-to-implementation.

   If /start fails at any step (unknown bead id, Jira resolution failure, missing workspace, etc.), surface the error — the old interval has already been stopped (and potentially transitioned) so no interval is now running. Suggest `/start <corrected-bead>` or `/start --jira <KEY>` to recover.

4. **Don't double-claim.** /start already issues `bd update --claim` on the new bead through the bridge. Do not add a separate claim call here. The `--status` flag only applies to the outgoing bead; the incoming bead is always claimed (and thus becomes `in_progress`).

## When to use `/switch` vs `/stop` then `/start`

- `/switch` — single conversational refocus. Saves the two-command ritual. Use `--status` to transition the outgoing bead in the same breath.
- `/stop` then later `/start` — when there's a real gap (break, meeting, end-of-day). The intervening untracked time is meaningful and shouldn't be hidden behind one command.

## Examples

- `/switch J121-abc` — stop current interval, start on J121-abc.
- `/switch --jira BOCO-18077` — same, via Jira key resolution.
- `/switch J121-abc --status=review` — move the outgoing bead to `review`, then start on J121-abc.
- `/switch --jira BOCO-18077 --status testing` — same pattern, Jira form + space-separated status.

## Related

- `/start`, `/stop`, `/status` — the rest of the time-tracking family.
- `bd config set status.custom <csv>` — register custom statuses accepted by `--status`.
