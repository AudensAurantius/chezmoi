---
name: resolve
description: Print the live filesystem source of a Claude config object and flag any shadowing
author: Michael Haynes
scope: global
tags: [meta-tooling, claude-config, introspection, read-only]
timestamps:
  - action: created
    at: 2026-04-20T14:45:00-05:00
    actor: Michael Haynes
comments:
  - "Source: J121-9kp.2.6 meta-tooling wave 2 discussion (2026-04-20). Paired with the CRUD family as an introspection tool — answers 'where does /foo come from?' when precedence or shadowing is unclear."
  - "Motivation: Claude config objects can exist in multiple locations (project-local, global, chezmoi source, MCP plugins). A user debugging unexpected behavior needs to know which copy is winning. Manual filesystem searches are tedious."
  - "Projected use: invoke before /edit-* or /remove-* when it's unclear which file would be touched. Also useful for auditing which tools originate from which source (user's chezmoi vs. project-local vs. MCP plugin) and for investigating why a command behaves unexpectedly."
related: [/add-command, /edit-command, /remove-command, /audit]
---

# /resolve — Print the live source of a Claude config object

Locate the filesystem source of a Claude config object and report all
copies that exist, flagging which one Claude Code loads and which are
shadowed. **Read-only.** Never mutates state.

Arguments: $ARGUMENTS

## Argument shapes

- `/resolve <name>` — minimum. Auto-detects the kind if unambiguous.
  Works for commands, skills, agents. Strip a leading `/` if given.
- `/resolve --kind={skill,command,agent,keybinding} <name>` — force
  the kind when a name collision exists across kinds.
- `/resolve /<name>` — shorthand for command kind (the leading slash
  is stripped; kind defaults to command because the `/` prefix is
  command-specific in Claude Code invocation).
- `/resolve <name> --all-kinds` — report all objects with the given
  name across every kind (useful when you suspect collisions).

## Precedence model

**Caveat: validate empirically.** The current assumption is that
project-local tools shadow global tools with the same name (project
`.claude/commands/foo.md` wins over `~/.claude/commands/foo.md`). If a
future Claude Code update changes this, update this command's output
language accordingly. The empirical test: add a project-local command
with the same name as a global one; invoke it; observe which fires.

## Instructions

1. **Require a name.** If missing:
   ```
   /resolve: missing name
   usage: /resolve <name> [--kind={skill,command,agent,keybinding}]
                  [--all-kinds]
   ```
   Strip leading `/`. Reject `/`, `..`, whitespace.

2. **Parse flags.** Reject unknowns. `--kind` and `--all-kinds` are
   mutually exclusive.

3. **Determine kind candidates.**
   - If `--kind` provided, single kind.
   - If `/` prefix or `--all-kinds=false` and no `--kind`, default to
     command.
   - If `--all-kinds`, check all four kinds.

4. **Search all plausible locations for each kind candidate.** The
   locations to check, in precedence order (top wins):

   | Kind | Project-local | Global | Chezmoi source (upstream) |
   |---|---|---|---|
   | command | `<project-root>/.claude/commands/<name>.md` | `~/.claude/commands/<name>.md` | `~/.local/share/chezmoi/home/dot_claude/commands/<name>.md` |
   | skill | `<project-root>/.claude/skills/<name>/SKILL.md` | `~/.claude/skills/<name>/SKILL.md` | `~/.local/share/chezmoi/home/dot_claude/skills/<name>/SKILL.md` |
   | agent | `<project-root>/.claude/agents/<name>.md` | `~/.claude/agents/<name>.md` | `~/.local/share/chezmoi/home/dot_claude/agents/<name>.md` (or `.md.tmpl`) |
   | keybinding | — | `~/.claude/keybindings.json` (search for binding matching `<name>`) | `~/.local/share/chezmoi/home/dot_claude/keybindings.json` |

   Additionally check for:
   - **MCP plugin skills** (names prefixed with `<plugin>:`) — these are
     served by an MCP server, not a filesystem file. Report the plugin
     name as the source.
   - **Chezmoi symlinks** (`symlink_<name>.md`) — if found, resolve to
     the target and note it as an alias.
   - **Plain symlinks** in any location — resolve the link target and
     note the chain.

5. **Build the output.** For each found location, report:
   - Path (full, absolute).
   - Whether it is the active source or shadowed.
   - Symlink target if applicable.
   - Whether the chezmoi source matches the live global (divergence
     detection — run `chezmoi diff` for global entries).

   Example output for a command with multiple copies:

   ```
   /resolve foo --kind=command

   Kind:    command
   Name:    foo

   Active source: /home/.../J121/.claude/commands/foo.md
                  (project-local — wins over global)

   Shadowed:
     /home/hactar/.claude/commands/foo.md
       (global; active when not in a project with a local override)
       ↳ chezmoi source: /home/hactar/.local/share/chezmoi/home/dot_claude/commands/foo.md
       ↳ chezmoi diff:   clean

   Alias of: (none)
   Aliased by: /chk  →  foo.md  (global symlink)

   Precedence caveat: project-local-wins is the current assumption;
   verify empirically if behavior surprises.
   ```

   Example for a command with one copy:

   ```
   /resolve start

   Kind:    command
   Name:    start

   Active source: /home/hactar/.claude/commands/start.md  (global)
     ↳ chezmoi source: /home/hactar/.local/share/chezmoi/home/dot_claude/commands/start.md
     ↳ chezmoi diff:   clean

   Shadowed: (none)
   Alias of: (none)
   Aliased by: (none)
   ```

6. **On not-found.** If no file exists for any checked location + kind
   combination, print:
   ```
   /resolve: no <kind> named "<name>" found
   Checked:
     <list of paths checked>
   ```
   Suggest `/add-<kind> <name>` to create it.

## Invariants

- **Read-only.** Never modifies any file. Never runs `chezmoi apply`.
  May run `chezmoi diff` (read-only).
- **Always report all copies, not just the winner.** Shadowing is the
  whole point of the command; suppressing shadowed copies defeats the
  purpose.
- **Flag chezmoi divergence explicitly.** If the live global file
  differs from the chezmoi source, say so — this is usually a bug.
- **Flag MCP plugin sources distinctly.** They're not filesystem
  files; treat them as a separate source type in the output.
- **Do not assert precedence as fact.** State the assumption and
  invite empirical validation when surprising behavior occurs.

## Related

- `/add-command`, `/add-skill`, `/add-agent` — create new tools.
- `/edit-command`, `/edit-skill`, `/edit-agent` — modify existing tools;
  /resolve is the natural lookup before invoking these.
- `/remove-command`, `/remove-skill`, `/remove-agent` — destructive;
  /resolve confirms which copy would be removed.
- `/add-command-alias` — create command aliases; /resolve reports
  aliases in the `Aliased by:` section.
- `/audit` *(future)* — deeper behavioral analysis of a specific tool.
