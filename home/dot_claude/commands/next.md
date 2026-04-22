---
name: next
description: Recommend the next bead to work on — delegates scoring to bv --robot-triage (graph-aware), falls back to bd ready if bv is unavailable
argument-hint: "[--parent <id>] [--epic <id>] [--src <value>] [--area <name>] [--svc <name>] [--label <dim:value>] [--priority <=N>] [--mine] [-n <N>]"
author: Michael Haynes
scope: global
tags: [beads, productivity, beads-viewer, graph-metrics]
timestamps:
  - action: created
    at: 2026-04-20T20:22:15-05:00
    actor: Michael Haynes
  - action: edited
    at: 2026-04-20T21:50:00-05:00
    actor: Michael Haynes
  - action: edited
    at: 2026-04-21T16:30:00-05:00
    actor: Michael Haynes
    note: "Added --src/--area/--svc shorthand flags as sugar over --label for the three billing label dimensions"
comments:
  - "Source: J121-9kp.2.13 Wave 2 productivity bundle (2026-04-20). Paired with /show (J121-9kp.2.15, read-only filter+list)."
  - "Motivation: default `bd ready` output is undifferentiated across epics/areas. /next scopes to a parent/area/priority slice and surfaces one curated recommendation with short alternates."
  - "Refactor 2026-04-20 (J121-d2v): delegate graph-aware scoring to `bv --robot-triage` (PageRank + betweenness + unblock-count + critical-path signals) instead of hand-rolled heuristic. Keep /next's ergonomic filter flags (--parent/--epic/--label/--priority/--mine/-n) as a thin translation layer over bv's flag surface, with post-filtering for flags bv doesn't support natively. Preserve a bd-ready fallback path for machines without bv provisioned."
  - "License-rider awareness (see bd remember beads-viewer-license-risk-accepted): `bv --robot-*` invocations carry the MIT-with-rider risk that was accepted for personal-tooling use. If the risk stance changes, the bv branch of /next should be disabled and the command should force-fall-through to bd ready."
related: [/show, /start, /switch, /status, /triage, "bv (beads_viewer)"]
---

# /next — Recommend the next bead to work on

Curated single-recommendation view over the ready queue. Graph-aware ranking from `bv --robot-triage` when available (PageRank + betweenness + unblock count + critical path), falling back to `bd ready` sort policy when bv isn't installed. Read-only — no writes, no side effects.

Arguments: $ARGUMENTS

## Argument shapes accepted

- `/next` — top of the ready queue across the whole workspace (3 candidates)
- `/next --parent <id>` / `/next --epic <id>` — scope to descendants of a parent or epic
- `/next --src <value>` — shorthand for `--label src:<value>`, e.g. `--src jira` (repeatable)
- `/next --area <name>` — shorthand for `--label area:<name>`, e.g. `--area snowflake` (repeatable)
- `/next --svc <name>` — shorthand for `--label svc:<name>`, e.g. `--svc none` (repeatable)
- `/next --label <dim:value>` — filter by label (repeatable; AND semantics)
- `/next --label-any <dim:value,...>` — filter by labels (OR semantics; comma-separated)
- `/next --priority <=N>` — cap priority floor, e.g. `--priority <=2` = P0/P1/P2 only
- `/next --priority <N>` — exact priority match, e.g. `--priority 1` = P1 only
- `/next --mine` — filter to beads assigned to the current git user
- `/next -n <N>` — number of candidates to show (default 3; one top pick + N-1 alternates)

Flags combine freely.

## Instructions

1. **Parse arguments.** Tokenize `$ARGUMENTS` on whitespace. Recognize the flags above; each takes the next token as its value except `--mine` (boolean). Unknown tokens → print a usage message and stop; don't guess.

   **Expand shorthand flags immediately after parsing** — before any other step:
   - Each `--src <v>` → append `src:<v>` to the `--label` list
   - Each `--area <v>` → append `area:<v>` to the `--label` list
   - Each `--svc <v>` → append `svc:<v>` to the `--label` list

   After expansion, all three are indistinguishable from `--label` entries; all downstream steps (bv flag translation, post-filtering, bd ready flag translation) treat them identically.

2. **Normalize `--priority` input.** Accept `--priority 2`, `--priority P2`, `--priority <=2`, or `--priority <=P2`. Strip `P`/`p` prefix and leading `<=`. Remember whether `<=` was present (ceiling vs. exact match).

3. **Detect bv.** Run `command -v bv >/dev/null 2>&1 && bv --version >/dev/null 2>&1`. If present → **bv branch (step 4)**. If not → **bd-ready fallback (step 8)**.

### bv branch — primary path

