---
name: edit-skill
description: Edit an existing skill with additive metadata and mandatory trigger-overlap re-check if the description changes
author: Michael Haynes
scope: global
tags: [meta-tooling, claude-config, skill-family, high-blast-radius]
timestamps:
  - action: created
    at: 2026-04-20T14:15:00-05:00
    actor: Michael Haynes
comments:
  - "Source: J121-9kp.2.6 meta-tooling wave 2 discussion (2026-04-20). Edit counterpart to /add-skill."
  - "Motivation: skill edits are the most dangerous edit operation in the CRUD family because a changed description/trigger silently changes auto-invocation behavior across all future sessions. The overlap re-check step is not optional."
  - "Projected use: invoke when an existing skill needs refinement. Description changes trigger a full overlap survey against the rest of the skill corpus before deployment."
related: [/add-skill, /remove-skill, /edit-command, /edit-agent, /resolve, /audit]
---

# /edit-skill — Modify an existing skill

Locate an existing skill, present it for editing, merge metadata additively
(preserve existing comments, append a new timestamp entry), diff old vs.
new, and deploy on confirmation. **If the `description`/trigger changes,
re-run the overlap survey against the existing skill corpus** — a modified
trigger can silently collide with other skills.

Arguments: $ARGUMENTS

## Argument shapes

- `/edit-skill <name>` — minimum. Default mode: write a working copy to
  `/tmp/claude-drafts/<name>-edit-<timestamp>.md`, print the path, stop.
  User edits externally, then re-invokes with `--from-draft=<path>`.
- `/edit-skill <name> --inline` — provide the replacement body or a
  targeted instruction directly in conversation.
- `/edit-skill <name> --from-draft=<path>` — resume after external editing.
- `/edit-skill <name> --global` — force lookup in
  `~/.local/share/chezmoi/home/dot_claude/skills/<name>/SKILL.md`.
- `/edit-skill <name> --local` — force lookup in
  `<project-root>/.claude/skills/<name>/SKILL.md`.
- `/edit-skill <name> --note="<summary>"` — `note` for this edit's
  timestamp entry.
- `/edit-skill <name> --actor="<name>"` — override this edit's actor
  (defaults to `git config user.name`).

Mutually exclusive groups:
- `--global` vs. `--local`
- `--inline` vs. `--from-draft`

## Instructions

1. **Require a name.** If missing:
   ```
   /edit-skill: missing skill name
   usage: /edit-skill <name> [--global|--local] [--inline]
                      [--from-draft=<path>] [--note="<summary>"]
                      [--actor="<name>"]
   ```
   Strip leading `/`. Reject `/`, `..`, whitespace in name.

2. **Parse flags.** Reject unknowns. Enforce mutual-exclusion.

3. **Locate the live file.**
   - `--global`: source at `~/.local/share/chezmoi/home/dot_claude/skills/<name>/SKILL.md`.
   - `--local`: `<project-root>/.claude/skills/<name>/SKILL.md`.
   - Neither: auto-detect. If both exist, **halt and ask.**
   - No file found: **halt and suggest `/add-skill`.**

4. **Check for divergence** (global only). `chezmoi diff
   ~/.claude/skills/<name>/SKILL.md`. If the live file differs from the
   expected render, halt and surface.

5. **Check for metadata frontmatter.** Skills already require `name` +
   `description`. If other fields (author, scope, tags, timestamps,
   comments) are missing, offer to retrofit as part of this edit
   (construct initial `timestamps[0]` from the first-git-commit date,
   add author/scope/tags/comments per `/add-skill` rules).

6. **Open for editing.** Default: draft file at
   `/tmp/claude-drafts/<name>-edit-<timestamp>.md`. `--inline`: print
   inline + accept replacement or instruction.

7. **Merge metadata.** Same rules as `/edit-command`, with skill-
   specific additions:
   - **Preserve** `name`, `author`, `scope`; the original `description`
     is preserved *unless the user explicitly changed it*.
   - **Append** a new `timestamps` entry: `action: edited`, `at`,
     `actor`, `note`.
   - **Append** to `comments` only on substantive scope/purpose shifts.
   - **Skill-specific:** if `tags` included `high-blast-radius` and the
     edit narrows the trigger, consider dropping the tag (ask first).
     If the edit broadens the trigger, the tag is warranted — add if
     missing.

8. **Re-run the overlap survey if `description` changed.** *Mandatory,
   never skip when the trigger changed.* List the current skill corpus,
   scan their `description` fields for overlap with the new trigger.
   Two failure modes:
   - **New overlap** — the edit's new trigger overlaps with another
     skill that the old trigger did not. Halt and ask; this is the
     exact silent-drift scenario the overlap check is designed to
     catch.
   - **Contradiction** — new trigger contradicts another skill's
     domain. Halt and ask.

   If no overlap, proceed.

9. **Diff + confirm.** Show unified diff of old vs. new:
   - Body changes.
   - Metadata changes (appended timestamp/comment, updated tags, any
     description change).
   Ask: `Deploy this edit? (yes / more edits / cancel)`.

   **If the description/trigger changed**, include a one-line summary of
   the trigger shift in the confirmation prompt (e.g., `Trigger shift:
   "Python scripts" → "Python scripts + shell scripts"`). Make the
   change visible.

10. **On confirm.** Write merged content. `--global`: `chezmoi apply`.
    Print:
    ```
    Edited:  <destination source path>
    Live at: <live path>
    Commit:  pending in chezmoi repo
    Timestamp appended: edited at <ISO> by <actor>
    Trigger: <unchanged | "old" → "new">
    Note: <note>
    ```
    Remind to commit chezmoi when ready. **Never commit.**

11. **On cancel.** Discard. No writes. Working copies at
    `/tmp/claude-drafts/` left in place.

## Invariants

- **Never remove existing metadata.** Append-only; explicit removal
  requires a second confirmation.
- **Never skip the overlap survey when the description changed.** This
  is the load-bearing safeguard for skill edits.
- **Never overwrite live-file divergence silently.**
- **Never change `author`.** This edit's contributor goes in the new
  timestamp's `actor`.
- **Never commit.**
- **Halt if the skill doesn't exist.** Suggest `/add-skill`.
- **Flag broadening triggers explicitly.** An edit that widens a
  skill's trigger scope (more auto-fires) is the silent-drift
  scenario. Even if no overlap is detected, state the scope change
  in the confirmation prompt.

## Related

- `/add-skill` — create a new skill.
- `/remove-skill` — delete a skill (with echo-to-confirm friction).
- `/edit-command`, `/edit-agent` — same shape for other config kinds.
- `/resolve` — locate the live source of a skill, flag shadowing.
- `/audit --skill <name>` *(future)* — deeper behavioral audit.
