---
name: draft-comment
description: Draft a Jira comment via the jira-comment-drafter subagent, isolating ticket-history context
argument-hint: <ticket> [guidance]
author: Michael Haynes
scope: global
tags: [jira, comments, subagent, adf]
timestamps:
  - action: created
    at: 2026-04-20T03:31:46-05:00
    actor: Michael Haynes
comments:
  - "Source: J121-9kp.1.4 Jira integration bundle (2026-04-20). Paired with /post-comment and the jira-comment-drafter subagent."
  - "Motivation: drafting Jira comments with correct ADF formatting, @-mention resolution, and engagement-specific style rules needs enough context that inlining it in the main conversation fills the working context with Jira ticket history. Subagent isolation solves this."
  - "Projected use: invoke when composing a Jira comment. Optional guidance argument steers tone/focus. Produces a draft file in tasks/<ticket>/comments/ with YAML frontmatter tracking post state."
related: [/post-comment, /jira-create, /jira-show, "jira-conventions skill", "jira-comment-drafter agent"]
---

# /draft-comment — Draft a Jira comment via the jira-comment-drafter subagent

Delegate the drafting of a Jira comment to the `jira-comment-drafter` subagent. Isolates ticket-history reads and drafting context from the main conversation.

Arguments: $ARGUMENTS
First token: Jira ticket ID (e.g. `BOCO-18077`). Remainder: optional guidance for the drafter.

## Instructions

1. **Parse arguments.** The first whitespace-delimited token is the ticket ID; everything after is guidance. If `$ARGUMENTS` is empty:

   ```
   /draft-comment: missing ticket id
   usage: /draft-comment <TICKET-ID> [guidance]
     e.g. /draft-comment BOCO-18077 brief status update; flag pending deploy
   ```

   and stop.

2. **Sanity-check the ticket ID.** Match `/^[A-Z][A-Z0-9]+-\d+$/`. If it doesn't match, refuse and ask for clarification — do not attempt to fetch or guess.

3. **Invoke the subagent** via the Agent tool with `subagent_type: "jira-comment-drafter"`. Pass a self-contained prompt:
   - The ticket ID.
   - The guidance string (verbatim, if any).
   - An explicit instruction to fetch ticket context via `mcp__claude_ai_Atlassian__getJiraIssue` (cloudId from its embedded engagement context) and recent comments as needed.
   - The target draft path: `tasks/<TICKET-ID>/comments/<YYYY-MM-DD>-<slug>.md` using today's date and a short slug derived from the classification (e.g., `-analysis`, `-status-update`, or a topic keyword).
   - Reminder to apply the `jira-conventions` skill and the four `~/.claude/references/jira-*.md` files.
   - Reminder that the draft must have full frontmatter (`ticket`, `title`, `contentFormat: "adf"`, `posted: null`, `comment_id: null`, optional `target_status`, optional `mentions`) and that `posted` stays `null` until `/post-comment` runs.

4. **Respect existing drafts.** If a draft already exists at the target path, the subagent should revise in place (not overwrite a committed post). Instruct the subagent to halt if the existing draft has `posted: <timestamp>` set — posted comments are immutable from our side.

5. **Create the containing directory if needed.** `tasks/<TICKET-ID>/` may not exist. The subagent (or you, before invoking) should `mkdir -p tasks/<TICKET-ID>/comments/`.

6. **Report back** the draft path (relative to the project root), the classification chosen (analysis / status-update / other), and any `@{…}` mentions used. Do not echo the full draft — the user can open the file.

## Related

- `/post-comment <draft-path>` — the companion command that posts an approved draft.
- `jira-conventions` skill — canonical rules.
- `jira-comment-drafter` subagent — does the actual writing.
