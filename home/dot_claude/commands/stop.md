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
