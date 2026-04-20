---
name: add-command-alias
description: Create a symlink alias for an existing slash command (commands only; no skill or agent aliasing)
author: Michael Haynes
scope: global
tags: [meta-tooling, claude-config, command-family, alias]
timestamps:
  - action: created
    at: 2026-04-20T14:45:00-05:00
    actor: Michael Haynes
comments:
  - "Source: J121-9kp.2.6 meta-tooling wave 2 discussion (2026-04-20). Commands-only by design — skills are directory-based (symlinking a SKILL.md doesn't re-parent the skill), agents have no natural aliasing story."
  - "Motivation: short aliases for long command names (/chk → /session-checkpoint) are cheap ergonomics wins. Codifying the chezmoi symlink_ pattern means aliasing is one command, not three steps."
  - "Projected use: invoke when an existing command deserves a shorter or alternate invocation. Refuses to alias a command that doesn't exist; refuses to alias skills or agents (errors with explanation)."
related: [/add-command, /edit-command, /remove-command, /resolve]
---

# /add-command-alias — Create a symlink alias for an existing command

Create a symlink alias for an existing slash command. Globals use chezmoi's
`symlink_<name>.md` pattern (file contents = target). Locals use plain
filesystem symlinks. **Commands only** — skills are directory-based and
agents lack a natural aliasing story; attempts to alias either error out
with an explanation.

Arguments: $ARGUMENTS

## Argument shapes

- `/add-command-alias <alias> <target>` — minimum. Creates `<alias>`
  pointing at `<target>`. Both names may be written with or without a
  leading `/`; Claude strips it.
- `/add-command-alias <alias> <target> --global` — default; writes to
  `~/.local/share/chezmoi/home/dot_claude/commands/symlink_<alias>.md`
  with contents `<target>.md`. After `chezmoi apply`, the live file at
  `~/.claude/commands/<alias>.md` is a symlink to `<target>.md`.
- `/add-command-alias <alias> <target> --local` — writes a plain
  filesystem symlink at `<project-root>/.claude/commands/<alias>.md`
  pointing at `<target>.md` in the same directory. No chezmoi.

Mutually exclusive: `--global` vs. `--local`.

## Instructions

1. **Require two name arguments.** If either is missing:
   ```
   /add-command-alias: missing argument
   usage: /add-command-alias <alias> <target> [--global|--local]
   ```
   Strip leading `/` from both names. Reject `/`, `..`, whitespace in
   either name.

2. **Refuse skill or agent aliasing.** If the user attempts
   `--kind=skill` or `--kind=agent` (or tries to alias a name that
   matches an existing skill/agent directory or file), halt with:
   ```
   /add-command-alias: aliases are commands-only.
   Skills are directory-based; aliasing a SKILL.md file doesn't
   re-parent the skill. Agents don't have a natural aliasing story.
   Use the original name directly.
   ```

3. **Verify the target exists.**
   - `--global`: check
     `~/.local/share/chezmoi/home/dot_claude/commands/<target>.md`.
   - `--local`: check `<project-root>/.claude/commands/<target>.md`.
   - If the target doesn't exist in the same scope, **halt and suggest
     `/add-command <target>` first.** Cross-scope aliasing (global alias
     → local target, or vice versa) is not supported.

4. **Verify the alias doesn't already exist.**
   - `--global`: check for existing files named `<alias>.md` or
     `symlink_<alias>.md` in the chezmoi commands dir, and for the live
     `~/.claude/commands/<alias>.md`.
   - `--local`: check `<project-root>/.claude/commands/<alias>.md`.
   - If anything exists at the alias name, **halt.** Suggest
     `/remove-command <alias>` first if the user actually wants to
     replace it, or pick a different alias name.

5. **Create the alias.**
   - `--global`: write a new file at
     `~/.local/share/chezmoi/home/dot_claude/commands/symlink_<alias>.md`
     whose contents are exactly:
     ```
     <target>.md
     ```
     (one line, no trailing newline beyond the standard). Then run
     `chezmoi apply`. Surface any errors verbatim.
   - `--local`: run `ln -s <target>.md
     <project-root>/.claude/commands/<alias>.md` via Bash. Surface errors.

6. **Report.**
   ```
   Alias:   /<alias>
   Target:  /<target>
   Source:  <chezmoi source path | live symlink path>
   Live:    <live symlink path>                  (global only)
   Commit:  pending in chezmoi repo              (global only)
   ```
   Remind the user to commit chezmoi when ready. **Never commit.**

## Invariants

- **Commands only.** Skills and agents are out of scope; reject
  explicitly with the canned error message.
- **Target must exist in the same scope.** No cross-scope aliasing.
- **Never overwrite an existing alias or command.** Halt and suggest
  `/remove-command <alias>` first.
- **`symlink_` prefix is the chezmoi convention.** Do not try to create
  a plain filesystem symlink in the chezmoi source — chezmoi won't
  know to treat it as a symlink at apply time.
- **Never commit.**

## Related

- `/add-command` — create a new command (aliases point at commands).
- `/edit-command`, `/remove-command` — modify or delete the target.
- `/resolve` — locate the live source of a command, including alias
  resolution (shows the alias and the underlying target).
