---
name: jira-conventions
description: Drafting and posting Jira comments in ADF with resolved @-mentions. TRIGGER when drafting, composing, editing, or posting a Jira comment; when constructing ADF payloads for `addCommentToJiraIssue`; when the user writes `@{Display Name}` in a draft destined for Jira; when touching files under `tasks/<ticket>/comments/`. Codifies: ADF-always posting format, `@{Display Name}` draft syntax, draft frontmatter (posted, comment_id, target_status, contentFormat: adf), analysis-vs-status-update style distinction. Canonical references: `~/.claude/references/jira-*.md`.
author: Michael Haynes
scope: global
tags: [jira, comments, adf, atlassian, mcp]
timestamps:
  - action: created
    at: 2026-04-20T03:31:18-05:00
    actor: Michael Haynes
comments:
  - "Source: J121-9kp.1.4 Jira integration bundle (2026-04-20). Paired with the jira-comment-drafter agent, /draft-comment and /post-comment slash commands."
  - "Motivation: Jira comments with mentions, nested bullets, or ADO links break in subtle ways when posted as markdown (v2 endpoint conversion). The only reliable path is ADF via MCP. Without a skill encoding this rule, Claude defaults to jira-cli and corrupts the comment. Verified against BOCO-18250."
  - "Projected use: fires on any Jira comment authoring/posting flow. Forces contentFormat=adf, resolves @{Display Name} against the engagement's account-ID table, distinguishes analysis vs. status-update structural norms. Pointers to four reference docs under ~/.claude/references/."
---

# Jira Comment Conventions

Drafting and posting conventions for Jira comments. The `jira-comment-drafter` agent loads this skill; the `/draft-comment` and `/post-comment` slash commands depend on it.

## Must-know rules

1. **Always post with `contentFormat: "adf"`.** Never `"markdown"`. Markdown mode breaks mentions, upgrades ADO URLs to broken Smart Link `inlineCard` nodes, and fragments nested bullet lists. See `~/.claude/references/jira-draft-frontmatter.md` for the bug inventory.

2. **Draft mentions as `@{Display Name}`.** Resolve to ADF `mention` nodes at post time, using the account-ID table embedded in the `jira-comment-drafter` agent (source: `.chezmoidata/atlassian.yaml`). **Halt on ambiguity** — a stray plaintext `@{…}` in a posted comment is a visible failure.

3. **Classify every draft: analysis vs. status update.** Different structural norms — see `~/.claude/references/jira-comment-style.md`. Universal rule: lead with "what did we do and how" before "what did we find". **Never** include prescriptive "Next steps" sections in analysis comments.

4. **Comment drafts live in `tasks/<ticket>/comments/`** with the frontmatter scaffold from `~/.claude/references/jira-draft-frontmatter.md`. The draft is the single source of truth for its own post state (`posted`, `comment_id`); do not duplicate status in memory or other tracking docs.

## Posting path: MCP tool only

Posting goes through `mcp__claude_ai_Atlassian__addCommentToJiraIssue` with `contentFormat: "adf"`. The `/post-comment` slash command handles the full pipeline.

**Do not substitute `jira issue comment add` for comment posting.** The jira-cli path hits a v2 endpoint that does partial wiki-markup conversion: mentions (`[~accountid:...]`), nested bullet lists (`*` / `**`), wiki-style named links (`[label|url]`), and bold vs. italic semantics all survive as literal text or wrong marks. Verified empirically 2026-04-20 against BOCO-18250 (canceled test ticket). The one thing jira-cli does NOT trigger is the Smart Link `inlineCard` upgrade for ADO URLs — but the ADF path gets that right too, via bare-URL `link` marks.

`jira` CLI remains useful for issue creation, viewing, and non-comment workflows — just not for posting comments with any structure.

### jira-cli gotcha (for issue create / view)

`--no-input` does not fully suppress interactive prompts when a required custom field (e.g., `Client`) isn't declared in `~/.config/.jira/.config.yml`. The child process hangs on stdin. Either pre-declare custom fields in the jira-cli config, or supply the field via `--custom Client="..."` (a warning fires but the server accepts the value).

## Slash commands

| Command | Purpose |
|---|---|
| `/draft-comment <ticket-id> [guidance]` | Invokes the `jira-comment-drafter` subagent to produce a draft in `tasks/<ticket-id>/comments/YYYY-MM-DD-<slug>.md` with the frontmatter scaffold. Optional `guidance` argument steers tone, focus, or length. |
| `/post-comment <draft-path>` | Validates frontmatter, resolves `@{…}` mentions, constructs ADF, posts via the Atlassian MCP tool, optionally transitions the ticket if `target_status` is set, updates the draft's frontmatter with `posted` timestamp and `comment_id`. |

## ADF construction patterns

The `~/.claude/references/jira-adf-reference.md` file is the canonical reference. Summary:

- **Mention:** `{"type": "mention", "attrs": {"id": "<accountId>", "text": "@<Display Name>", "accessLevel": ""}}`. Canonicalize `text` to the full display name even if the draft used an alias.
- **ADO URL:** plain text node carrying the bare URL, with a `link` mark whose `href` equals that same URL. Using the URL as display text prevents Jira's Smart Link upgrade.
- **Nested bullets:** all items at the same indentation level must live inside a **single** `bulletList` node. Jira's markdown converter sometimes splits them into sibling `bulletList` nodes, breaking visual continuity.

## References

- `~/.claude/references/jira-comment-style.md` — analysis-vs-status-update structural distinctions, voice rules.
- `~/.claude/references/jira-draft-frontmatter.md` — YAML frontmatter scaffold, why ADF not markdown.
- `~/.claude/references/jira-mention-convention.md` — `@{Display Name}` syntax, resolution rules.
- `~/.claude/references/jira-adf-reference.md` — ADF node patterns for mentions, links, nested bullets.
- `~/.claude/agents/jira-comment-drafter.md` — subagent that loads this skill; embeds the engagement's account-ID table via chezmoi template.
- `~/.local/share/chezmoi/home/.chezmoidata/atlassian.yaml` — account-ID source of truth.

## When to invoke this skill autonomously

- User says "draft a Jira comment", "write a comment for BOCO-…", "post this to Jira".
- User types `@{…}` in a file that looks like a Jira draft (frontmatter with `ticket:` and `contentFormat:`).
- User invokes `/draft-comment` or `/post-comment`.
- Any time you are about to construct an ADF payload targeting `addCommentToJiraIssue`.
