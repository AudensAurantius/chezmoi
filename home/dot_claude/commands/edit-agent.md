---
name: edit-agent
description: Edit an existing subagent with additive metadata; re-scrutinize tool access and refusal paths if the system prompt changed
author: Michael Haynes
scope: global
tags: [meta-tooling, claude-config, agent-family]
timestamps:
  - action: created
    at: 2026-04-20T14:15:00-05:00
    actor: Michael Haynes
comments:
  - "Source: J121-9kp.2.6 meta-tooling wave 2 discussion (2026-04-20). Edit counterpart to /add-agent."
  - "Motivation: agent edits that modify the system prompt or tool allowlist change the agent's blast radius in ways the parent session never directly observes. The post-edit intent-summary step re-validates tool access and refusal paths."
  - "Projected use: invoke when an existing agent needs refinement. Preserves the `.md` vs `.md.tmpl` distinction (templated agents stay templated unless explicitly converted)."
related: [/add-agent, /remove-agent, /edit-command, /edit-skill, /resolve, /audit]
---

# /edit-agent — Modify an existing subagent

Locate an existing agent, present it for editing, merge metadata additively,
diff old vs. new, and deploy on confirmation. **If the system prompt or
tool allowlist changes, re-run the intent-summary step** from `/add-agent`
to re-validate tool access and refusal paths.

Arguments: $ARGUMENTS

## Argument shapes

- `/edit-agent <name>` — minimum. Default mode: write a working copy to
  `/tmp/claude-drafts/<name>-edit-<timestamp>.md`, print the path, stop.
  User edits externally, then re-invokes with `--from-draft=<path>`.
- `/edit-agent <name> --inline` — provide replacement body or targeted
  instruction directly in conversation.
- `/edit-agent <name> --from-draft=<path>` — resume after external editing.
- `/edit-agent <name> --global` — force lookup in
  `~/.local/share/chezmoi/home/dot_claude/agents/<name>.md` or
  `<name>.md.tmpl`.
- `/edit-agent <name> --local` — force lookup in
  `<project-root>/.claude/agents/<name>.md`.
- `/edit-agent <name> --note="<summary>"` — `note` for this edit's
  timestamp entry.
- `/edit-agent <name> --actor="<name>"` — override this edit's actor
  (defaults to `git config user.name`).
- `/edit-agent <name> --convert-to-template` — convert a `.md` agent to
  `.md.tmpl` (chezmoi-templated). Requires `--global`. Reverse:
  `--convert-from-template`. Both are explicit opt-ins — never auto.

Mutually exclusive groups:
- `--global` vs. `--local`
- `--inline` vs. `--from-draft`
- `--convert-to-template` vs. `--convert-from-template`

## Instructions

1. **Require a name.** If missing:
   ```
   /edit-agent: missing agent name
   usage: /edit-agent <name> [--global|--local] [--inline]
                     [--from-draft=<path>] [--note="<summary>"]
                     [--actor="<name>"]
                     [--convert-to-template|--convert-from-template]
   ```
   Strip leading `/`. Reject `/`, `..`, whitespace in name.

2. **Parse flags.** Reject unknowns. Enforce mutual-exclusion.

3. **Locate the live file.**
   - `--global`: check for `<name>.md` and `<name>.md.tmpl` in
     `~/.local/share/chezmoi/home/dot_claude/agents/`. If both exist,
     **halt and ask** (shouldn't happen — investigate before proceeding).
   - `--local`: `<project-root>/.claude/agents/<name>.md` (no templates
     in local scope).
   - Neither flag: auto-detect.
   - No file found: **halt and suggest `/add-agent`.**

4. **Check for divergence** (global only). `chezmoi diff
   ~/.claude/agents/<name>.md`. For templated agents, compare against the
   rendered output. Halt on unexpected drift.

5. **Check for metadata frontmatter.** Agents already require `name` +
   `description`. Missing other fields → offer retrofit as part of this
   edit (same pattern as `/edit-command` and `/edit-skill`).

6. **Open for editing.** Default: draft file at
   `/tmp/claude-drafts/<name>-edit-<timestamp>.md`. `--inline`: print
   inline + accept replacement or instruction.

7. **Merge metadata.** Same rules as `/edit-command`, with agent-
   specific additions:
   - **Preserve** `name`, `author`, `scope`, `description` (unless the
     user explicitly changed it), `tools` (unless explicitly changed).
   - **Append** a new `timestamps` entry: `action: edited`, `at`,
     `actor`, `note`.
   - **Append** to `comments` only on substantive shifts in purpose,
     scope, or tool-access posture.
   - **Agent-specific:** if `tools` expanded (broader allowlist), this
     is the blast-radius shift — flag in the confirmation prompt and
     re-run the intent summary (step 8).

8. **Re-run the intent summary if system prompt or `tools` changed.**
   *Mandatory.* State:
   - **What the agent does now** — restate the narrow job.
   - **Tool access** — cross-check the updated tool allowlist against
     the updated job. Look for asymmetries (broad tools + narrow
     instructions).
   - **Refusal paths** — the edited system prompt should still clearly
     enumerate what the agent refuses. If the edit weakened the
     refusal set, **flag it explicitly.**

9. **Handle template conversion** if flagged.
   - `--convert-to-template`: rename `<name>.md` to `<name>.md.tmpl` in
     chezmoi source. Warn the user to add template syntax (`{{ .Data
     }}`) as part of the edit; this command does not author template
     interpolation.
   - `--convert-from-template`: rename `.md.tmpl` to `.md`. Warn that
     existing template syntax will be treated as literal text until
     removed. Both conversions happen after deploy confirmation, not
     before.

10. **Diff + confirm.** Unified diff of old vs. new:
    - Body changes.
    - Metadata changes.
    - Tool allowlist changes (explicit line).
    - Template conversion (if any).
    Ask: `Deploy this edit? (yes / more edits / cancel)`.

    **If tools expanded or refusal set weakened**, include an explicit
    one-line summary: `Tool allowlist: Read,Grep → Read,Grep,Bash` or
    `Refusal set weakened: agent no longer refuses file writes`. Force
    the user to see it.

11. **On confirm.** Write merged content. `--global`: `chezmoi apply`
    (re-renders the template if applicable). Print:
    ```
    Edited:  <destination source path>
    Live at: <live path>
    Commit:  pending in chezmoi repo
    Timestamp appended: edited at <ISO> by <actor>
    Tools: <unchanged | "old" → "new">
    Note: <note>
    ```
    Remind to commit chezmoi when ready. **Never commit.**

12. **On cancel.** Discard. No writes. Working copies left in place.

## Invariants

- **Never remove existing metadata.** Append-only; explicit removal
  requires second confirmation.
- **Never skip the intent-summary step when system prompt or `tools`
  changed.** This is the load-bearing safeguard for agent edits.
- **Never overwrite live-file divergence silently.**
- **Never change `author`.** This edit's contributor goes in the new
  timestamp's `actor`.
- **Never implicitly convert `.md` ↔ `.md.tmpl`.** Requires explicit
  `--convert-*` flag.
- **Never commit.**
- **Halt if the agent doesn't exist.** Suggest `/add-agent`.
- **Flag tool-allowlist expansion explicitly.** Weakening the refusal
  set or broadening tools is the blast-radius shift; the user must see
  it in the confirmation prompt.

## Related

- `/add-agent` — create a new agent.
- `/remove-agent` — delete an agent (with echo-to-confirm friction).
- `/edit-command`, `/edit-skill` — same shape for other config kinds.
- `/resolve` — locate the live source of an agent, flag shadowing.
- `/audit --agent <name>` *(future)* — deeper behavioral audit.
