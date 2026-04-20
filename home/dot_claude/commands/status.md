# /status — Show the current Timewarrior interval

Report what bead is currently being tracked, the resolved billing tuple, and elapsed time. Thin wrapper over `bd-timew status`.

## Instructions

1. Run `bd-timew status` via a Bash tool call.
2. Print the output verbatim. Expected shape when an interval is active:

   ```
   Tracking: <bead-id>  <title>
   Status:   <beads-status>
   Elapsed:  <Xh Ym or Nm>
   Client:   <bucket>
   Case:     <case-string>
   Svc:      <service-item>
   ```

3. When no interval is active, the script prints `bd-timew: no active timew interval.` — pass it through; no extra commentary.

4. **Flag anomalies** in the output only if they matter:
   - `Svc: (none)` (parenthesised) — tuple unresolved; point at the sidecar.
   - `Tracking: (no bead tag found on active interval)` — the active interval was started outside `bd-timew` (raw `timew start`) and isn't linked to a bead. Suggest `/stop` + `/start <bead>` to re-tag.

5. **Do not** try to compute variance against `est-h:` — that's a separate (not-yet-built) subcommand. If the user asks for variance, point them at `timew summary :id:<bead>` + `bd show <bead>` manual comparison.

## Related

- `/start`, `/stop`, `/switch` — the rest of the time-tracking family.
- Variance follow-up: tracked under Wave 2 (`bd list --label-pattern='est-h:*' --status=open` and search for "variance").
