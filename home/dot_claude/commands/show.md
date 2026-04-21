---
name: show
description: Filter+list beads (or inspect one) using ergonomic flag names that map to bd label/filter syntax
argument-hint: "[--task <id>] [--epic <id>] [--area <name>] [--service <name>] [--assignee <name>] [--status <s>] [--ready] [--priority <N>] [-n <N>]"
author: Michael Haynes
scope: global
tags: [beads, productivity, read-only]
timestamps:
  - action: created
    at: 2026-04-20T20:30:48-05:00
    actor: Michael Haynes
comments:
  - "Source: J121-9kp.2.15 Wave 2 productivity bundle (2026-04-20). Sibling to /next (J121-9kp.2.13) under the split decided in bd remember show-vs-next-split."
  - "Motivation: default bd list/ready require dim:value label syntax (--label area:claude, --label svc:none) which is ergonomically hostile; /show exposes --area/--service as first-class flags that translate internally. Also solves the 'I forgot the bead ID' problem that /start can't solve itself (positional arg must be precise — fuzzy matching in /start would risk corrupting billing)."
  - "Projected use: invoke when browsing available work, checking what's under an epic, or inspecting a single bead by partial recall. Read-only; no scoring (that belongs in /next). --task <id> is a single-item inspect that dispatches to bd show."
related: [/next, /start, /switch, /status]
---

# /show — Filter+list beads with ergonomic flag names

Read-only list/inspect over `bd list` (or `bd ready` with `--ready`), with convenience flags that translate to bd's label/filter syntax. No scoring, no recommendation — that's `/next`'s job.

Arguments: $ARGUMENTS

## Argument shapes accepted

