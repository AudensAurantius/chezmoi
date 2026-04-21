---
name: show
description: Filter+list beads (or inspect one) using ergonomic flag names that map to bd label/filter syntax
argument-hint: "[<bead-id>] [--task <id>] [--jira <JIRA-KEY>] [--epic <id>] [--area <name>] [--service <name>] [--assignee <name>] [--status <s>] [--ready] [--priority <N>] [-n <N>] [--with-context]"
author: Michael Haynes
scope: global
tags: [beads, productivity, read-only]
timestamps:
  - action: created
    at: 2026-04-20T20:30:48-05:00
    actor: Michael Haynes
  - action: updated
    at: 2026-04-21T11:00:00-05:00
    actor: Michael Haynes
    note: "Added --with-context flag for single-bead inspect: appends bd memories + notes doc links"
  - action: updated
    at: 2026-04-21T11:30:00-05:00
    actor: Michael Haynes
    note: "Added bare positional bead ID (implicit --task), --jira <KEY> flag with Jira-fallback resolution, positional/--task/--jira mutual exclusion"
comments:
  - "Source: J121-9kp.2.15 Wave 2 productivity bundle (2026-04-20). Sibling to /next (J121-9kp.2.13) under the split decided in bd remember show-vs-next-split."
  - "Motivation: default bd list/ready require dim:value label syntax (--label area:claude, --label svc:none) which is ergonomically hostile; /show exposes --area/--service as first-class flags that translate internally. Also solves the 'I forgot the bead ID' problem that /start can't solve itself (positional arg must be precise — fuzzy matching in /start would risk corrupting billing)."
  - "Projected use: invoke when browsing available work, checking what's under an epic, or inspecting a single bead by partial recall. Read-only; no scoring (that belongs in /next). --task <id> is a single-item inspect that dispatches to bd show."
  - "2026-04-21: Added --with-context flag. When a single-bead path is active, appends a Context block: bd memories search on bead keywords + doc/path links extracted from the NOTES field."
  - "2026-04-21: Bare positional bead ID now treated as implicit --task (e.g. /show J121-abc or /show J121-abc --with-context). Added --jira <JIRA-KEY> as an alternative to --task/positional, mutually exclusive with both. --jira resolves via local title search → Jira MCP verify → bd jira sync → retry; surfaces known pitfalls and offers manual-mirror fallback on continued failure."
related: [/next, /start, /switch, /status]
---

# /show — Filter+list beads with ergonomic flag names

Read-only list/inspect over `bd list` (or `bd ready` with `--ready`), with convenience flags that translate to bd's label/filter syntax. No scoring, no recommendation — that's `/next`'s job.

Arguments: $ARGUMENTS

## Argument shapes accepted

