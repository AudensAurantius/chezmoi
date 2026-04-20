# /post-comment — Post a Jira comment draft via the Atlassian MCP tool

Validate a Jira comment draft, resolve `@{Display Name}` mentions to ADF `mention` nodes, construct the full ADF payload, post via `mcp__claude_ai_Atlassian__addCommentToJiraIssue`, optionally transition the ticket, and update the draft's frontmatter to record the post.

Argument: $ARGUMENTS
Single argument: path to the draft file (relative or absolute). Quote the path if it contains spaces.

## Instructions

1. **Require a draft path.** If `$ARGUMENTS` is empty:

   ```
   /post-comment: missing draft path
   usage: /post-comment <path-to-draft.md>
     e.g. /post-comment tasks/BOCO-18077/comments/2026-04-20-status-update.md
   ```

   and stop.

2. **Load and parse the draft.** Read the file. Split YAML frontmatter from the body. Required frontmatter fields:

   - `ticket:` — Jira ticket ID; must match `/^[A-Z][A-Z0-9]+-\d+$/`.
   - `contentFormat: "adf"` — refuse to post anything with `markdown` or missing format.
   - `posted:` — must be `null`. If it's a timestamp, the comment is already posted; refuse and report the existing `comment_id`.

   Optional:
   - `target_status:` — a status name to transition the ticket to after posting.
   - `comment_id:` — must be `null` on an unposted draft.
   - `mentions:` — advisory; authoritative mention list comes from scanning the body.

3. **Resolve `@{…}` mentions.** Scan the body for `@{...}` patterns. For each, look up the account ID via the account-ID table in `~/.claude/agents/jira-comment-drafter.md` (or `.chezmoidata/atlassian.yaml` if reading the source). Match on display name first, then aliases. If any `@{…}` is unresolved or ambiguous, **halt and ask the user** — do not post. Replay the unresolved tokens verbatim so the user can fix them.

4. **Construct the ADF payload.** Walk the Markdown body and emit ADF JSON following the patterns in `~/.claude/references/jira-adf-reference.md`:

   - Paragraphs → `paragraph` nodes.
   - Headings → `heading` nodes with the appropriate `level`.
   - Bold / italic / inline code → `strong` / `em` / `code` marks on text nodes.
   - Bullet lists → `bulletList`/`listItem` tree. **All items at the same indentation level live in a single `bulletList` node** — never split sibling items into parallel lists.
   - Numbered lists → `orderedList`/`listItem`.
   - Code fences → `codeBlock` with optional `language`.
   - Inline links: `[text](url)` → text node with a `link` mark (`href: url`). **For Azure DevOps URLs** (`dev.azure.com`), use the bare URL as the display text to prevent Jira's Smart Link / `inlineCard` upgrade, which renders as broken.
   - `@{Display Name}` → `mention` node (`id`, `text: "@<canonical display name>"`, `accessLevel: ""`).

5. **Post via the MCP tool.** Call `mcp__claude_ai_Atlassian__addCommentToJiraIssue` with:

   - `cloudId`: the BOCO engagement value (`80b04637-628f-4df2-8bfa-012de201c08c` — also in `.chezmoidata/atlassian.yaml`).
   - `issueIdOrKey`: the ticket from frontmatter.
   - `body`: the constructed ADF document (type `doc`, version `1`, `content: [...]`).
   - `contentFormat: "adf"`.

   If the call fails, surface the error and **do not** modify the draft's frontmatter.

6. **Transition the ticket if `target_status` is set.** Call `mcp__claude_ai_Atlassian__getTransitionsForJiraIssue` to resolve the status name to a transition ID, then `mcp__claude_ai_Atlassian__transitionJiraIssue`. If the target status isn't an available transition, report the available options and skip the transition — do not fail the whole command over this.

7. **Update the draft's frontmatter** after a successful post:

   ```yaml
   posted: <ISO 8601 timestamp with timezone, e.g. 2026-04-20T09:15:42-05:00>
   comment_id: "<id returned by addCommentToJiraIssue>"
   ```

   Use the local timezone (prefer the system's, not UTC). Preserve any other frontmatter keys untouched.

8. **Report back** concisely:
   - Ticket and comment ID.
   - Mentions resolved (for reassurance).
   - Whether a transition fired, and the from→to statuses.
   - Draft path (so the user knows where the updated frontmatter lives).

   Do not echo the posted body.

## Invariants

- Never post with unresolved `@{…}` — halt first.
- Never post with `contentFormat: "markdown"` — refuse.
- Never re-post a draft that already has `posted: <timestamp>` — refuse.
- Do not use `jira issue comment add`. The CLI v2 endpoint drops mentions and list structure (verified 2026-04-20). MCP + ADF only.

## Related

- `/draft-comment <ticket-id> [guidance]` — the drafting companion.
- `jira-conventions` skill — canonical rules.
- `~/.claude/references/jira-adf-reference.md` — ADF node patterns.
