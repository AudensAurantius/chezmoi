# /jira-create — Create a Jira issue, mirror to Beads, and scaffold a task dir

Create a Jira issue via the Atlassian MCP tool, mirror it as a Beads issue with `src:jira` + URL-formatted `external_ref` (indistinguishable from a `bd jira sync --pull` result), and scaffold the `tasks/<JIRA-KEY>/` working directory. All three artifacts are linked before the command returns.

Arguments: $ARGUMENTS

## Argument shapes

- `/jira-create <summary>` — minimum; defaults to Task
- `/jira-create <summary> --type=<Task|Bug|Story|...>`
- `/jira-create <summary> --priority=<P0..P4 | Highest..Lowest>` — applied to both Jira and Beads
- `/jira-create <summary> --description=<text>` or `--description-file=<path>`
- `/jira-create <summary> --project=<KEY>` — Jira project key (default: `BOCO`)
- `/jira-create <summary> --assignee="<Display Name>"` — resolved via MCP `lookupJiraAccountId`

Flags may appear before or after the summary and in any order. The summary is everything left after flag tokens are removed — quote it if it contains `--` literally.

## Instructions

1. **Require an argument.** If `$ARGUMENTS` is empty or yields an empty summary after flag removal:

   ```
   /jira-create: missing summary
   usage: /jira-create <summary> [--type=<type>] [--priority=<P0..P4|name>]
                       [--description=<text>|--description-file=<path>]
                       [--project=<KEY>] [--assignee="<Display Name>"]
   ```

   and stop.

2. **Parse arguments.** Strip recognized `--key=value` flag tokens; the remainder joined by single spaces is the summary. Reject unknown `--flags` rather than treating them as part of the summary.

3. **Defaults.**
   - `--type=Task`
   - `--project=BOCO` (matches the active BOLD Orange engagement)
   - `--priority=` unset → Jira and Beads use their respective project defaults
   - No description unless explicitly supplied

4. **Load description.** If `--description-file` is given, read the file; error and stop if missing. If both `--description` and `--description-file` are given, refuse — they are mutually exclusive. Treat the resulting text as plain Markdown/text; do not pre-convert to ADF (the MCP tool accepts a `description` string).

5. **Resolve priority.** If the user passed `P0..P4`, map to Jira names:

   | Beads | Jira     |
   |-------|----------|
   | P0    | Highest  |
   | P1    | High     |
   | P2    | Medium   |
   | P3    | Low      |
   | P4    | Lowest   |

   If the user passed a Jira name (Highest/High/Medium/Low/Lowest), pass it through to Jira and reverse-map for Beads. Pass unrecognized values through to Jira verbatim and let Jira reject them.

6. **Resolve assignee** (if `--assignee` set). Call `mcp__claude_ai_Atlassian__lookupJiraAccountId` with the display name and `cloudId: 80b04637-628f-4df2-8bfa-012de201c08c`. If ambiguous (multiple matches) or missing, **halt and ask the user** — do not guess.

7. **Create the Jira issue.** Call `mcp__claude_ai_Atlassian__createJiraIssue` with:

   - `cloudId`: `80b04637-628f-4df2-8bfa-012de201c08c`
   - `projectKey`: resolved project key
   - `summary`: the parsed summary
   - `issueTypeName`: resolved type
   - `description`: resolved description (omit if none)
   - `assignee_account_id`: resolved account ID (omit if none)
   - `additional_fields`: JSON object carrying anything else:
     - Priority goes here: `{"priority": {"name": "<Jira name>"}}`.
     - BOCO Task requires the `Client` custom field. If the user didn't supply one, **halt and ask** — don't pick one. Reference the pattern: `{"customfield_XXXXX": {"value": "<client name>"}}`. The BOCO `Client` field ID is **not** hardcoded here because we don't have a stable reference yet; surface the raw error if Jira rejects the create for missing custom fields, and let the user supply the field/value explicitly.

   On failure — especially "required field missing" for custom fields — surface the error verbatim and stop. **Do not create the Beads issue if Jira creation failed.**

   Record the returned Jira key (e.g. `BOCO-18251`) and its URL.

8. **Mirror to Beads.** Run (via Bash):

   ```bash
   bd create \
     --title "<summary>" \
     --type <bd-type> \
     --priority <bd-priority-0-4> \
     --external-ref "https://boldorange.atlassian.net//browse/<JIRA-KEY>" \
     --label src:jira \
     --metadata '{"source_system":"jira:<PROJECT>:<JIRA-KEY>","jira_type":"<Type>"}' \
     --silent
   ```

   Notes:
   - The **double slash** in the URL is deliberate. It matches the format `bd jira sync --pull` generates, keeping this bead indistinguishable from pulled ones.
   - Map Jira types to Beads types: `Task → task`, `Bug → bug`, `Story → feature`, `Epic → epic`. Unknown → `task`.
   - `--priority` accepts `0..4` numerically. Omit if unset.
   - If the description was loaded from `--description-file`, use `--body-file` on `bd create` instead of repeating the text inline.
   - `--silent` makes `bd create` emit just the bead ID on stdout.

   Capture the returned bead ID. If `bd create` fails, report the Jira key that was created and halt — let the user decide whether to hand-sync or `bd jira sync --pull`.

9. **Scaffold the task working directory.**

   - If a project-local `.claude/commands/task-init.md` exists **and** a `tasks/` directory sits at the project root, prefer invoking `/task-init <JIRA-KEY> --bead <bead-id>` equivalent logic. Specifically follow that command's steps (create dir, write `.beads`, stage).
   - Otherwise perform the minimal inline equivalent:

     ```bash
     mkdir -p tasks/<JIRA-KEY>
     printf '%s\n' '<bead-id>' > tasks/<JIRA-KEY>/.beads
     [ -d tasks/.git ] && git -C tasks add <JIRA-KEY>
     ```

   Do **not** commit. Subdir creation (`scripts/`, `comments/`, etc.) is out of scope — the user adds what they need.

10. **Report back.** Print a compact summary:

    ```
    Jira:  <JIRA-KEY>  https://boldorange.atlassian.net/browse/<JIRA-KEY>
    Beads: <bead-id>   (src:jira, priority P<n>)
    Dir:   tasks/<JIRA-KEY>/   (staged in tasks/ nested repo)
    ```

    If any optional field was set, list it: assignee, priority, type override.

## Invariants

- **Never create the Beads issue if Jira creation failed.** Partial state is worse than no state — the user can retry cleanly.
- **Never skip `src:jira` or the URL external_ref.** Downstream `bd jira sync --pull` matches on external_ref; mismatches create duplicate beads.
- **Never commit** in either the outer repo or the `tasks/` nested repo. Staging only.
- **Never guess** an assignee, project key, or required custom field. Ask the user.

## Related

- `/jira-show <key>` — briefing-style context display for an existing ticket.
- `/task-init` — the project-local task-dir scaffolder; this command defers to it when available.
- `/draft-comment <key> [guidance]` — once a ticket exists, draft a follow-up comment.
- `jira-conventions` skill — ADF, mention, and posting rules.
