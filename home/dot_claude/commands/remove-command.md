---
name: remove-command
description: Delete an existing slash command with echo-to-confirm friction and reference-check warning
author: Michael Haynes
scope: global
tags: [meta-tooling, claude-config, command-family, destructive]
timestamps:
  - action: created
    at: 2026-04-20T14:30:00-05:00
    actor: Michael Haynes
comments:
  - "Source: J121-9kp.2.6 meta-tooling wave 2 discussion (2026-04-20). Third command in the CRUD family; pair with /add-command and /edit-command."
  - "Motivation: deletion is the one CRUD operation where a slip has irrecoverable consequences (modulo git). The echo-to-confirm friction layer was chosen over a trash dir pattern because chezmoi is already git-versioned — recovery is `git checkout` and doesn't warrant a separate soft-delete store."
  - "Projected use: invoke when retiring a command. --force skips the echo-to-confirm for scripted cleanup; the reference-check warning and `never overwrite live-file divergence` invariant still apply."
related: [/add-command, /edit-command, /add-command-alias, /remove-skill, /remove-agent, /resolve]
---

# /remove-command — Delete an existing slash command

Delete a command with three layers of friction: (1) echo-to-confirm
requires the user's next message to be exactly `yes remove <name>`,
(2) reference-check warns if other tools mention the command, and
(3) git safety-net — chezmoi is git-versioned, so recovery is
`git checkout` from the chezmoi repo. `--force` skips echo-to-confirm
only.

Arguments: $ARGUMENTS

## Argument shapes

- `/remove-command <name>` — default. Full friction stack.
- `/remove-command <name> --global` — force chezmoi source lookup.
- `/remove-command <name> --local` — force project-local lookup.
- `/remove-command <name> --force` — skip echo-to-confirm. Reference-
  check and divergence-check still apply; this is for scripted
  cleanup, not blind deletion.

Mutually exclusive: `--global` vs. `--local`.

## Instructions

1. **Require a name.** If missing:
   ```
   /remove-command: missing command name
   usage: /remove-command <name> [--global|--local] [--force]
   ```
   Strip leading `/`. Reject `/`, `..`, whitespace.

2. **Parse flags.** Reject unknowns. Enforce mutual-exclusion.

3. **Locate the live file.**
   - `--global`: `~/.local/share/chezmoi/home/dot_claude/commands/<name>.md`.
   - `--local`: `<project-root>/.claude/commands/<name>.md`.
   - Neither: auto-detect. If both exist, **halt and ask.**
   - No file found: **halt.** Nothing to remove.

4. **Check for divergence** (global only). `chezmoi diff
   ~/.claude/commands/<name>.md`. If the live file differs from the
   chezmoi source, halt and surface — the user may have uncommitted
   changes worth preserving before deletion.

5. **Reference-check.** Grep all tool files in both global and local
   scopes for mentions of the command name. Report findings:
   - **Aliases** — any `symlink_*.md` in the chezmoi commands dir whose
     contents name this command. Removing the target breaks the alias.
   - **Cross-references** — any other command/skill/agent that
     references `/<name>` in its body or `related` frontmatter.

   Report as a warning, not a halt (the user may be intentionally
   retiring a family). If `--force` is set, skip the grep and proceed.

6. **Echo-to-confirm** (skipped if `--force`).
   - Print the full current file contents in a fenced block so the user
     sees what's about to disappear.
   - Print the reference-check findings (if any).
   - Print:
     ```
     To confirm deletion, reply with exactly:
         yes remove <name>

     Any other reply aborts.
     ```
   - **Wait for the next user message.** Do not delete until it arrives.
   - **Strict match.** The next message must match `^yes remove <name>$`
     (case-sensitive, no extra whitespace). Anything else → abort with
     `Deletion aborted. No changes made.`

7. **Delete.**
   - Remove the file from the chezmoi source (global) or project-local
     path.
   - `--global`: run `chezmoi apply` via Bash. The live file at
     `~/.claude/commands/<name>.md` disappears because the source is
     gone. Surface any chezmoi errors.
   - Print:
     ```
     Removed: <source path>
     Live path: <live path> (now absent)
     Recovery: `git checkout HEAD~1 -- <source path>` in the chezmoi repo,
              followed by `chezmoi apply`.
     ```
   - Remind the user to commit the deletion to chezmoi when ready.

8. **On abort.** No changes. Print `Deletion aborted. No changes made.`

## Invariants

- **Echo-to-confirm is strict.** The next message must match the exact
  `yes remove <name>` string. Partial matches, typos, or extra context
  abort the deletion. This is deliberate friction — do not soften it
  even when the user seems impatient.
- **Reference-check runs regardless of `--force`.** Well — see step 5;
  `--force` skips it. But warn prominently in the `--force` path that
  references were not checked.
- **Never delete a divergent live file without surfacing.** Unsaved
  changes may be hiding in the divergence.
- **Never commit.** Leave deletion uncommitted in the chezmoi repo
  until the user chooses.
- **Recovery path is git, not a trash dir.** Do not implement soft-
  delete or copy-to-trash — chezmoi is already versioned, and a
  separate trash store fragments the recovery story.

## Related

- `/add-command` — create a new command.
- `/edit-command` — modify an existing command.
- `/add-command-alias` — symlink alias; aliases are pointers, not
  content.
- `/remove-skill`, `/remove-agent` — same shape for other kinds.
- `/resolve` — locate the live source of a command before deletion.
