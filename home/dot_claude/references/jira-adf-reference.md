# Jira ADF Construction Reference

Patterns for constructing ADF (Atlassian Document Format) payloads when posting via `mcp__claude_ai_Atlassian__addCommentToJiraIssue` with `contentFormat: "adf"`.

**Never use `contentFormat: "markdown"` for comments with mentions, ADO links, or nested bullets** — see `jira-draft-frontmatter.md` for why.

## Mention node (replaces plaintext `@Name`)

```json
{
  "type": "mention",
  "attrs": {
    "id": "<accountId>",
    "text": "@Display Name",
    "accessLevel": ""
  }
}
```

Example — rendered correctly:

```json
{"type": "text", "text": " "},
{"type": "mention", "attrs": {"id": "712020:066cc9a8-...", "text": "@Jane Doe", "accessLevel": ""}},
{"type": "text", "text": " has already moved the ticket to In Review"}
```

Account IDs come from the engagement-specific table (chezmoi template) — see `jira-mention-convention.md`.

## Link mark (for ADO URLs — avoids Smart Link / inlineCard)

```json
{
  "type": "text",
  "text": "https://dev.azure.com/<org>/<project>/_git/<repo>?path=/path/to/file",
  "marks": [
    {
      "type": "link",
      "attrs": {
        "href": "https://dev.azure.com/<org>/<project>/_git/<repo>?path=/path/to/file"
      }
    }
  ]
}
```

Use the **bare URL as the display text** to prevent Jira from upgrading the link to a Smart Link card (which renders as broken for ADO URLs).

## Bullet list with nested sub-bullets

```json
{
  "type": "bulletList",
  "content": [
    {
      "type": "listItem",
      "content": [
        {
          "type": "paragraph",
          "content": [{"type": "text", "text": "First item"}]
        }
      ]
    },
    {
      "type": "listItem",
      "content": [
        {
          "type": "paragraph",
          "content": [{"type": "text", "text": "Second item with sub-bullet"}]
        },
        {
          "type": "bulletList",
          "content": [
            {
              "type": "listItem",
              "content": [
                {
                  "type": "paragraph",
                  "content": [{"type": "text", "text": "Sub-bullet"}]
                }
              ]
            }
          ]
        }
      ]
    }
  ]
}
```

**Key invariant:** ALL items at the same indentation level must live inside a SINGLE `bulletList` node. Jira's markdown converter sometimes splits items into separate `bulletList` nodes, breaking visual continuity. ADF construction must keep the list tree intact.