4. **Invoke `bv --robot-triage`.** Build the flag set:

   | User flag              | bv flag                                       |
   |------------------------|-----------------------------------------------|
   | `--mine`               | `--robot-by-assignee "$(git config user.name)"` |
   | `--label <v>` (single, the first one)  | `--robot-by-label <v>` (narrows bv's analysis) |
   | (other filters)        | *(post-filter in step 5 — bv's flag surface is thinner than /next's)* |

   Run `bv --robot-triage <flags>` and parse the JSON. The candidate list lives at `.triage.recommendations[]` — each entry has `id`, `title`, `type`, `status`, `priority`, `labels`, `score`, `breakdown`, `reasons`, `unblocks_ids`. bv returns up to 10; leave room for post-filtering.

   If bv exits non-zero, surface stderr. If `.triage.recommendations` is empty or missing, proceed to step 8 (fallback) with a one-line notice: `/next: bv returned no recommendations; falling back to bd ready`.

5. **Post-filter bv recommendations.** Apply our richer flags that bv doesn't support natively:
   - `--parent <id>` / `--epic <id>`: run `bd list --parent <id> --json -n 0` to enumerate descendant IDs (handle the bd-list-json trailing-footer gotcha with `sed -n '1,/^]$/p'`); keep only recommendations whose `id` is in that set.
   - `--label <v>` beyond the first: AND-filter recommendations by presence in the `labels` array.
   - `--label-any <csv>`: OR-filter recommendations by presence of any listed label.
   - `--priority <N>` (exact): keep only entries with `priority == N`.
   - `--priority <=N>` (ceiling): keep only entries with `priority <= N`. Beads priority is 0-4, 0 = highest.

6. **Trim to the requested count.** Take the first `-n` entries (default 3) after post-filtering. Do not re-sort — bv's ranking is the whole point of using this branch.

7. **Render (bv variant).** Use this structure:

   ```
   ── /next · <filter summary or "all ready"> · via bv ──

   Top pick:
     [P<priority>] <id> · <title>
     Type:     <type>
     Status:   <status>
     Labels:   <comma-separated, "(none)" if empty>
     Score:    <score to 3 decimals>
     Why:
       • <reasons[0]>
       • <reasons[1]>
       • <reasons[2]>
     Unblocks: <comma-separated unblocks_ids, or omit line if empty>

   Alternates (<count>):
     [P<priority>] <id> · <title>   (score <n.nnn>, <one reasons[] excerpt>)
     [P<priority>] <id> · <title>   (score <n.nnn>, <one reasons[] excerpt>)

   To start: /start <top-pick-id>
   ```

   Skip to step 11.

### bd-ready fallback — when bv is missing or returned nothing

8. **Build `bd ready --json`.** Translate flags:

   | User flag              | `bd ready` flag                             |
   |------------------------|---------------------------------------------|
   | `--parent <id>` / `--epic <id>` | `--parent <id>`                    |
   | `--label <v>` (repeatable) | `--label <v>` (repeatable, AND)         |
   | `--label-any <csv>`    | `--label-any <csv>`                         |
   | `--priority <N>` (exact) | `--priority <N>`                          |
   | `--priority <=N>` (ceiling) | *(no bd flag — post-filter in step 10)* |
   | `--mine`               | `--assignee "$(git config user.name)"`      |
   | `-n <N>`               | `--limit <N+5>` (over-fetch, trim in step 10) |

   Always pass `--json`. `bd ready --json` does NOT emit a trailing footer; no sed trim needed (unlike `bd list --json`).

9. **Run `bd ready --json <flags>`.** If empty (`[]`), print `/next: no ready beads match the given filters.` and stop.

10. **Post-filter for `--priority <=N>`** if a ceiling was set. Trim to `-n` (default 3).

11. **Render (bd-ready variant).** Use the same structure as step 7 but swap the heading and rationale:

   ```
   ── /next · <filter summary or "all ready"> · via bd ready (bv unavailable) ──

   Top pick:
     [P<priority>] <id> · <title>
     Type:     <issue_type>
     Labels:   <comma-separated, "(none)" if empty>
     Fanout:   <dependent_count> <"issue"|"issues"> blocked by this
     Created:  <YYYY-MM-DD>
     Jira:     <external_ref> | (omit line if none)

   Alternates (<count>):
     [P<priority>] <id> · <title>   (<fanout> blocked, <age>d old)
     [P<priority>] <id> · <title>   (<fanout> blocked, <age>d old)

   To start: /start <top-pick-id>
   ```

### Both paths

12. **Filter summary format.** Terse recap of user flags. Use `all ready` if no filters were given. Always include `· via bv` or `· via bd ready (bv unavailable)` to make the ranking source explicit.

    Label shorthands use their short form in the summary (e.g. `src=jira · area=snowflake`); raw `--label` entries render as `label=<v>`. Other flags: `parent=J121-9kp.2 · priority<=2 · mine`. Example: `src=jira · priority<=2 · via bv`.

13. **Single-candidate case.** If only one candidate comes back after filtering, omit the `Alternates` block and print `(no alternates at this filter scope)` underneath the top pick.

14. **Do not editorialize.** bv's `reasons[]` array is the rationale on the bv path; `bd ready`'s sort policy is the rationale on the fallback path. Don't add your own interpretation. Don't offer to run `/start` automatically.

## Invariants

- **Read-only.** Never claim, close, transition, or update any bead from /next.
- **Pure ranking delegation.** All scoring comes from bv or bd ready; no hand-rolled heuristics.
- **No fallback widening.** If user filters produce empty on both branches, say so and stop. Do not relax filters automatically.
- **bv ranking visible.** The output always names the ranking source (`via bv` or `via bd ready`) so the user knows which signal set they're looking at.
- **Never guess** a bead id or title. If neither bv nor bd returned it, it doesn't exist for this command's purpose.

## Related

- `/show` — non-opinionated sibling: filter+list without ranking.
- `/triage` — whole-project briefing with bv's 9 graph-metric insights (bead J121-6gw).
- `/start <id>` — claim the top pick and begin the timer.
- `bv --robot-triage` — the upstream data source for the bv branch; see also `bv --help` for the full `--robot-*` flag family.
