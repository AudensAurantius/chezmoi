---
name: add-agent
description: Author a new subagent (system prompt + frontmatter) from conversation context
author: Michael Haynes
scope: global
tags: [meta-tooling, claude-config, agent-family]
timestamps:
  - action: created
    at: 2026-04-20T05:15:24-05:00
    actor: Michael Haynes
comments:
  - "Source: J121-9kp.2.6 meta-tooling wave 2 discussion (2026-04-20). Third of three /add-* commands."
  - "Motivation: subagents are medium-blast-radius — invocation is explicit, but system prompts are opaque during parent-agent sessions. A badly-scoped agent with broad tool access plus narrow instructions can take destructive actions the parent never sees."
  - "Projected use: invoke when a narrow-scope, reusable task emerges that deserves its own agent context (drafting a specific kind of document, auditing a specific concern). --tools flag for explicit allowlist; --template for chezmoi-templated agents embedding .chezmoidata/* content."
related: [/edit-agent, /remove-agent, /add-command, /add-skill, /resolve, /audit]
---

# /add-agent — Author a new subagent from conversation context

Draft a new subagent (system prompt + frontmatter) from recent conversation,
present inline for review, and deploy to the chezmoi source on confirmation.

**Blast radius:** medium. Agents are invoked explicitly (unlike skills), but
their system prompts are opaque to the main conversation — only the
invocation and the return value are visible. A badly-scoped agent can take
destructive actions inside a subagent context you never see directly, or
return confidently-wrong answers the main agent trusts. Auto-deploy is the
default (matching `/add-command`), but the intent-summary step scrutinizes
tool access and refusal paths more carefully than for commands.

Arguments: $ARGUMENTS

## Argument shapes

- `/add-agent <name>` — minimum. Claude reads recent conversation to pick
  the pattern.
- `/add-agent <name> --global` — default; writes to
  `~/.local/share/chezmoi/home/dot_claude/agents/<name>.md`, then
  `chezmoi apply`.
- `/add-agent <name> --local` — writes to
  `<project-root>/.claude/agents/<name>.md`; no chezmoi.
- `/add-agent <name> --focus="<hint>"` — natural-language pointer to the
  relevant part of the conversation.
- `/add-agent <name> --from-file=<path>` — use the file's contents as the
  context source. Overrides `--focus`.
- `/add-agent <name> --tools="<comma-separated>"` — declare an explicit
  tool allowlist in frontmatter (e.g., `--tools="Read,Grep,WebFetch"`).
  If omitted, the agent inherits the parent's toolset.
- `/add-agent <name> --template` — write to `<name>.md.tmpl` instead of
  `<name>.md` so chezmoi can interpolate data (e.g., account-ID tables
  from `.chezmoidata/*.yaml`). Global only — local projects don't run
  chezmoi templates.
- `/add-agent <name> --create-draft[=<path>]` — writes the proposal to
  `<path>` (or `/tmp/claude-drafts/<name>-<timestamp>.md`) and stops.
  User edits externally, then re-invokes with `--from-draft=<path>`.
- `/add-agent <name> --from-draft=<path>` — skip drafting; load the file
  as final content and proceed to deploy confirmation.
- `/add-agent <name> --author="<name>"` — override the author (defaults
  to `git config user.name`).

Mutually exclusive groups:
- `--global` vs. `--local`
- `--from-file` vs. `--focus` (file overrides)
- `--from-draft` vs. `--create-draft`, `--focus`, `--from-file`
- `--template` requires `--global` (chezmoi-only feature).

## Instructions

1. **Require a name.** If `$ARGUMENTS` is empty or yields no name token:
   ```
   /add-agent: missing agent name
   usage: /add-agent <name> [--global|--local] [--focus="<hint>"]
                     [--from-file=<path>] [--tools="<tool1,tool2>"]
                     [--template] [--create-draft[=<path>]]
                     [--from-draft=<path>]
   ```
   Strip a leading `/` if the user included one. Reject names containing
   `/`, `..`, or whitespace. Lowercase-with-hyphens is convention.

2. **Parse flags.** Reject unknown flags rather than folding them into the
   name. Enforce mutual-exclusion rules above. If `--template` is used
   with `--local`, reject — chezmoi templating is global-only.

3. **Determine destination.**
   - Global default: `~/.local/share/chezmoi/home/dot_claude/agents/<name>.md`.
     Live after `chezmoi apply`: `~/.claude/agents/<name>.md`.
   - Global template: `~/.local/share/chezmoi/home/dot_claude/agents/<name>.md.tmpl`.
     Live (rendered): `~/.claude/agents/<name>.md`.
   - Local: `<project-root>/.claude/agents/<name>.md`. Create
     `.claude/agents/` if missing. If the current directory doesn't look
     like a project root (no `.git`, no `CLAUDE.md`, no `.claude/`),
     **ask before creating.**
   - If a file exists at the destination (either `<name>.md` or
     `<name>.md.tmpl`), **halt and suggest `/edit-agent` instead.** Never
     overwrite.

