# auto-session templates

Opt-in preference bundles loaded during `/auto-session` elicitation, plus scaffolds written into each session at creation time. Layout:

```
templates/
  exit-summary.md            ← scaffold for <session-dir>/exit-summary.md (written at shutdown)
  session-claude-md.md       ← scaffold for <session-dir>/CLAUDE.md (written at scaffold time)
  run.sh.tmpl                ← scaffold for <session-dir>/run.sh (rendered at scaffold time)
  repos/                     ← per-repo preferences (frontmatter-matched to target repos)
  conventions/               ← opt-in convention documents (embedded into prompt.md)
  permissions/               ← opt-in allowlist bundles (merged into parent-project settings.local.json)
  alerts/                    ← notification-category policies (one default; future: named variants)
  beads/                     ← bead mutation-policy files (one default; future: scope-specific variants)
```

Singulars at the top level (`exit-summary.md`, `session-claude-md.md`, `run.sh.tmpl`) have no sub-variants today. Everything else has a subdir because multiple templates of the same kind are expected.

## `repos/` — per-repo preferences

Each file here declares preferences for a specific target repo (e.g., chezmoi). The skill auto-matches target repos from scope elicitation against each repo template's `applies_to` frontmatter block; matches are embedded into the session `prompt.md`.

### Frontmatter schema

```yaml
---
name: <template-name>
applies_to:
  repo_paths:              # absolute paths; tilde-expanded at match time
    - ~/.local/share/chezmoi
  repo_name_patterns:      # glob patterns against the repo directory name
    - "*chezmoi*"
sandbox:                   # optional; any/all fields may be pinned — user cannot downgrade pinned fields
  location: clone          # optional; one of: in-place, clone
  branch: feature          # optional; one of: current, feature
  # read_only: false       # optional; if true, the other sandbox fields are ignored
---
```

Sandbox dimensions (orthogonal):

- `location`: `in-place` (default; operate on the canonical repo) or `clone` (clone to `<session-dir>/clones/<repo>/` first)
- `branch`: `current` (default; commit to the checked-out branch) or `feature` (create `feature/auto-<slug>-<date>` and commit there)
- `read_only`: pre-empt flag; if true, the repo is consulted but not modified and the other sandbox fields are ignored

Each dimension is independently pinnable. Unpinned dimensions are elicited from the user at session setup.

### Body

Prose directives the coordinator reads at launch:
- Render-only commands (safe to run)
- Forbidden commands
- Branch naming conventions
- Push policy
- Known pitfalls specific to this repo

Keep it concrete and actionable. The coordinator is not a human — it will follow what's written literally.

### Example

See `repos/chezmoi.md` for the canonical shape.

## `conventions/` — reusable convention documents

Each file here codifies a convention the session should follow or the review agent should check against. Not tied to a specific repo. Opt-in during scope elicitation — the skill lists all `conventions/*.md` files with their descriptions and asks which to include.

Selected templates are:
1. Embedded verbatim into `prompt.md` under a "## Conventions" section (so the coordinator reads them)
2. Listed by path in the review agent's brief (so the reviewer reads them too)

### Frontmatter schema

```yaml
---
name: <template-name>
description: <one-line description shown during elicitation>
checkable_by_review: true | false       # hint: can session-reviewer statically verify this?
---
```

### Body

Whatever rules you want the coordinator and reviewer to follow. Phrase rules as checkable statements where possible (e.g., "every new skill file must have a `timestamps` array in frontmatter") rather than aspirations (e.g., "strive for consistency").

If `checkable_by_review: true`, the review agent will enumerate each rule and report complies / violates / n/a per rule. If `false`, the rule is informative for the coordinator but not automatically checked.

## `permissions/` — opt-in allowlist bundles

Each YAML file declares a named allowlist bundle. The canonical file is `default.yaml`. Structure:

- `autosession_scripts.allowed[*]` — the skill's own scripts the coordinator may invoke. Under the session-scoped-hooks architecture this is empty by default: every script in `scripts/lib/` is hook-only.
- `autosession_scripts.disallowed[*]` — scripts the skill refuses to merge, with `reason` fields explaining why. Acts as both policy (the merge logic drops them) and documentation (the reader understands the hook-only / TTY-only / detached-spawn surfaces).
- `command_permissions.<group>[*]` — opt-in groups of Bash/MCP patterns. All commented out by default. User uncomments the groups they want; each entry has `pattern` (merged) and `purpose` (discarded, human-readable).

### Merge target

The skill merges selected entries into the **parent project's** `<project-root>/.claude/settings.local.json` under `permissions.allow`, never into the committed `settings.json`. The session dir's *own* `.claude/settings.local.json` is separate — that one carries the hook registrations and is scaffolded by `scripts/scaffold-autosession.sh`, not by this template. Merge is idempotent (no duplicates) and preserves all other keys.

### Authoring policy reminders

Keep these in any custom template — they prevent accidental catastrophic grants:
- Read-only commands only; mutating commands stay interactive.
- No interpreter wildcards (`python:*`, `node:*`, `bun:*`, `bash:*`, `npx:*`, `uvx:*`).
- No `gh api *` — use specific subcommands.
- No `Bash(*:*)` or bare `Bash(*)` ever.

