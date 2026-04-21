---
name: edit-command
description: Edit an existing slash command with additive metadata (comments preserved, timestamps appended)
author: Michael Haynes
scope: global
tags: [meta-tooling, claude-config, command-family]
timestamps:
  - action: created
    at: 2026-04-20T14:15:00-05:00
    actor: Michael Haynes
comments:
  - "Source: J121-9kp.2.6 meta-tooling wave 2 discussion (2026-04-20). Second command in the CRUD family; pair with /add-command."
  - "Motivation: modifying commands required manual file edits plus remembering to preserve frontmatter metadata, append timestamps, and leave author-comments additive. /edit-* formalizes all three."
  - "Projected use: invoke when an existing command needs refinement. Default mode writes a working copy for external editing; --inline mode accepts replacement content or targeted instructions directly in conversation."
related: [/add-command, /remove-command, /add-command-alias, /edit-skill, /edit-agent, /resolve]
---

# /edit-command — Modify an existing slash command

Locate an existing command, present it for editing (either as a working copy
for external editing or inline), merge metadata additively (preserve
existing comments, append a new timestamp entry), diff old vs. new, and
deploy on confirmation.

Arguments: $ARGUMENTS

## Argument shapes

- `/edit-command <name>` — minimum. Default mode: write a working copy to
  `/tmp/claude-drafts/<name>-edit-<timestamp>.md`, print the path, stop.
  User edits externally, then re-invokes with
  `--from-draft=<path>` to resume.
