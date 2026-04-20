# Jira @-Mention Convention

When drafting Jira comments locally, use `@{Display Name}` syntax for mentions (e.g., `@{Jane Doe}`). Before posting via the Atlassian MCP tools, replace all `@{...}` strings with proper ADF `mention` nodes using the account ID for each name.

## Why

Local drafts don't have Jira's autocomplete. The `@{...}` convention is unambiguous, non-colliding with ordinary `@` characters in text, and easy to find-and-replace programmatically at post time.

## How to apply

On every Jira post (comment, description, issue body):

1. **Scan** the draft for `@{...}` patterns.
2. **Resolve** each to an account ID using the engagement-specific lookup table (agent-level or project-level chezmoi template). Match on both Display Name and any declared Aliases.
3. **Construct** ADF `mention` nodes with the account ID. See `jira-adf-reference.md` for the node shape.
4. **Canonicalize** the `text` field to the full display name (e.g., `@Jane Doe`), even if the draft used an alias (e.g., `@{Jane}`).
5. **Halt on ambiguity.** If a `@{...}` pattern doesn't match any display name or alias, stop and ask for clarification. Do not post with unresolved mentions — plaintext `@{...}` in a posted comment is a visible failure.

## Account ID sourcing

Account ID tables are engagement-specific. For projects configured in Chezmoi, the IDs are typically pre-populated in a chezmoi template (`.chezmoitemplates/<context>`) that agent files pull in at apply time. For ad-hoc cases, look up via `mcp__claude_ai_Atlassian__lookupJiraAccountId` or extract from ticket data returned by other Atlassian MCP tools.