- `/show` — open + in_progress across the workspace (bd list default)
- `/show <bead-id>` — single-bead inspect; bare positional token is implicit `--task`
- `/show --task <id>` — single-bead inspect (explicit form)
- `/show --jira <JIRA-KEY>` — single-bead inspect resolved via Jira key (e.g. `--jira BOCO-18077`)
- `/show --epic <id>` — descendants of an epic or parent bead
- `/show --area <name>` — label filter, e.g. `--area snowflake` → `--label=area:snowflake`
- `/show --service <name>` — label filter, e.g. `--service none` → `--label=svc:none`
- `/show --assignee <name>` — filter by assignee (or `--mine` for current git user)
- `/show --status <s>` — `open`, `in_progress`, `blocked`, `deferred`, `closed`, or comma-separated combo
- `/show --ready` — use `bd ready` semantics instead of `bd list` (filters to truly-claimable work)
- `/show --priority <N>` — exact priority (0-4 or P0-P4)
- `/show --priority <=N>` — priority ceiling (post-filter)
- `/show -n <N>` — limit results (default: bd's own default of 50)
- `/show <bead-id> --with-context` or `/show --task <id> --with-context` or `/show --jira <KEY> --with-context` — single-bead inspect with appended Context section (memories + doc links)

`--with-context` may be combined with any single-bead path. `--task`, `--jira`, and a bare positional ID are mutually exclusive with each other and with all list-mode flags.

## Instructions

1. **Parse arguments.** Tokenize `$ARGUMENTS` on whitespace. Recognize:
   - Boolean flags: `--ready`, `--mine`, `--with-context`
   - Value flags: `--task <id>`, `--jira <KEY>`, `--epic <id>`, `--area <name>`, `--service <name>`, `--assignee <name>`, `--status <s>`, `--priority <N>`, `-n <N>`
   - **Bare positional token:** a token that does not start with `-` and appears before any value-taking flag → treat as implicit `--task <id>`. A token that appears *after* a value-taking flag is that flag's value, not a positional ID.
   - Unknown tokens that aren't flag values → print a usage message and stop.

2. **Validate single-bead path.** If any of `--task`, `--jira`, or a bare positional ID was given:
   - They are mutually exclusive with each other. If more than one is present → usage error and stop.
   - They are mutually exclusive with all list-mode flags (`--epic`, `--area`, `--service`, `--assignee`, `--status`, `--ready`, `--priority`, `-n`). If combined → print:
     ```
     /show: single-bead flags (--task / --jira / <bead-id>) cannot be combined with list filters.
     ```
     and stop. Exception: `--with-context` is allowed alongside any single-bead flag.
   - If only a single-bead flag is present (with or without `--with-context`), proceed to **step 3**.
   - Otherwise proceed to **step 5** (list path).

3. **Resolve the bead ID.**
   - If `--task <id>` or bare positional → `resolved_id = <id>`. Skip to step 4.
   - If `--jira <KEY>` → run the **Jira key resolution** procedure:

     **A. Local lookup.**
     ```bash
     bd list --label=src:jira --json 2>/dev/null | sed -n '1,/^]$/p' | \
       jq -r --arg k "KEY" '.[] | select(.title | test($k; "i")) | .id' | head -1
     ```
     If a bead ID is returned → `resolved_id = <that id>`. Proceed to step 4.

     **B. Jira verification** (if local lookup returned nothing). Call the Atlassian MCP tool `getJiraIssue` (cloudId `80b04637-628f-4df2-8bfa-012de201c08c`, issueIdOrKey `<KEY>`).
     - If MCP returns an error or 404: print `/show: ticket <KEY> not found in Jira or no access. Verify the key and Jira authentication.` and stop.
     - If ticket found → proceed to C.

     **C. Sync and retry.** Run `bd jira sync --pull` via Bash. Re-run the local lookup from A. If found → `resolved_id = <that id>`. Proceed to step 4.

     **D. Diagnose and surface** (if still not found after sync). Run `bd config show | grep pull_jql` to get the configured JQL. Check whether the Jira ticket's summary and assignee match it. Then report:
     - "Ticket `<KEY>` exists in Jira but could not be imported into Beads."
     - List applicable known reasons based on what you found:
       * *JQL mismatch*: ticket isn't assigned to `currentUser()` or summary doesn't satisfy the filter. The sync will never auto-import it. See CLAUDE.md pitfall #26.
       * *Incremental timing gap*: ticket matches the JQL but hasn't been updated since the last sync run — it falls outside the delta window. Known pitfall: `bd-jira-sync-pull-incremental-timing-gap-sync`. Running `bd jira sync --pull` again may not help if the ticket still has no recent activity.
       * *Done ticket pre-dating first sync*: ticket is in Done status and was Done when the first full sync ran. See CLAUDE.md pitfall #27.
     - Offer: `(a) Create a manual mirror: bd create --title '<KEY> · <summary>' --label=src:jira --external-ref=<jira-url>; (b) Full investigation with /jira-show <KEY>.`
     - **Record any newly discovered failure mode** not matching the above: run `bd remember "jira-sync-failure: <concise description>"` before stopping.
     - Stop.

4. **Single-bead output.** Run `bd show <resolved_id>` via Bash and report the output verbatim. If `--with-context` was set, proceed to step 4a; otherwise stop.

   **4a. `--with-context` enrichment.**
   - **Keywords:** derive 2-4 specific nouns from the bead's title and labels (e.g. "pipeline", "snowflake", "BOCO-18077"). Avoid generic terms ("task", "open").
   - **Memories:** run `bd memories <keyword>` for each term via Bash. Deduplicate; keep substantively relevant entries (discard generic workflow entries that would appear for any bead).
   - **Doc links:** scan the bead's `NOTES` section for lines containing path fragments (`docs/`, `tasks/`, `.md`, `.sql`, `J121-pipelines/`) and extract them as a list.
   - Render as a `── Context ──` block appended after the main bead output:
     ```
     ── Context ──

     Memories (bd remember):
       • <key>: <first ~120 chars of value>
       • <key>: ...
       (none) if no relevant matches

     Supporting docs:
       • <path-or-link>
       • ...
       (none) if notes contain no path references
     ```
   - If both sections are empty, omit the Context block.

5. **Normalize `--priority` input.** Accept `--priority 2`, `--priority P2`, `--priority <=2`, or `--priority <=P2`. Strip any `P`/`p` prefix and any leading `<=`. Remember whether the user wrote `<=` (ceiling) vs. no prefix (exact).

6. **Resolve `--mine`.** If `--mine` was passed, set the assignee to `$(git config user.name)`. If `--assignee` was also passed, `--assignee` wins.

7. **Build the bd invocation.** Base command is `bd list` unless `--ready` was passed, in which case `bd ready`. Translate flags:

   | User flag               | bd flag                                                |
   |-------------------------|--------------------------------------------------------|
   | `--epic <id>`           | `--parent <id>`                                        |
   | `--area <name>`         | `--label=area:<name>` (repeatable if user repeats)     |
   | `--service <name>`      | `--label=svc:<name>`                                   |
   | `--assignee <name>` / `--mine` | `--assignee <name>`                             |
   | `--status <s>`          | `--status <s>` (bd list only; bd ready ignores)        |
   | `--priority <N>` (exact)| `--priority <N>`                                       |
   | `--priority <=N>` (ceiling) | *(post-filter in step 9)*                          |
   | `-n <N>`                | `--limit <N>`                                          |

   Always pass `--json`.

   **Note:** `bd ready` does not accept `--status`. If combined with `--ready`, drop `--status` silently — `bd ready` already excludes closed/deferred/blocked — and continue.

8. **Run the command via Bash.** If exit is non-zero, surface stderr and stop. If the JSON is `[]`, print:
   ```
   /show: no beads match the given filters.
   ```
   and stop. Do not suggest widening the filters.

   **Gotcha — `bd list --json` trailing footer.** When `bd list` hits its `-n` limit it appends a human-readable footer after the JSON array. Strip it before parsing: `sed -n '1,/^]$/p'`. `bd ready --json` does not have this bug.

9. **Post-filter for `--priority <=N>`** if a ceiling was provided. Keep only entries whose `priority` field is `<= N`.

10. **Render the list.** Compact table, one line per bead, bd's own sort order:
    ```
    ── /show · <filter summary or "default"> · <N> result(s) ──

     st  pri  id              title                                               labels
     ○   P0   J121-ao6        BOCO-14604 · Great Clips | Unit Test Dev…           src:jira
     ◐   P3   J121-9kp.2      (EPIC) Wave 2: Productivity…                        area:claude
     ...

    To inspect:  /show <id>   or   /show --jira <KEY>
    To start:    /start <id>
    ```
    Rules:
    - Status glyph: `○ open`, `◐ in_progress`, `● blocked`, `❄ deferred`, `✓ closed`.
    - Priority: `P<N>` left-padded to 2 chars.
    - Title: truncate at ~60 chars with `…`.
    - Labels: up to 3 most-informative; drop `src:jira` if row already shows a Jira key in title; drop `scope:local` as low-signal. Overflow: `+N`.
    - Footer when truncated: `<shown> of <total> matched; raise -n to see more`.
    - `<filter summary>`: terse recap, e.g. `epic=J121-9kp.2 · status=open · area=claude`. Use `default` if no filters.

11. **Do not editorialize.** No recommendations, no commentary. /show lists; /next recommends.

## Invariants

- **Read-only.** Never claim, close, transition, or update a bead from /show.
- **Pure wrapper.** All filtering goes through bd. No custom queries beyond the `--priority <=N>` ceiling post-filter and label trimming for display.
- **No fallbacks.** Empty result → say so and stop. Do not widen automatically.
- **Single-bead flags are exclusive.** `--task`, `--jira`, and bare positional ID are mutually exclusive with each other and with all list-mode flags. Only `--with-context` may accompany them.
- **`--jira` resolution records new pitfalls.** If a `--jira` failure mode isn't covered by CLAUDE.md pitfalls #26–28 or the `bd-jira-sync-*` bd remember entries, run `bd remember` to document it before stopping.

## Related

- `/next` — opinionated sibling: same filters, recommends one bead.
- `/start <id>` or `/start --jira <KEY>` — claim and begin the timer.
- `bd list --help` / `bd ready --help` — the underlying commands.
