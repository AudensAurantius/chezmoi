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
