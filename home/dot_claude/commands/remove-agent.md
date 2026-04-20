---
name: remove-agent
description: Delete an existing subagent with echo-to-confirm friction and reference-check warning
author: Michael Haynes
scope: global
tags: [meta-tooling, claude-config, agent-family, destructive]
timestamps:
  - action: created
    at: 2026-04-20T14:30:00-05:00
    actor: Michael Haynes
comments:
  - "Source: J121-9kp.2.6 meta-tooling wave 2 discussion (2026-04-20). Third agent command; pair with /add-agent and /edit-agent."
  - "Motivation: removing an agent breaks any command or skill that spawns it. The reference-check warns about such dependencies; echo-to-confirm ensures the user sees the system-prompt content before it disappears."
  - "Projected use: invoke when retiring an agent. Handles both .md and .md.tmpl files; verifies exactly one source exists for the given name before deleting."
related: [/add-agent, /edit-agent, /remove-command, /remove-skill, /resolve]
---

# /remove-agent — Delete an existing subagent

Delete an agent with three layers of friction: echo-to-confirm, reference-
check warning, and git-versioned recovery via chezmoi.

Arguments: $ARGUMENTS

## Argument shapes

- `/remove-agent <name>` — default.
- `/remove-agent <name> --global` — force chezmoi source lookup.
- `/remove-agent <name> --local` — force project-local lookup.
- `/remove-agent <name> --force` — skip echo-to-confirm (reference-check
  still runs).

Mutually exclusive: `--global` vs. `--local`.

## Instructions

1. **Require a name.** If missing:
   ```
   /remove-agent: missing agent name
   usage: /remove-agent <name> [--global|--local] [--force]
   ```
   Strip leading `/`. Reject `/`, `..`, whitespace.

2. **Parse flags.** Reject unknowns. Enforce mutual-exclusion.

3. **Locate the live file.**
   - `--global`: check for `<name>.md` and `<name>.md.tmpl` in
     `~/.local/share/chezmoi/home/dot_claude/agents/`. If both exist,
     **halt and ask** (abnormal — investigate first).
   - `--local`: `<project-root>/.claude/agents/<name>.md` (no templates
     in local scope).
   - Neither flag: auto-detect across both scopes and both extensions.
   - No file found: **halt.** Nothing to remove.

4. **Check for divergence** (global only). `chezmoi diff` over the agent
   file. For templated agents, compare against the rendered output.
   Halt on unexpected drift.

5. **Reference-check.** Grep all tool files (global + local) for
   mentions of the agent name:
   - **Commands** that spawn this agent via the Agent tool or via
     references in their instructions (e.g., `/draft-comment` invokes
     `jira-comment-drafter`).
   - **Skills** that reference the agent by name in their body or
     `related` frontmatter.

   Report as a warning. If `--force` is set, skip the grep but warn
   prominently.

6. **Echo-to-confirm** (skipped if `--force`).
   - Print the full agent file contents (including frontmatter) in a
     fenced block. For `.md.tmpl` files, print the raw source (pre-
     render); also note the rendered-output path.
   - Print the reference-check findings (if any).
   - Print:
     ```
     To confirm deletion, reply with exactly:
         yes remove <name>

     Any other reply aborts.
     ```
   - **Wait for the next user message.** Strict exact match.

7. **Delete.**
   - Remove the file from the chezmoi source (`.md` or `.md.tmpl`) or
     project-local path.
   - `--global`: `chezmoi apply` via Bash. For templated agents, the
     live rendered file at `~/.claude/agents/<name>.md` disappears.
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

- **Echo-to-confirm is strict.** Exact `yes remove <name>` match only.
- **Reference-check runs unless `--force` skips it.** Agents are
  frequently spawned by commands — the check catches the common
  dependency.
- **Handle `.md` and `.md.tmpl` uniformly.** Whichever exists is the
  source of truth; the user shouldn't need to know which.
- **Never delete divergent live state without surfacing.**
- **Never commit.**
- **Recovery is git, not a trash dir.**

## Related

- `/add-agent` — create a new agent.
- `/edit-agent` — modify an existing agent.
- `/remove-command`, `/remove-skill` — same shape for other kinds.
- `/resolve` — locate the live source of an agent before deletion.
