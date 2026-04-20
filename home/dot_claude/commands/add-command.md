# /add-command — Author a new slash command from conversation context

Draft a new slash command from recent conversation, present inline for review
(or write to a draft file), and deploy to the chezmoi source on confirmation.
Does not commit — the chezmoi repo remains under the user's control.

Arguments: $ARGUMENTS

## Argument shapes

- `/add-command <name>` — minimum. Claude reads recent conversation to pick the pattern.
- `/add-command <name> --global` — default; writes to
  `~/.local/share/chezmoi/home/dot_claude/commands/<name>.md`, then
  `chezmoi apply`.
- `/add-command <name> --local` — writes to
  `<project-root>/.claude/commands/<name>.md`; no chezmoi.
- `/add-command <name> --focus="<hint>"` — natural-language pointer to the
  relevant part of the conversation. Anchors Claude's selection.
- `/add-command <name> --from-file=<path>` — use the file's contents as the
  context source instead of conversation history. Overrides `--focus`.
- `/add-command <name> --create-draft[=<path>]` — writes the proposal to
  `<path>` (or `/tmp/claude-drafts/<name>-<timestamp>.md`) and stops. The
  user edits externally, then re-invokes with `--from-draft=<path>`.
- `/add-command <name> --from-draft=<path>` — skip drafting; load the file
  as final content and proceed to deploy confirmation.

Mutually exclusive groups:
- `--global` vs. `--local`
- `--from-file` vs. `--focus` (file overrides)
- `--from-draft` vs. `--create-draft`, `--focus`, `--from-file` (from-draft
  skips the drafting phase entirely)

## Instructions

1. **Require a name.** If `$ARGUMENTS` is empty or yields no name token:
   ```
   /add-command: missing command name
   usage: /add-command <name> [--global|--local] [--focus="<hint>"]
                       [--from-file=<path>] [--create-draft[=<path>]]
                       [--from-draft=<path>]
   ```
   Strip a leading `/` if the user included one. Reject names containing
   `/`, `..`, or whitespace.

2. **Parse flags.** Reject unknown flags rather than folding them into the
   name. Enforce the mutual-exclusion rules above — if violated, surface a
   clear error and stop.

3. **Determine destination.**
   - Global: source `~/.local/share/chezmoi/home/dot_claude/commands/<name>.md`,
     live `~/.claude/commands/<name>.md` after `chezmoi apply`.
   - Local: `<project-root>/.claude/commands/<name>.md`. Create `.claude/`
     and `.claude/commands/` if missing, but if the current directory doesn't
     look like a project root (no `.git`, no `CLAUDE.md`, no existing
     `.claude/`), **ask before creating.**
   - If a file already exists at the destination, **halt and suggest
     `/edit-command` instead.** Never overwrite.

4. **Summarize intent.** *Mandatory step — never skip.* Before drafting the
   full body, state in one sentence what you believe the command is meant to
   do, drawing on:
   - `--focus` if provided, as the primary anchor;
   - `--from-file` contents if provided (overrides `--focus`);
   - recent conversation otherwise, biased toward the most recent reusable
     pattern the user and Claude discussed.

   Ask the user to confirm or redirect. Cheap sanity check that catches
   misreads early. Example:

   ```
   I'll draft /foo to wrap `bd ready` with scoring that weights P0/P1
   above P2+. Confirm or redirect?
   ```

5. **Draft the content.** On confirmation, distill the selected context into
   a reusable prompt template. A good slash command:
   - Uses `$ARGUMENTS` for the argument string.
   - Opens with a short heading stating the purpose in one sentence.
   - Numbered instructions for multi-step behavior.
   - Explicit halt conditions with concrete error messages.
   - Invariants (`Never X`, `Do not Y`) for destructive or ambiguous edges.
   - References to related commands.

   Models to follow: `~/.claude/commands/start.md` (thin wrapper),
   `~/.claude/commands/jira-create.md` (flag parsing + multi-tool workflow).

   **If the signal is weak, halt and ask** — do not invent. A vague
   `--focus="the important bit"` is not enough. Ambiguous conversations
   without clear reusable patterns are not enough. Halting is cheap; a
   plausible-looking bad command can cause silent drift for weeks.

6. **Present for review.**
   - Default: print the full proposed content inline and ask
     `Deploy this? (yes / edits / cancel)`.
   - `--create-draft`: write to the chosen path, print it, stop. On the
     user's return, re-invoke with `--from-draft=<path>`.

7. **On confirm.**
   - Write final content to the destination.
   - `--global`: run `chezmoi apply` via Bash; surface any errors verbatim.
   - Print:
     ```
     Wrote:   <destination source path>
     Live at: <live path>             (global only, after chezmoi apply)
     Commit:  pending in chezmoi repo (global only)
     ```
   - Remind the user to commit chezmoi when ready. **Never commit.**

8. **On cancel.** Discard the proposal. No writes. If `--create-draft` was
   in play, leave the draft file — the user asked for it.

## Invariants

- Never overwrite an existing command. `/edit-command` is the explicit path.
- Never commit. Chezmoi repo hygiene is the user's call.
- Never skip the intent-summary step. It is the cheapest safeguard against
  drafting the wrong thing.
- Halt rather than generate from vague signal. `--focus="the important bit"`
  is not enough; an unfocused conversation is not enough.
- Name must not contain `/`, `..`, or whitespace. Lowercase with hyphens is
  convention.

## Related

- `/edit-command <name>` — modify an existing command.
- `/remove-command <name>` — delete with echo-to-confirm friction.
- `/add-command-alias <alias> <target>` — symlink alias for an existing
  command.
- `/add-skill`, `/add-agent` — same shape for the other config object kinds.
- `/resolve <name>` — locate the live source of a command, flag shadowing.
