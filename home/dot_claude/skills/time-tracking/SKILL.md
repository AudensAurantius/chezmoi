---
name: time-tracking
description: Beads + Timewarrior time-tracking ritual via bd-timew. Use when claiming a bead to work on, switching focus between beads, stopping work for a break, or checking what's currently being tracked. Covers the /start, /stop, /switch, and /status slash commands that wrap the bd-timew bridge script.
---

# Time Tracking

This skill codifies the Beads + Timewarrior time-tracking workflow. Every unit of billable and non-billable work should be bracketed by a `timew` interval tagged with a Beads issue ID and a resolved `(client, case, svc)` tuple.

## The bridge: `bd-timew`

`bd-timew` (at `~/.local/bin/bd-timew`, Chezmoi-managed) is the single source of truth for linking Beads issues to Timewarrior intervals. It reads the per-workspace sidecar `.beads/bd-timew.yaml` to resolve a bead's labels to a NetSuite billing tuple.

**Resolution order** (first wins, merged onto the sidecar's `default:` block):

1. Per-issue `case:<string>` label on the bead (escape hatch — forces `case`).
2. First matching rule in the sidecar's `patterns:` list (regex over the space-joined label string).
3. Sidecar `default:` block.
4. Hardcoded fallback: `svc = "Technology Services"`.

Run `bd-timew resolve <id>` to preview the tuple without starting anything.

## Slash commands

| Command | Wraps | When to use |
|---|---|---|
| `/start <bead-id>` | `bd-timew start <id>` | Beginning work on a bead. Claims the bead in Beads and starts a tagged `timew` interval. |
| `/switch <bead-id>` | `bd-timew switch <id>` | Mid-session refocus. Stops the current interval, claims the new bead, starts a new interval. Not transactional — if `start` fails after `stop`, no interval runs; rerun `/start`. |
| `/stop` | `bd-timew stop` | Ending work, break, end of day. Does **not** change bead status in Beads — the bead stays claimed (use `bd close <id>` to finish). |
| `/status` | `bd-timew status` | Answering "what am I tracking right now?" without leaving Claude. Shows bead ID + title, Beads status, elapsed time, and resolved tuple. |

### No-argument handling

`/start` and `/switch` require an argument. If the user invokes either without a bead ID, refuse with short usage text — do not guess a bead from `bd ready` or `bd list --status=in_progress`. Silently starting a timer on the wrong bead corrupts billing data.

### Interpreting `/status` output

```
Tracking: J121-abc  <title>
Status:   in_progress | open | blocked | ...
Elapsed:  1h 23m
Client:   <bucket> | (none)
Case:     <NetSuite case string> | area:<label> | (none)
Svc:      <service item> | none | (none)
```

- `Svc: none` (the string "none") marks a non-billable interval (tooling, meta-work, personal).
- `Svc: (none)` (parenthesised) means the tuple field was unresolved — investigate the sidecar or bead labels.
- `Case: area:<label>` means the resolver fell through to a default that uses the raw Beads area label; this is expected for non-client work buckets.

## Variance and reporting

`bd-timew` does not yet ship a variance subcommand. To compare actual time to an `est-h:N` estimate:

```bash
# Total time tagged with a specific bead ID, across all time:
timew summary :id:J121-abc

# Or for a week:
timew summary :week :id:J121-abc
```

Then compare to the bead's `est-h:` label (`bd show J121-abc`). See the follow-up bead for automating this (tracked under Wave 2: variance reporting).

## Estimate label convention

Three optional dimensions; apply at creation time, retrofit only when touching an issue for other reasons:

- `est-h:N` — hours (whole or half integers, min 0.5). **Only dimension `bd-timew` variance reports consult.**
- `est-p:N` — story points (scrum).
- `est-t:S` — t-shirt size: XS / S / M / L / XL.

Query patterns: `bd list --label-pattern='est-h:*'` etc.

## When to invoke this skill autonomously

- Any time the user says "start working on <bead>" or "let's do <bead>".
- Session-start rituals where a bead is being claimed.
- When the user asks "what am I working on?" or equivalent.
- Before a `/clear` or end-of-session: if a timer is running and the user indicates wrapping up, confirm whether to `/stop`.

## References

- `bd-timew` source: `~/.local/bin/bd-timew` (Chezmoi: `home/dot_local/bin/executable_bd-timew.tmpl`)
- Sidecar schema example: `<project>/.beads/bd-timew.yaml`
- Full convention + rationale: auto-memory `feedback-time-tracking.md`
- Label taxonomy (Option B prefix-namespaced): auto-memory `reference-beads-label-taxonomy.md`
- Billing-tuple decision record: `bd memories time-tracking-option-a-decision`