4. **Summarize intent.** *Mandatory — never skip.* State in two or three
   sentences:
   - **What the agent does** — the narrow job it is built for;
   - **When the main agent should spawn it** — the subagent-selection
     trigger, phrased as the `description` field;
   - **Tool access and blast-radius edges** — what tools it needs, what
     destructive actions it must refuse, what outputs it must not
     fabricate. If `--tools` was supplied, cross-check the list against
     the job description: narrow allowlists are safer, but agents with
     broad file/network tools plus narrow instructions are the classic
     blast-radius trap.

   Draw on `--focus` if provided, `--from-file` contents if provided, or
   recent conversation otherwise. Example:

   ```
   Agent: foo-reviewer — reviews staged snowflake_migrations SQL for
   missing USE DATABASE directives and cross-DB references.
   Spawn on: "review this migration", "check my snowflake SQL",
             before the user runs `just snowflake-deploy`.
   Tools:    Read, Grep (no Bash, no WebFetch). Never executes SQL.
   Refuses:  writing or modifying files; only reports findings.
   Confirm or redirect?
   ```

   Ask the user to confirm. If the tool/refusal mix looks unsafe ("broad
   tool access + no refusal path" or "narrow job but Bash + Edit
   unrestricted"), **push back explicitly** — name the concern, don't
   just ask.

5. **Draft the content.** On confirmation, produce the agent file with:
   - YAML frontmatter (see step 5a below for required fields). `tools` is
     included only if `--tools` was supplied — omit the key otherwise.
   - Body in markdown: the system prompt. A good subagent prompt:
     - Opens with "You are a <role>." stating the narrow job.
     - Lists any convention references to load first (skills, reference
       docs, canonical exemplars).
     - Describes the workflow step-by-step.
     - Explicitly enumerates what the agent must refuse (see
       `~/.claude/agents/jira-comment-drafter.md.tmpl` for the pattern).

5a. **Metadata frontmatter — required for every new agent.** Populate:
    - `name` — the filename stem (without `.md` or `.md.tmpl`).
    - `description` — one-line subagent-selection trigger, phrased so the
      parent Agent tool can match it to a spawn request.
    - `author` — `--author` flag value if provided, else
      `git config user.name`.
    - `scope` — `global` or `local`, matching the destination from step 3.
    - `tags` — categorical list (2-5 tags). Include `subagent` for
      discoverability.
    - `tools` — only if `--tools` supplied; pass through verbatim. Omit
      the key otherwise.
    - `timestamps` — a single-entry list on creation:
      `[{action: created, at: <ISO-8601 now>, actor: <author>}]`. Edits
      append; never replace.
    - `comments` — array with at least three bullets covering:
      - **Source** — the conversation, bead, or decision that prompted
        creation.
      - **Motivation** — why this agent earns isolation from the parent
        (context-heavy task, tool-access asymmetry, narrow reusable job).
      - **Projected use** — how the parent invokes it, what it refuses,
        what outputs it returns.

   Model to follow:
   `~/.local/share/chezmoi/home/dot_claude/agents/jira-comment-drafter.md.tmpl`
   (rendered live at `~/.claude/agents/jira-comment-drafter.md`).

   **If the signal is weak, halt and ask.** A vague
   `--focus="the important bit"` is not enough. An unfocused conversation
   is not enough. For agents specifically, **if the intent summary
   couldn't articulate what the agent refuses, that is the red flag** —
   a subagent that refuses nothing is a subagent that can do anything.
   Halt, invite the user to scope it down.

6. **Present for review.**
   - Default: print the full proposed content inline and ask
     `Deploy this agent? (yes / edits / cancel)`.
   - `--create-draft`: write to the chosen path, print it, stop. On the
     user's return, re-invoke with `--from-draft=<path>`.

7. **On confirm.**
   - Write final content to the destination (with `.md.tmpl` extension if
     `--template` was set).
   - `--global`: run `chezmoi apply` via Bash; surface any errors verbatim.
     If a template, confirm the rendered output at
     `~/.claude/agents/<name>.md` looks correct (or halt if the template
     failed to render).
   - Print:
     ```
     Wrote:   <destination source path>
     Live at: <live path>             (global only, after chezmoi apply)
     Commit:  pending in chezmoi repo (global only)
     Role:    <one-line agent role summary>
     ```
   - Remind the user to commit chezmoi when ready. **Never commit.**

8. **On cancel.** Discard the proposal. No writes. If `--create-draft` was
   in play, leave the draft file — the user asked for it.

## Invariants

- Never overwrite an existing agent. `/edit-agent` is the explicit path.
- Never commit. Chezmoi repo hygiene is the user's call.
- Never skip the intent-summary step. For agents, tool access and refusal
  paths are the two fields most worth articulating explicitly.
- Halt rather than draft on vague signal. `--focus="the important bit"`
  is not enough; an agent without an articulable refusal set is not
  enough.
- `--template` implies `--global`. Local projects don't run chezmoi.
- Name must not contain `/`, `..`, or whitespace.
- **Every new agent ships with metadata frontmatter.** `name`,
  `description`, `author`, `scope`, `tags`, `timestamps` (one `created`
  entry), and a `comments` array with source/motivation/projected-use
  bullets. Missing metadata is a halt condition.

## Related

- `/edit-agent <name>` — modify an existing agent.
- `/remove-agent <name>` — delete with echo-to-confirm friction.
- `/add-skill`, `/add-command` — same shape for other config object kinds.
- `/resolve <name>` — locate the live source of an agent, flag shadowing.
- `/audit --agent <name>` *(future)* — behavioral audit of an existing
  agent's tool access, refusal paths, and instruction/tool asymmetries.