- `/edit-command <name> --inline` — user provides the replacement body or
  a targeted instruction ("change the description to X", "add a --force
  flag") directly in the next message. No external draft file.
- `/edit-command <name> --from-draft=<path>` — resume after external
  editing; load the file and proceed to diff + confirm.
- `/edit-command <name> --global` — force lookup in
  `~/.local/share/chezmoi/home/dot_claude/commands/`.
- `/edit-command <name> --local` — force lookup in
  `<project-root>/.claude/commands/`.
- `/edit-command <name> --note="<summary>"` — the `note` field for this
  edit's timestamp entry (e.g., `"Added --force flag"`). If omitted,
  Claude derives a one-line summary from the diff.
- `/edit-command <name> --actor="<name>"` — override the edit's actor
  (defaults to `git config user.name`). The original `author` field is
  preserved across edits.

Mutually exclusive groups:
- `--global` vs. `--local` (auto-detect if neither given; halt if both
  locations have a file with the given name)
- `--inline` vs. `--from-draft` (from-draft is the resume path)

## Instructions

1. **Require a name.** If `$ARGUMENTS` is empty or yields no name token:
   ```
   /edit-command: missing command name
   usage: /edit-command <name> [--global|--local] [--inline]
                        [--from-draft=<path>] [--note="<summary>"]
                        [--actor="<name>"]
   ```
   Strip a leading `/` if present. Reject names containing `/`, `..`, or
   whitespace.

2. **Parse flags.** Reject unknown flags. Enforce mutual-exclusion rules.

3. **Locate the live file.**
   - If `--global`: look in
     `~/.local/share/chezmoi/home/dot_claude/commands/<name>.md`.
   - If `--local`: look in `<project-root>/.claude/commands/<name>.md`.
   - If neither flag: auto-detect. Check both locations. **If both exist,
     halt and ask** which one to edit — silent precedence choice risks
     editing the wrong file.
   - If no file exists, **halt and suggest `/add-command`** instead.

4. **Check for divergence** (global only). Run `chezmoi diff
   ~/.claude/commands/<name>.md` via Bash. If the live `~/.claude/` file
   differs from the expected rendered output of the chezmoi source,
   **halt and surface the divergence.** Someone edited the live file
   without going through chezmoi; resolving the divergence precedes the
   edit. Do not silently overwrite.

5. **Check for metadata frontmatter.** Read the top of the source file.
   - If frontmatter is missing (file predates the metadata convention),
     notify the user and offer to retrofit during this edit. If accepted,
     construct the initial `timestamps` array with:
     - `action: created, at: <first-git-commit date>, actor: <first-git-
       commit author>`
     - followed by this edit's `action: edited` entry.
     Populate other required fields per the `/add-command` metadata rules,
     drawing `comments` bullets from the user's description of the file's
     purpose.
   - If frontmatter is present, proceed.

6. **Open for editing.**
   - Default mode: write the current file contents to
     `/tmp/claude-drafts/<name>-edit-<timestamp>.md`, print the path,
     stop. Tell the user to edit externally, then re-invoke with
     `--from-draft=<path>`.
   - `--inline` mode: print the current file contents inline, ask the
     user to provide either (a) the full replacement body or (b) a
     targeted instruction to apply. Execute the instruction, show the
     modified content, iterate until the user confirms.

7. **Merge metadata.** When the new content is ready:
   - **Preserve** the existing `name`, `description` (unless the user
     explicitly changed it), `author` (never change — the original
     author is load-bearing for attribution), `scope`.
   - **Update** `description` only if the user's change touches it —
     otherwise preserve. Flag a mismatch if the H1 changed but
     `description` didn't, or vice versa (the two should co-vary).
   - **Append** to `timestamps`:
     ```yaml
     - action: edited
       at: <ISO-8601 now>
       actor: <--actor or git config user.name>
       note: <--note or Claude-derived summary>
     ```
   - **Append** to `comments` *only if* the edit represents a substantive
     shift in the tool's purpose, scope, or motivation. Mechanical
     changes (bug fixes, flag additions) belong in `timestamps[].note`,
     not comments. Judgment call — when in doubt, ask.
   - **Update** `tags` if scope expanded (e.g., added `--deploy` flag
     might warrant a `high-blast-radius` tag). Again, judgment.
   - **Never remove** existing comments, timestamps, or the original
     `author`. Edits are additive.

8. **Diff + confirm.** Show a unified diff of old vs. new content,
   highlighting:
   - Body changes (the substantive edit).
   - Metadata changes (appended timestamp, any appended comment, any
     updated description/tags).
   Ask: `Deploy this edit? (yes / more edits / cancel)`.

9. **On confirm.**
   - Write the merged content to the chezmoi source (global) or the
     project-local path.
   - `--global`: run `chezmoi apply` via Bash; surface errors verbatim.
   - Print:
     ```
     Edited:  <destination source path>
     Live at: <live path>                     (global only)
     Commit:  pending in chezmoi repo          (global only)
     Timestamp appended: edited at <ISO> by <actor>
     Note: <note>
     ```
   - Remind the user to commit chezmoi when ready. **Never commit.**

10. **On cancel.** Discard the changes. No writes. If the working copy
    exists at a `/tmp/claude-drafts/` path, leave it — the user may want
    to salvage.

## Invariants

- **Never remove existing metadata.** Comments, timestamps, and the
  original `author` are append-only. Edits that would remove them are a
  halt condition (unless the user explicitly confirms removal with a
  second confirmation prompt — and even then, make it costly).
- **Never overwrite a live-file divergence silently.** If `chezmoi diff`
  shows unexpected drift, halt and surface.
- **Never change `author`.** The original-authorship attribution is
  load-bearing; this edit's contributor goes in the new timestamp's
  `actor` field.
- **Prefer `timestamps[].note` over new comments for mechanical changes.**
  The comments array is reserved for substantive shifts in purpose,
  scope, or motivation — not for every bug fix.
- **Always update `argument-hint` when flags change.** If an edit adds,
  removes, or renames any flag or positional argument, the `argument-hint`
  field must be updated in the same edit to reflect the new interface.
  An out-of-date `argument-hint` is a usage-documentation bug.
- **Never commit.** Chezmoi repo hygiene is the user's call.
- **Halt if the command doesn't exist.** Suggest `/add-command` and stop.
- **H1 and `description` should co-vary.** If an edit changes one, it
  should change the other. Flag mismatches.

## Related

- `/add-command` — create a new command.
- `/remove-command` — delete a command (with echo-to-confirm friction).
- `/add-command-alias` — symlink alias for an existing command.
- `/edit-skill`, `/edit-agent` — same shape for other config object kinds.
- `/resolve` — locate the live source of a command, flag shadowing.
