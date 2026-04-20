# Jira Comment Draft Frontmatter Convention

Track Jira comment posting status in YAML frontmatter of the draft file itself — not in memory files, not in separate tracking docs. The draft is the single source of truth for its own state.

Drafts live under `tasks/<ticket-id>/comments/` in project working directories.

## Frontmatter template

```yaml
---
ticket: PROJECT-NNNN
title: Short ticket title
contentFormat: "adf"             # ALWAYS adf (see below)
posted: null                      # ISO 8601 timestamp after posting; null while draft
comment_id: null                  # Jira comment ID after posting; null while draft
target_status: "In Progress"      # optional: transition ticket on post
mentions:
  - Display Name
---
```

After posting, update `posted` and `comment_id`:

```yaml
posted: 2026-04-14T23:06:38-05:00
comment_id: "63205"
```

An unposted draft has `posted: null`. Do not duplicate this state elsewhere.

## Why ADF, never markdown

Jira's `contentFormat: "markdown"` has known issues:

1. **Mentions**: `@Name` in markdown renders as plaintext — Jira's converter does NOT resolve mentions. Must use ADF `mention` nodes with account IDs.
2. **ADO / dev.azure.com links**: Jira auto-upgrades `[text](url)` to Smart Link `inlineCard` nodes, but ADO URLs lack the metadata Jira needs, causing broken previews. Use bare URLs with ADF link marks.
3. **Nested bullets**: Sub-bullets in markdown can produce two separate `bulletList` nodes instead of one nested structure. ADF gives full control.
4. **Bullet icons in dark mode**: Unrelated Jira CSS issue, but worth noting — ADF produces correct structure, dark-mode rendering is not fixable from the API side.

**Standing rule:** Always post with `contentFormat: "adf"`. Construct ADF explicitly with proper mention nodes, link marks, and list structure.

## Future improvement (deferred)

`@atlaskit/editor-markdown-transformer` (Node, Atlassian's own Markdown-to-ADF converter) could automate the conversion. Would still need a post-processing step to resolve `@{...}` mention patterns into ADF mention nodes. Not yet implemented.
