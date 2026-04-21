---
name: start
description: Begin work on a Beads issue — claim it and start a Timewarrior interval tagged with its billing tuple
argument-hint: "<bead-id> | --jira <JIRA-KEY>"
author: Michael Haynes
scope: global
tags: [time-tracking, beads, timewarrior]
timestamps:
  - action: created
    at: 2026-04-20T00:35:06-05:00
    actor: Michael Haynes
  - action: updated
    at: 2026-04-21T11:30:00-05:00
    actor: Michael Haynes
    note: "Added --jira <KEY> as alternative to positional bead ID, with Jira-fallback resolution procedure"
comments:
  - "Source: J121-9kp.1 Wave 1 time-tracking bundle (2026-04-20). Companion to /stop, /switch, /status and the bd-timew bridge script at ~/.local/bin/bd-timew."
  - "Motivation: claiming a bead and starting time tracking were two separate rituals (bd update --claim + timew start) that were easy to skip. One command enforces the pairing."
  - "Projected use: invoke when starting work on a specific bead. Epic-level /start is OK for triage/refinement; /switch to a child bead as soon as concrete work begins so billing tuple resolves correctly."
  - "2026-04-21: Added --jira <JIRA-KEY> flag as an alternative to the positional bead ID. Resolves via local title search → Jira MCP verify → bd jira sync → retry; surfaces known pitfalls and offers manual-mirror fallback on continued failure. Positional ID and --jira are mutually exclusive."
related: [/stop, /switch, /status, /time-report]
---

# /start — Begin work on a Beads issue

Claim a Beads issue and start a Timewarrior interval tagged with its resolved billing tuple. Thin wrapper over `bd-timew start`.

Arguments: $ARGUMENTS

## Instructions

1. **Parse and validate arguments.** If `$ARGUMENTS` is empty or whitespace, print:
   ```
   /start: missing bead id
   usage: /start <bead-id>        (e.g. /start J121-abc)
          /start --jira <KEY>     (e.g. /start --jira BOCO-18077)
   ```
   and stop. Do **not** infer a bead from `bd ready`, in-progress lists, or context. Starting the timer on the wrong bead corrupts billing.

   Recognized forms:
   - Positional bead ID: first token that does not start with `-`
   - `--jira <KEY>`: flag + value (mutually exclusive with positional ID)
   - Both present simultaneously → usage error and stop.

2. **Resolve the bead ID.**
   - If a positional bead ID was given → `resolved_id = <id>`. Skip to step 3.
   - If `--jira <KEY>` → run the **Jira key resolution** procedure:

     **A. Local lookup.**
     ```bash
     bd list --label=src:jira --json 2>/dev/null | sed -n '1,/^]$/p' | \
       jq -r --arg k "KEY" '.[] | select(.title | test($k; "i")) | .id' | head -1
     ```
     If a bead ID is returned → `resolved_id = <that id>`. Proceed to step 3.

     **B. Jira verification** (if local lookup returned nothing). Call the Atlassian MCP tool `getJiraIssue` (cloudId `80b04637-628f-4df2-8bfa-012de201c08c`, issueIdOrKey `<KEY>`).
     - If MCP returns an error or 404: print `/start: ticket <KEY> not found in Jira or no access. Verify the key and Jira authentication.` and stop.
     - If ticket found → proceed to C.

     **C. Sync and retry.** Run `bd jira sync --pull` via Bash. Re-run the local lookup from A. If found → `resolved_id = <that id>`. Proceed to step 3.

     **D. Diagnose and surface** (if still not found after sync). Run `bd config show | grep pull_jql` to get the configured JQL. Check whether the Jira ticket's summary and assignee match it. Then report:
     - "Ticket `<KEY>` exists in Jira but could not be imported into Beads."
     - List applicable known reasons:
       * *JQL mismatch*: ticket isn't assigned to `currentUser()` or summary doesn't satisfy the filter — sync will never auto-import it. See CLAUDE.md pitfall #26.
       * *Incremental timing gap*: ticket matches the JQL but hasn't been updated since the last sync run. Known pitfall: `bd-jira-sync-pull-incremental-timing-gap-sync`. Running sync again may not help without recent ticket activity.
       * *Done ticket pre-dating first sync*: ticket is Done and was Done when the first full sync ran. See CLAUDE.md pitfall #27.
     - Offer: `(a) Create a manual mirror: bd create --title '<KEY> · <summary>' --label=src:jira --external-ref=<jira-url>; (b) Full investigation with /jira-show <KEY>.`
     - **Record any newly discovered failure mode** not matching the above: run `bd remember "jira-sync-failure: <concise description>"` before stopping.
     - Stop.

3. **Run the bridge.** Execute `bd-timew start <resolved_id>` via a Bash tool call. Report the full stdout (it shows the issue, labels, and resolved `(client, case, svc)` tuple) and any stderr.

4. **On failure** (non-zero exit), surface the error verbatim. Common causes:
   - No active beads workspace (`bd where` fails): tell the user to `cd` into a project that has `.beads/`.
   - Unknown bead id: check spelling with `bd list`.
   - `PyYAML` missing: the script's error message explains the fix.

5. **Do not change bead status yourself.** `bd-timew start` already calls `bd update --claim` when appropriate. Don't double up.

6. **Post-action:** no additional commentary unless the tuple looks wrong (e.g. `Svc: (none)` on what should be a billable bead) — in that case, flag it briefly and point at `.beads/bd-timew.yaml`.

7. **Offer to scaffold a task directory.** Check whether `tasks/<resolved_id>/` exists; for `src:jira` beads, also check `tasks/<JIRA-KEY>/`. If either exists, skip this step silently. Otherwise, ask the user on one line: `Scaffold tasks/<id>/? [y/N]`. Do not try to judge appropriateness from the bead description — the user decides at the prompt. On `y`/`yes`, invoke `/task-init <resolved_id>` yourself (don't wait for the user to re-type); on anything else, skip and continue.

8. **Proceed to implementation.** After the timer is running, any tuple concern is flagged, and the task-dir prompt is resolved, read the bead's description (already printed by step 3) and begin the work. The user invoked `/start` to start doing the issue — do not stop and ask for confirmation. Exception: if the bead is pure scoping/design with no concrete deliverable yet, say so in one line and prompt for direction instead of spinning up speculative work.

## Related

- `/stop`, `/switch`, `/status` — the rest of the time-tracking family.
- The `time-tracking` skill has the full ritual, tuple resolution order, and reporting pointers.
