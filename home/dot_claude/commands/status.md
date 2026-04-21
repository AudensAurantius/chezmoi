---
name: status
description: Show the current Timewarrior interval, bead, and elapsed time
argument-hint: "[--with-context]"
author: Michael Haynes
scope: global
tags: [time-tracking, timewarrior]
timestamps:
  - action: created
    at: 2026-04-20T00:35:06-05:00
    actor: Michael Haynes
  - action: updated
    at: 2026-04-21T11:00:00-05:00
    actor: Michael Haynes
comments:
  - "Source: J121-9kp.1 Wave 1 time-tracking bundle (2026-04-20). Companion to /start, /stop, /switch."
  - "Motivation: 'what am I tracking right now and for how long' is the single most common time-tracking question. Needed a zero-friction answer."
  - "Projected use: invoke at any point to verify the current bead, billing tuple, and elapsed time. Read-only — never modifies state."
  - "2026-04-21: Added --with-context flag. When passed, after showing the active interval, runs bd show on the active bead, searches bd memories for keywords from the bead's title and labels, and surfaces matching entries plus any doc/path references found in the bead's notes field."
related: [/start, /stop, /switch, /time-report]
---

# /status — Show the current Timewarrior interval

Report what bead is currently being tracked, the resolved billing tuple, and elapsed time. Thin wrapper over `bd-timew status`.

Arguments: $ARGUMENTS

## Instructions

1. **Parse arguments.** Recognize `--with-context` (boolean). Any other token → print a usage message and stop.

2. Run `bd-timew status` via a Bash tool call.

3. Print the output verbatim. Expected shape when an interval is active:

   ```
   Tracking: <bead-id>  <title>
   Status:   <beads-status>
   Elapsed:  <Xh Ym or Nm>
   Client:   <bucket>
   Case:     <case-string>
   Svc:      <service-item>
   ```

4. When no interval is active, the script prints `bd-timew: no active timew interval.` — pass it through; no extra commentary. Skip step 5 if no interval is active.

5. **Flag anomalies** in the output only if they matter:
   - `Svc: (none)` (parenthesised) — tuple unresolved; point at the sidecar.
   - `Tracking: (no bead tag found on active interval)` — the active interval was started outside `bd-timew` (raw `timew start`) and isn't linked to a bead. Suggest `/stop` + `/start <bead>` to re-tag.

6. **Do not** try to compute variance against `est-h:` — that's a separate (not-yet-built) subcommand. If the user asks for variance, point them at `timew summary :id:<bead>` + `bd show <bead>` manual comparison.

7. **`--with-context` enrichment.** Only if `--with-context` was passed and an active bead ID was found in the `Tracking:` line:
   - Run `bd show <bead-id>` via Bash to get the full bead record (labels, notes).
   - Extract keywords: 2-4 specific nouns from the bead title and labels (same heuristic as `/show --with-context`).
   - Run `bd memories <keyword>` for each term; deduplicate and filter to substantively relevant results.
   - Scan the bead's `NOTES` section for path references (`docs/`, `tasks/`, `.md`, `.sql`, `J121-pipelines/`).
   - Render as a `── Context ──` block appended after the status output, in the same format as `/show --with-context`:

     ```
     ── Context ──

     Memories (bd remember):
       • <key>: <first ~120 chars of value>

     Supporting docs:
       • <path-or-link>
     ```

   - If both sections are empty, omit the Context block.

## Related

- `/start`, `/stop`, `/switch` — the rest of the time-tracking family.
- Variance follow-up: tracked under Wave 2 (`bd list --label-pattern='est-h:*' --status=open` and search for "variance").
