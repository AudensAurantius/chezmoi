---
name: next
description: Recommend the next bead to work on — filter+rank bd ready, return the top candidate and 1-2 alternates
argument-hint: "[--parent <id>] [--epic <id>] [--label <dim:value>] [--priority <=N>] [--mine] [-n <N>]"
author: Michael Haynes
scope: global
tags: [beads, productivity, ready-queue]
timestamps:
  - action: created
    at: 2026-04-20T20:22:15-05:00
    actor: Michael Haynes
comments:
  - "Source: J121-9kp.2.13 Wave 2 productivity bundle (2026-04-20). Paired with /show (J121-9kp.2.15) which covers filter+list without scoring."
  - "Motivation: default `bd ready` output is undifferentiated across epics/areas; picking the right next item required eyeballing the full list. /next scopes to a parent/label/priority slice and surfaces one recommendation with short alternates."
  - "Projected use: invoke between stops — 'what should I pick up next?' — optionally scoped to an epic or area. Ship-it-first version is filter-only; scoring extension (fanout * priority * est-h) is a follow-up iteration if filter-only proves insufficient."
  - "Future integration with /queue-bead (J121-fxa): when /queue-bead is implemented, /next should peek the queue first and return the head if non-empty, falling through to filter+rank only when the queue is empty."
related: [/show, /start, /switch, /status, /queue-bead]
---

# /next — Recommend the next bead to work on

Filter and surface the next available Beads issue to pick up. Thin wrapper over `bd ready --json` with convenient filter flags and a curated single-recommendation output. No writes — purely advisory.

Arguments: $ARGUMENTS

## Argument shapes accepted

- `/next` — top of `bd ready` across the whole workspace (3 candidates)
- `/next --parent <id>` / `/next --epic <id>` — scope to descendants of a parent or epic
- `/next --label <dim:value>` — filter by label (repeatable; AND semantics)
- `/next --label-any <dim:value,...>` — filter by labels (OR semantics; comma-separated)
- `/next --priority <=N>` — cap priority floor, e.g. `--priority <=2` = P0/P1/P2 only
- `/next --priority <N>` — exact priority match, e.g. `--priority 1` = P1 only
- `/next --mine` — filter to beads assigned to the current git user
- `/next -n <N>` — number of candidates to show (default 3; one top pick + N-1 alternates)

Flags combine freely.

## Instructions

1. **Parse arguments.** Tokenize `$ARGUMENTS` on whitespace. Recognize the flags above; each takes the next token as its value (except `--mine`, which is boolean). Unknown tokens → print a usage message and stop; don't guess.

2. **Normalize `--priority` input.** Accept either `--priority 2`, `--priority P2`, `--priority <=2`, or `--priority <=P2`. Strip any `P`/`p` prefix and any leading `<=`. Remember whether the user wrote `<=` so you know to treat it as a ceiling rather than exact match.

3. **Build the `bd ready --json` invocation.** Translate flags:

   | User flag              | `bd ready` flag                             |
   |------------------------|---------------------------------------------|
   | `--parent <id>` / `--epic <id>` | `--parent <id>`                     |
   | `--label <v>` (repeatable)      | `--label <v>` (repeatable, AND)     |
   | `--label-any <csv>`             | `--label-any <csv>`                 |
   | `--priority <N>` (exact)        | `--priority <N>`                    |
   | `--priority <=N>` (ceiling)     | *(no bd flag — post-filter in step 5)* |
   | `--mine`                        | `--assignee "$(git config user.name)"` |
   | `-n <N>`                        | `--limit <N+5>` (over-fetch, then trim in step 6 — leaves room for post-filtering) |

   Always pass `--json`. Default `-n` is 3 if the user did not specify.

4. **Run `bd ready --json <flags>` via Bash.** If it exits non-zero, surface stderr and stop. If it returns `[]`, print:

   ```
   /next: no ready beads match the given filters.
   ```

   and stop. Do not suggest fallbacks or widen the search — the user's filters are authoritative.

5. **Post-filter for `--priority <=N>`** if the user passed a ceiling. Keep only entries whose `priority` field is `<= N`. (Beads `priority` field is 0-4, 0 = highest.)

6. **Trim to the requested count.** Take the first N entries after any post-filter. The JSON is already sorted by `bd ready`'s default sort policy (priority + hybrid). Do not re-sort.

7. **Render the output.** Use this structure verbatim:

   ```
   ── /next · <filter summary or "all ready"> ──

   Top pick:
     [P<priority>] <id> · <title>
     Type:     <issue_type>
     Labels:   <comma-separated, "(none)" if empty>
     Fanout:   <dependent_count> <"issue"|"issues"> blocked by this
     Created:  <YYYY-MM-DD> (age in days if > 7)
     Jira:     <external_ref> | (none)

   Alternates (<count>):
     [P<priority>] <id> · <title>   (<fanout> blocked, <age>d old)
     [P<priority>] <id> · <title>   (<fanout> blocked, <age>d old)

   To start: /start <top-pick-id>
   ```

   Rules:
   - `<filter summary>` is a terse recap of the user's filters, e.g. `parent=J121-9kp.2 · priority<=2 · mine`. Omit the section heading parenthetical if no filters were given.
   - `<age in days>` = `floor((now - created_at) / 86400)`. Only show on top pick if > 7 days; always show on alternates.
   - If only one candidate came back, omit the `Alternates` block and print `(no alternates at this filter scope)` underneath the top pick.
   - If a candidate has no `external_ref`, omit the Jira line entirely (don't print `(none)` on the top pick — keep it clean).

8. **Do not editorialize.** Don't explain why you picked the top one — `bd ready`'s sort policy is the rationale. Don't suggest adjacent beads outside the filter. Don't offer to run `/start` automatically. This is an advisory surface, not an automation surface.

## Invariants

- **Read-only.** Never claim, close, transition, or update any bead from /next.
- **Pure wrapper.** All ranking comes from `bd ready`. No custom scoring in this version — see J121-fxa and the bead description for why scoring is deferred.
- **No fallbacks.** If filters produce empty, say so and stop. Do not widen automatically.
- **Never guess** a bead id or title. If `bd ready` didn't return it, it doesn't exist for this command's purpose.

## Related

- `/show` — the non-opinionated sibling: filter+list without ranking or recommendation.
- `/start <id>` — claim the top pick and begin the timer.
- `/queue-bead` (J121-fxa, not yet implemented) — when live, /next should peek the committed queue first.
