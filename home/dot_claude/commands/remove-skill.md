---
name: remove-skill
description: Delete an existing skill with echo-to-confirm friction and reference-check warning
author: Michael Haynes
scope: global
tags: [meta-tooling, claude-config, skill-family, destructive]
timestamps:
  - action: created
    at: 2026-04-20T14:30:00-05:00
    actor: Michael Haynes
comments:
  - "Source: J121-9kp.2.6 meta-tooling wave 2 discussion (2026-04-20). Third skill command; pair with /add-skill and /edit-skill."
  - "Motivation: removing a skill silently changes future-session behavior (auto-fires stop happening). Echo-to-confirm ensures the user sees the full skill content before it disappears; reference-check warns if any agent or command depends on the skill."
  - "Projected use: invoke when retiring an outdated convention or consolidating skills. Deletes the entire skill directory, not just SKILL.md — check for sidecar files first."
related: [/add-skill, /edit-skill, /remove-command, /remove-agent, /resolve]
---

# /remove-skill — Delete an existing skill

Delete a skill with three layers of friction: echo-to-confirm, reference-
check warning, and git-versioned recovery via chezmoi. Unlike commands,
skills live in a directory (`skills/<name>/SKILL.md`); this command
removes the entire directory, after warning about any sidecar files.

Arguments: $ARGUMENTS

## Argument shapes

- `/remove-skill <name>` — default.
- `/remove-skill <name> --global` — force chezmoi source lookup.
- `/remove-skill <name> --local` — force project-local lookup.
- `/remove-skill <name> --force` — skip echo-to-confirm (reference-check
  still runs).

Mutually exclusive: `--global` vs. `--local`.

## Instructions

1. **Require a name.** If missing:
   ```
   /remove-skill: missing skill name
   usage: /remove-skill <name> [--global|--local] [--force]
   ```
   Strip leading `/`. Reject `/`, `..`, whitespace.

2. **Parse flags.** Reject unknowns. Enforce mutual-exclusion.

3. **Locate the skill directory.**
   - `--global`: `~/.local/share/chezmoi/home/dot_claude/skills/<name>/`.
   - `--local`: `<project-root>/.claude/skills/<name>/`.
   - Neither: auto-detect. If both exist, **halt and ask.**
   - No directory found: **halt.** Nothing to remove.

4. **Check for sidecar files in the skill directory.** List the directory
   contents. If anything beyond `SKILL.md` exists (references, data
   files, scripts), surface the list and pause. The user may need to
   preserve those sidecars — confirm they're OK to delete or halt.

5. **Check for divergence** (global only). `chezmoi diff` over the
   skill directory. Unsaved changes → halt and surface.

6. **Reference-check.** Grep all tool files (global + local) for
   mentions of the skill name:
   - **Agents** that load this skill as part of their system prompt
     (e.g., "load the jira-conventions skill first").
   - **Commands** that reference the skill in their `related` frontmatter.
   - **Other skills** that cross-reference this one.

   Report as a warning. If `--force` is set, skip the grep and proceed
   with a prominent warning that references were not checked.

7. **Echo-to-confirm** (skipped if `--force`).
   - Print the full `SKILL.md` contents in a fenced block.
   - List any sidecar files in the skill directory.
   - Print the reference-check findings (if any).
   - Print:
     ```
     To confirm deletion, reply with exactly:
         yes remove <name>

     Any other reply aborts.
     ```
   - **Wait for the next user message.** Strict exact match.

8. **Delete.**
   - Remove the entire skill directory from the chezmoi source (global)
     or project-local path. Use `rm -rf` on the directory path — but
     only after the echo-to-confirm succeeded, since this is the step
     that actually writes destructive changes.
   - `--global`: `chezmoi apply` via Bash.
   - Print:
     ```
     Removed: <directory path>
     Live path: <live path>/ (now absent)
     Recovery: `git checkout HEAD~1 -- <directory path>/` in the chezmoi repo,
              followed by `chezmoi apply`.
     Sidecars deleted: <list>   (if any)
     ```
   - Remind the user to commit the deletion to chezmoi when ready.

9. **On abort.** No changes. Print `Deletion aborted. No changes made.`

## Invariants

- **Echo-to-confirm is strict.** Exact `yes remove <name>` match only.
- **The whole directory goes.** SKILL.md alone would leave an empty
  directory that confuses the skill loader. Delete the directory
  entirely or not at all.
- **Sidecar files require confirmation.** If the skill directory holds
  anything beyond SKILL.md, pause and list. User can abort or confirm.
- **Reference-check runs unless `--force` skips it.** Warn prominently
  on `--force`.
- **Never delete divergent live state without surfacing.**
- **Never commit.**
- **Recovery is git, not a trash dir.**

## Related

- `/add-skill` — create a new skill.
- `/edit-skill` — modify an existing skill.
- `/remove-command`, `/remove-agent` — same shape for other kinds.
- `/resolve` — locate the live source of a skill before deletion.