- `/show` — open + in_progress across the workspace (bd list default)
- `/show --task <id>` — single-bead inspect (dispatches to `bd show <id>`; exclusive with other filters)
- `/show --epic <id>` — descendants of an epic or parent bead
- `/show --area <name>` — label filter, e.g. `--area snowflake` → `--label=area:snowflake`
- `/show --service <name>` — label filter, e.g. `--service none` → `--label=svc:none`
- `/show --assignee <name>` — filter by assignee (or `--mine` for current git user)
- `/show --status <s>` — `open`, `in_progress`, `blocked`, `deferred`, `closed`, or comma-separated combo
- `/show --ready` — use `bd ready` semantics instead of `bd list` (filters to truly-claimable work)
- `/show --priority <N>` — exact priority (0-4 or P0-P4)
- `/show --priority <=N>` — priority ceiling (post-filter)
- `/show -n <N>` — limit results (default: bd's own default of 50)

Flags combine with AND semantics. `--task` is exclusive; any other flag passed with `--task` is an error.

## Instructions

1. **Parse arguments.** Tokenize `$ARGUMENTS` on whitespace. Recognize the flags above; each takes the next token as its value except `--ready` and `--mine` (booleans). Unknown tokens → print a usage message and stop. Don't guess.

2. **Handle `--task` exclusively.** If `--task <id>` was passed along with any other filter, print:

   ```
   /show: --task <id> is a single-bead inspect; it cannot be combined with other filters.
   ```

   and stop. If only `--task <id>` was passed, run `bd show <id>` via Bash and report the output verbatim. Do not post-process. That's the whole behavior for this branch.

3. **Normalize `--priority` input.** Accept `--priority 2`, `--priority P2`, `--priority <=2`, or `--priority <=P2`. Strip any `P`/`p` prefix and any leading `<=`. Remember whether the user wrote `<=` (ceiling) vs. no prefix (exact).

4. **Resolve `--mine`.** If `--mine` was passed, set the assignee to `$(git config user.name)`. If `--assignee` was also passed, `--assignee` wins (explicit beats shorthand).

5. **Build the bd invocation.** Base command is `bd list` unless `--ready` was passed, in which case it's `bd ready`. Translate flags:

   | User flag               | bd flag                                                |
   |-------------------------|--------------------------------------------------------|
   | `--epic <id>`           | `--parent <id>`                                        |
   | `--area <name>`         | `--label=area:<name>` (repeatable if user repeats)     |
   | `--service <name>`      | `--label=svc:<name>`                                   |
   | `--assignee <name>` / `--mine` | `--assignee <name>`                             |
   | `--status <s>`          | `--status <s>` (bd list only; bd ready ignores)        |
   | `--priority <N>` (exact)| `--priority <N>` (pass through for bd list; bd ready's int flag is exact too) |
   | `--priority <=N>` (ceiling) | *(no bd flag — post-filter from JSON in step 7)*   |
   | `-n <N>`                | `--limit <N>`                                          |

   Always pass `--json` so the output is structured.

   **Note:** `bd ready` does not accept `--status` (it has fixed semantics). If the user combined `--ready` with `--status`, drop `--status` silently — `bd ready` already excludes closed/deferred/blocked — and continue.

6. **Run the command via Bash.** If exit is non-zero, surface stderr and stop. If the JSON is `[]`, print:

   ```
   /show: no beads match the given filters.
   ```

   and stop. Do not suggest widening the filters.

   **Gotcha — `bd list --json` is not clean JSON when truncated.** When `bd list` hits its `-n` limit, it appends a human-readable footer (`Showing N issues; more results matched but were hidden by --limit...`) *after* the JSON array. Before parsing, strip trailing non-JSON: take the substring up to and including the last line containing only `]` (optionally with trailing whitespace). Example one-liner: pipe to `sed -n '1,/^]$/p'` before passing to a JSON parser. `bd ready --json` does *not* have this bug; no stripping needed on that path.

7. **Post-filter for `--priority <=N>`** if a ceiling was provided. Keep only entries whose `priority` field is `<= N`.

8. **Render the list.** Use a compact table — one line per bead, sorted by bd's own order (do not re-sort):

   ```
   ── /show · <filter summary or "default"> · <N> result(s) ──

    st  pri  id              title                                               labels
    ○   P0   J121-ao6        Great Clips | Unit Test Development / Documentation src:jira
    ◐   P3   J121-9kp.2      (EPIC) Wave 2: Productivity...                      area:claude, area:tooling
    ...

   To inspect:  /show --task <id>
   To start:    /start <id>
   ```

   Rules:
   - Status glyph: `○ open`, `◐ in_progress`, `● blocked`, `❄ deferred`, `✓ closed` (match bd's legend).
   - Priority: `P<N>` left-padded to 2 chars (e.g. `P0`, `P3`).
   - Title: truncate to fit one line — budget ~60 chars for title; overflow with `…`.
   - Labels: comma-separated, up to 3 most-informative (drop `src:jira` if the row already has a Jira external_ref, drop `scope:local` as low-signal). If more than 3 survive, show `+N` suffix.
   - If the result set is large, print a footer: `<shown> of <total> matched; raise -n to see more` — only when `bd`'s own JSON response indicates truncation (check for presence of more results vs. limit).
   - `<filter summary>` is a terse recap, e.g. `epic=J121-9kp.2 · status=open · area=claude`. Use `default` if no filters.

9. **Do not editorialize.** No recommendations, no "consider starting with X", no commentary. /show lists; /next recommends — keep the boundary clean.

## Invariants

- **Read-only.** Never claim, close, transition, or update a bead from /show.
- **Pure wrapper.** All filtering goes through bd. No custom queries. The only post-processing is the `--priority <=N>` ceiling and label trimming for display.
- **No fallbacks.** Empty result → say so and stop. Do not widen automatically.
- **`--task` is exclusive.** Mixing it with other filters is a usage error, not something to reconcile.

## Related

- `/next` — the opinionated sibling: applies filters the same way and recommends a single bead.
- `/start <id>` — claim and begin the timer on a bead you picked from the list.
- `bd list --help` / `bd ready --help` — the underlying commands; /show is a flag-ergonomics wrapper.
