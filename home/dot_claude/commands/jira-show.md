---
name: jira-show
description: Fetch a Jira ticket + recent comments and present a context briefing with local-mirror pointers
argument-hint: <JIRA-KEY>
author: Michael Haynes
scope: global
tags: [jira, mcp, atlassian, read-only]
timestamps:
  - action: created
    at: 2026-04-20T03:52:31-05:00
    actor: Michael Haynes
comments:
  - "Source: J121-9kp.2.2 Jira workflow bundle (2026-04-20). Paired with /jira-create."
  - "Motivation: picking up inherited, stale, or handoff work needed a one-shot brief that went beyond 'bd show' — status, assignee, priority, description, recent comments, and pointers into the local tasks/<KEY>/ mirror."
  - "Projected use: invoke when returning to unfamiliar work, responding to a Jira mention, or before posting an update. Read-only; never mutates Jira. Comment bodies arrive as ADF despite responseContentFormat=markdown (known MCP quirk)."
related: [/jira-create, /draft-comment, /post-comment, "jira-conventions skill"]
---

# /jira-show — Context briefing for an existing Jira ticket

Fetch a Jira ticket and its recent comments, then present a briefing — status, assignee, priority, description, recent activity, local mirror pointers. Useful when picking up inherited or stale work.

Argument: $ARGUMENTS
Single token: the Jira key (e.g. `BOCO-18077`). Additional tokens are ignored.

## Instructions

1. **Require an argument.** If `$ARGUMENTS` is empty:

   ```
   /jira-show: missing ticket id
   usage: /jira-show <JIRA-KEY>
     e.g. /jira-show BOCO-18077
   ```

   and stop.

2. **Validate the key.** Match `^[A-Z][A-Z0-9]+-\d+$`. If it doesn't match, refuse — do not attempt a fetch or guess from partial input.

3. **Fetch the issue.** Call `mcp__claude_ai_Atlassian__getJiraIssue` with:

   - `cloudId`: `80b04637-628f-4df2-8bfa-012de201c08c`
   - `issueIdOrKey`: the key
   - `responseContentFormat`: `"markdown"` — the **description** will flatten to markdown; **comment bodies may still arrive as ADF** and must be handled per step 7. ADO URLs are fine at read time (the Smart-Link upgrade problem only matters on write).
   - `fields`: `["summary","status","priority","issuetype","assignee","reporter","created","updated","labels","description","comment"]`

   If the call returns a 404 or similar, surface the error verbatim and stop.

4. **Ensure comments are loaded.** If the `comment` field returned truncated or empty but the issue clearly has comments, fetch the last 10 via `mcp__claude_ai_Atlassian__fetch` against `/rest/api/3/issue/<key>/comment?maxResults=10&orderBy=-created`. Take the most recent 5 chronologically (oldest→newest within the window).

5. **Check the local mirror.** In parallel:
   - Run `bd list --label=src:jira --json | jq -r '.[] | select(.external_ref | endswith("/<KEY>")) | .id'` to find a mirrored bead ID. (If no mirror, note "no mirror" and move on — do not create one.) **`bd` must run from the repo root**, i.e. the parent of `.beads/`, not inside `.beads/` itself. If the user isn't in a beads workspace, skip this subcheck silently.
   - Check `tasks/<KEY>/` existence. If it exists, list any `comments/*.md` files (draft Jira comments, posted or otherwise).

6. **Compose the briefing.** Use this structure verbatim:

   ```
   ── <KEY> ─ <summary>

   Status:    <name>
   Type:      <issueType>
   Priority:  <name>
   Assignee:  <displayName or "Unassigned">
   Reporter:  <displayName>
   Created:   <YYYY-MM-DD>
   Updated:   <YYYY-MM-DD>
   Labels:    <comma-separated or "(none)">

   ── Description ──
   <description body, flattened to markdown>

   ── Recent comments (<n> of <total>) ──
   <author> · <YYYY-MM-DD HH:MM>
   <body>

   ────────

   <next comment…>

   ── Local links ──
   Beads:      <bead-id> | (no mirror)
   Task dir:   tasks/<KEY>/ | (none)
   Drafts:     comments/2026-04-20-analysis.md [posted 2026-04-20] | (none)
   ```

7. **Rendering.** With `responseContentFormat: "markdown"` the description pre-flattens but comment bodies typically still arrive as ADF. For ADF content, flatten to markdown covering: headings, paragraphs, bullet/numbered lists (preserving nesting), code blocks, inline `code` / **bold** / _italic_, links (`[text](url)`), mentions (display `@<Display Name>` if `text` attr is set, else `@<accountId>`). Render unknown node types as `[unsupported: <type>]` rather than dropping them. For markdown bodies, **strip over-escaped wiki artifacts** (`\*`, `\[`, `\]`, `\~`, `\_`, `\#`) except inside code fences — the server's markdown flattener escapes them defensively and they hurt readability.

8. **Do not editorialize.** This is a briefing, not an analysis. No "next steps", no interpretation. Present the facts.

## Invariants

- **Read-only.** Never transition, comment, edit, or modify the Jira ticket. Never create the Beads mirror if one is missing.
- **Never guess** values that aren't in the API response. If a field is missing, say so (`Priority: (unset)`) rather than inventing.
- **Never truncate** the description. Summaries belong in the task/commit/PR flow, not in a briefing.

## Related

- `/jira-create <summary>` — the companion that creates a new ticket.
- `/draft-comment <key> [guidance]` — draft a follow-up comment after reviewing the briefing.
- `/post-comment <draft-path>` — post a drafted comment.
- `jira-conventions` skill — when drafting a reply, these rules apply.
