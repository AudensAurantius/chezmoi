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
