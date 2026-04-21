---
name: add-command
description: Author a new slash command from conversation context
author: Michael Haynes
scope: global
tags: [meta-tooling, claude-config, command-family]
timestamps:
  - action: created
    at: 2026-04-20T05:15:24-05:00
    actor: Michael Haynes
  - action: updated
    at: 2026-04-21T12:30:00-05:00
    actor: Michael Haynes
    note: "Added argument-hint to step 5a required fields and metadata invariant"
  - action: updated
    at: 2026-04-21T13:15:00-05:00
    actor: Michael Haynes
    note: "Added script-extraction guidance to step 5, step 6 review block, and invariants"
comments:
  - "Source: J121-9kp.2.6 meta-tooling wave 2 discussion (2026-04-20). First of three /add-* commands; the pattern-exemplar for /add-skill and /add-agent."
  - "Motivation: the project had accumulated enough ad-hoc slash commands that authoring-friction was worth formalizing. Prerequisite for the broader /add-*, /edit-*, /remove-* CRUD family."
  - "Projected use: invoke mid-conversation when a reusable pattern emerges that deserves preservation as a slash command. Default is inline-review-and-deploy; --create-draft for external editing."
related: [/edit-command, /remove-command, /add-command-alias, /add-skill, /add-agent, /resolve]
---

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
- `/add-command <name> --author="<name>"` — override the author (defaults
  to `git config user.name`).

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
   - Opens with a YAML frontmatter block (see step 5a below for required
     fields).
   - Uses `$ARGUMENTS` for the argument string.
   - Has an H1 heading `# /<name> — <purpose>` immediately below the
     frontmatter, matching the frontmatter `description` in purpose.
   - Numbered instructions for multi-step behavior.
   - Explicit halt conditions with concrete error messages.
   - Invariants (`Never X`, `Do not Y`) for destructive or ambiguous edges.
   - References to related commands.
   - **Scripts extracted, never embedded.** If the command needs to run a
     non-trivial bash script (more than ~5 lines, or invoked repeatedly),
     write it to the appropriate scripts directory rather than embedding it
     inline in the command body: `.claude/scripts/` for `--local` commands,
     `~/.claude/scripts/` for `--global` commands (chezmoi source:
     `~/.local/share/chezmoi/home/dot_claude/scripts/`). Reference it by
     absolute path. Reason: embedded multi-line scripts cannot be
     pre-authorized with granular `permissions.allow` rules — the permission
     checker evaluates the full blob, not individual lines inside it.

5a. **Metadata frontmatter — required for every new command.** Populate:
    - `name` — the command stem (filename without `.md`).
    - `description` — one-line purpose. The registry uses this verbatim, so
      write it to stand alone (no `/<name> —` prefix). Should convey the
      same purpose as the H1 in different words.
    - `argument-hint` — the argument signature shown in tab-completion and
      `/resolve` output (e.g., `"<bead-id> | --jira <JIRA-KEY>"`). Set to
      `""` explicitly when the command takes no arguments — omission looks
      identical to forgetting it, so explicit is always better.
    - `author` — `--author` flag value if provided, else
      `git config user.name`.
    - `scope` — `global` or `local`, matching the destination from step 3.
    - `tags` — categorical list (e.g., `[time-tracking, beads]`). Pick
      2-5 tags that would help `/resolve` or `/audit` group related tools.
    - `timestamps` — a single-entry list on creation:
      `[{action: created, at: <ISO-8601 now>, actor: <author>}]`. Edits
      append; never replace.
    - `comments` — array with at least three bullets covering:
      - **Source** — the conversation, bead, or decision that prompted
        creation (e.g., `"Source: J121-9kp.2.6 meta-tooling discussion
        (2026-04-20)."`).
      - **Motivation** — why this command earns its keep *now* (not just
        "it would be nice"). Ideally tied to an incident or friction
        pattern.
      - **Projected use** — expected invocation context and primary flow.
    - `related` — optional list of related tool names (`/edit-command`,
      etc.) for `/resolve` navigation.

   Models to follow: `~/.claude/commands/start.md` (thin wrapper),
   `~/.claude/commands/jira-create.md` (flag parsing + multi-tool workflow).

   **If the signal is weak, halt and ask** — do not invent. A vague
   `--focus="the important bit"` is not enough. Ambiguous conversations
   without clear reusable patterns are not enough. Halting is cheap; a
   plausible-looking bad command can cause silent drift for weeks.

6. **Present for review.**
   - Default: print the full proposed content inline and ask
     `Deploy this? (yes / edits / cancel)`.
   - If any companion scripts were written to `.claude/scripts/` or
     `~/.claude/scripts/`, include their full contents in the review block
     and propose the `permissions.allow` entry needed to pre-authorize each
     one (e.g., `"Bash(bash /path/to/script.sh)"`). The user reviews and
     approves both the command file and any scripts before deploy.
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
- **Every new command ships with metadata frontmatter.** `name`,
  `description`, `argument-hint` (set to `""` if the command takes no
  arguments), `author`, `scope`, `tags`, `timestamps` (one `created`
  entry), and a `comments` array with source/motivation/projected-use
  bullets. Missing metadata is a halt condition, not a warning.
- **H1 follows the canonical format** `# /<name> — <purpose>`. The H1 and
  the frontmatter `description` convey the same purpose in different
  phrasings. The registry uses frontmatter; the H1 is for readers-of-the-
  file.
- **Extract non-trivial bash to script files; never embed inline.** The
  permission checker evaluates the full blob of an embedded multi-line
  script — granular `permissions.allow` rules won't match lines inside it.
  Scripts >~5 lines or invoked repeatedly belong in `.claude/scripts/`
  (local) or `~/.claude/scripts/` (global). Add `Bash(bash <path>)` to
  the appropriate `settings.json` during deploy and include it in the
  review block.

## Related

- `/edit-command <name>` — modify an existing command.
- `/remove-command <name>` — delete with echo-to-confirm friction.
- `/add-command-alias <alias> <target>` — symlink alias for an existing
  command.
- `/add-skill`, `/add-agent` — same shape for the other config object kinds.
- `/resolve <name>` — locate the live source of a command, flag shadowing.