See `permissions/default.yaml` for the canonical shape, including the group-commenting convention.

## `alerts/` — notification-category policies

Each YAML file here maps notification categories to behavior (sound, urgency, nag cadence, persistence). Canonical file: `alerts/default.yaml`. The active alerts template is embedded by slug into `prompt.md` so the coordinator knows when to fire each category.

Category taxonomy:
- **io_block** — coordinator is waiting on user I/O (permission prompt, clarification). Soft sound, nag every 60s up to 30 iterations.
- **decision_block** — coordinator has hit a design decision it will not make autonomously. Alarm sound, urgent, persistent until acknowledged.
- **compaction** — context compaction is about to occur. Reminder sound, one-shot.
- **session_end** — session has reached its planned end. Reminder sound, one-shot.

The hook dispatcher (`scripts/lib/notify-dispatcher.sh`) reads category from the Notification payload's `message` prefix or a `[category]` tag; if absent it defaults to io_block. Custom categories can be added by editing `alerts/default.yaml` or authoring a named variant.

## `beads/` — bead mutation-policy files

Each YAML file here declares what the coordinator may and may not do to beads on behalf of the user. Canonical file: `beads/default.yaml`. The active beads template is embedded by slug into `prompt.md` and referenced by the review agent.

Policy covers:
- `lifecycle.claim` — whether the coordinator may claim beads
- `lifecycle.status_transitions` — per-event (on_claim/on_finish/on_defer/on_block) status and label changes; `allowed_transitions` whitelist; `transition_note_required` forcing a `bd note` per transition
- `lifecycle.labels` — `allowed_prefixes` (autosession-specific) and `forbidden` (classification labels the coordinator must not touch)
- `lifecycle.metadata` — keys the coordinator sets on claim (`agent=claude`, `autosession_slug=<slug>`)
- `lifecycle.notes` — `transition_prefix` template and `required_on_status_change` flag
- `lifecycle.comments` — whether the coordinator may add comments (default: false; notes are queryable, comments aren't)
- `lifecycle.description` / `lifecycle.graph` — whether description may be appended and graph (parents/deps) may be mutated
- `lifecycle.create` — whether the coordinator may create new beads; if enabled, required labels (e.g., `src:autosession-<slug>`)
- `lifecycle.memory` — whether the coordinator may run `bd remember`; if enabled, the prescribed format string and `review_on_import` flag

See `beads/default.yaml` for the canonical shape with inline explanations per field.

## `exit-summary.md` — shutdown scaffold (top-level)

The coordinator copies this template to `<session-dir>/exit-summary.md` at shutdown (Step 9) and fills it in. It is the canonical "what happened in this session" artifact and is the input to the future `/import-session` command.

Key structural notes:
- Lives inside the session dir (not `memory/`). `/import-session` promotes relevant parts into the parent project's conventions.
- References other session artifacts (`decisions.md`, `execution-log.md`, `events.jsonl`, `agents/*/result.md`) rather than duplicating their contents.
- Has a dedicated "Import hints for `/import-session`" section the coordinator fills in with concrete suggestions (checkpoint filename, bd remember candidates, auto-memory candidates).

Do not edit the template in-place per session — copy, then fill the copy. The template stays generic.

## `session-claude-md.md` — per-session CLAUDE.md scaffold (top-level)

Copied verbatim into `<session-dir>/CLAUDE.md` by `scripts/scaffold-autosession.sh`. Contains the compaction-resilience rehydrate rule, anti-loop clause, single-writer invariants (timew + bd mutation policy), and a pointer to the session's `prompt.md`. Because Claude Code auto-loads the cwd's `CLAUDE.md` at every session start (including post-compact), this is the durable carrier for rules that must survive compaction.

Do not use session-specific values (slug, dir) in the scaffold itself — `scaffold-autosession.sh` does a string-substitution pass to inject those at copy time.

## `run.sh.tmpl` — launcher template (top-level)

Rendered to `<session-dir>/run.sh` by `scripts/scaffold-autosession.sh`. The launcher:

- Verifies `$SESSION_DIR_ACTUAL == $SESSION_DIR_EXPECTED` (cwd invariant — refuses to run from a different directory, because hook paths and env vars are all relative to the session dir)
- Verifies `prompt.md` and `.claude/settings.local.json` exist
- Exports `AUTOSESSION_SLUG` and `AUTOSESSION_DIR`
- `exec claude "$@"` — replaces shell so hooks see the exported env

Template substitution markers: `{{SLUG}}`, `{{SESSION_DIR}}`, `{{SKILL_DIR}}`.

## Authoring new templates

1. Copy an existing template as a starting point
2. Edit the frontmatter or top-level YAML keys as appropriate for the template kind
3. Write the body / policy in concrete prose (or concrete allowlist patterns, for permissions)
4. Drop it into the right subdir (`repos/`, `conventions/`, `permissions/`, `alerts/`, `beads/`); the skill picks it up on next invocation

No registration step. The skill reads the directory fresh every time it runs.

**Exception**: the top-level singulars (`exit-summary.md`, `session-claude-md.md`, `run.sh.tmpl`) are not template families. Edit them directly if their shape needs to change.

## Removing templates

Delete the file. Active sessions that already embedded it are unaffected (templates are embedded at launch, not referenced dynamically).
