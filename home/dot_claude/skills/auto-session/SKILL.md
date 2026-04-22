---
name: auto-session
description: Scaffold and launch a semi-autonomous multi-bead implementation session. TRIGGER on `/auto-session`, "start an autonomous session on <epic>", "kick off autonomous work on <bead-group>", or "resume the paused session". The skill elicits scope, per-target-repo sandbox (location × branch, each pinnable by repo template), model tiers, landmark cadence, alerts policy, and bead mutation policy; scaffolds a session dir with a session-scoped `.claude/settings.local.json`, a compaction-resilient `CLAUDE.md`, a launcher `run.sh`, a human execution log, JSONL event stream, categorized scratchpad, and decision log; gates on explicit user approval before the user launches the coordinator. Loads opt-in per-repo templates (e.g., chezmoi), convention templates, alerts templates, and beads templates. Does NOT fire on single-bead work (`/start` + `/stop` covers that) or execution of a fixed phased plan (use `claude-mem:do`).
author: Michael Haynes
scope: global
tags: [autonomous, session, multi-bead, coordinator, review, decision-log, high-blast-radius]
timestamps:
  - action: created
    at: 2026-04-21T17:57:47-05:00
    actor: Michael Haynes
  - action: revised
    at: 2026-04-22T00:35:00-05:00
    actor: Michael Haynes
    note: "Session-scoped hooks replace global marker-file gating; CLAUDE.md + SessionStart:compact hook added for compaction resilience; templates/alerts/ and templates/beads/ introduced; install.sh reduced to agent-only symlink; scaffold-autosession.sh added."
comments:
  - "Source: design conversation 2026-04-21 on setting up a secondary autonomous session alongside a primary interactive session for the tooling-and-claude-related bead epics (Waves 1-3). Iterative design dialogue covered sandbox isolation, event logging, decision protocols, subagent patterns, notification ergonomics, bd metadata/label/notes taxonomy, and compaction resilience."
  - "Motivation: prevents the main failure modes of autonomous sessions — silent clobbering of the canonical chezmoi main branch, decision drift without audit trail, subagent context starvation, timew interval orphaning, missed notifications when the user steps away, bead-label proliferation, and compaction-induced policy paraphrasing. Encodes the structural decisions so every autonomous session starts from the same tested baseline."
  - "Projected use: fires when the user kicks off or resumes a multi-bead autonomous working session. Should NOT fire on single-bead work, on execution of a pre-existing phased plan (claude-mem:do handles that), or on interactive one-off implementation. Bundled with the session-reviewer agent (symlinked into ~/.claude/agents/ via install.sh, or per-session via scaffold-autosession.sh)."
---

# Auto Session

Scaffold and launch a semi-autonomous multi-bead implementation session. Everything structural — working dir layout, sandbox discipline, logging, decision protocol, subagent patterns, notifications, bead mutation policy, compaction resilience — is codified here so each session starts from the same tested baseline.

The skill is **repo-agnostic at its core**. Repo-specific conventions (chezmoi sandbox rules, push policies, render-command allowlists) live in opt-in templates under `templates/repos/`, loaded per session.

## When to fire

- `/auto-session` slash-invocation
- "Start an autonomous session on `<scope>`"
- "Kick off autonomous work on `<epic>` / `<bead-group>`"
- "Resume the paused session" / "/auto-session --resume"

## When NOT to fire

- Single-bead work — `/start <id>` + `/stop` is the right tool
- Execution of a pre-planned phased roadmap — use `claude-mem:do`
- Interactive one-off implementation — just do the work directly

## Architectural pillars

Four design decisions shape everything else; read them first.

1. **Session-scoped hooks.** Each session writes its own `<session-dir>/.claude/settings.local.json` with the Notification / PreToolUse / SessionStart:compact hooks. Claude Code only loads that file when launched with cwd == session dir, so interactive sessions are unaffected. No global marker file, no dispatcher-side gating — the hook's *presence in the session's config* is the signal.
2. **Compaction-resilient CLAUDE.md.** Each session's `CLAUDE.md` carries the rehydrate rule, anti-loop clause, and single-writer invariants. Because Claude Code auto-loads the cwd's `CLAUDE.md` at every session start (including post-compact), these rules survive when `prompt.md` is paraphrased away. A SessionStart:compact hook belts-and-suspenders it by emitting a rehydrate instruction into the coordinator's context.
3. **Bd metadata + structured notes, not label proliferation.** The coordinator sets cardinality-1 metadata (`agent=claude`, `autosession_slug=<slug>`) on claim, and writes prefixed `bd note` entries on every status transition. Transient state uses a tiny label set (`autosession-deferred`, `autosession-blocked`), each removed on the next claim. No accumulating `src:autosession-<slug>` history labels — the notes trail is the audit history.
4. **Launcher-enforced cwd invariant.** `run.sh` refuses to launch unless its own location matches the expected session dir. This prevents the silent-misbehavior class of failure where hooks, CLAUDE.md, and bead paths all resolve against the wrong project because the user typed `claude` from the parent directory.

## First-run install (global — one-time)

Autonomous sessions are self-contained: each session dir carries its own hooks, CLAUDE.md, and settings file. The only *global* step is symlinking the `session-reviewer` subagent so it resolves from `Task(subagent_type=session-reviewer)` in any Claude Code session.

```sh
~/.claude/skills/auto-session/install.sh
```

`install.sh` is **TTY-only** — it refuses to run from a non-interactive shell. Modes: `install` (default), `uninstall`, `status`. Idempotent; re-running detects existing wiring and either confirms or surfaces drift.

If the user is chezmoi-managed and declares the symlink in `home/dot_claude/agents/symlink_session-reviewer.md`, `chezmoi apply` handles it and `install.sh` detects the pre-existing symlink as already-installed.

The scaffold script also symlinks the agent into each session's local `.claude/agents/`, so `install.sh` is not strictly required — it just makes `session-reviewer` usable outside auto-sessions.

## Session lifecycle

```
┌────────────────────┐
│ 1. Scope elicit    │  goals, beads/epics, target repos, model tiers, landmarks
├────────────────────┤
│ 2. Sandbox elicit  │  per-repo (location, branch) + read_only pre-empt
├────────────────────┤
│ 3. Template load   │  repos/, conventions/, permissions/, alerts/, beads/
├────────────────────┤
│ 4. Scaffold        │  scaffold-autosession.sh materializes dir tree, CLAUDE.md,
│                    │  run.sh, .claude/settings.local.json, state/
├────────────────────┤
│ 5. Approval gate   │  present prompt.md + scaffold tree + resolved sandbox/policy;
│                    │  require explicit "go"
├────────────────────┤
│ 6. Launch          │  instruct user to run `cd <session-dir> && ./run.sh`
├────────────────────┤
│ 7. Execution loop  │  coordinator works through beads; hooks fire; compaction-safe
├────────────────────┤
│ 8. Landmarks       │  every N closures: gap-review subagent; session-reviewer on branches
├────────────────────┤
│ 9. Shutdown        │  close timew, push pre-authorized repos, write exit-summary
└────────────────────┘
```

### Step 1 — Scope elicitation

Interactive prompts (one at a time; don't front-load):

1. **Session slug** — short kebab-case descriptor (e.g., `tooling-wave-1-3`). Must match `[A-Za-z0-9_-]+`.
2. **Goal summary** — one paragraph describing what the session is trying to accomplish.
3. **Bead scope** — beads to include. Accept:
   - Explicit list: `J121-9kp J121-xxx J121-yyy`
   - Epic prefix: `J121-9kp.*` (skill expands via `bd list`)
   - Label filter: `bd list --label=area:tooling --status=open --json` (skill shows count, asks to confirm)
   - Native `bd query` expression for complex AND/OR/NOT filters.
4. **Target repos** — paths that may be modified during the session. Each gets a sandbox in step 2.
5. **Model tier policy** — default tiers; user can override:
   - `haiku` for review/gap-analysis/logging subagents
   - `sonnet` for implementation (default)
   - `opus` for architecture decisions the coordinator escalates
6. **Landmark cadence** — number of bead closures between gap-review subagent invocations (default: 5).
7. **Max session duration** — wall-clock cap (default: 6 hours); coordinator halts for user confirmation past this.

### Step 2 — Sandbox elicitation

For each target repo from step 1.4, ask two orthogonal questions (or accept `read_only: true` which skips both):

**Q1: Location** — where does the working copy live?
- `in-place` (default) — operate on the repo in its canonical filesystem location
- `clone` — clone to `<session-dir>/clones/<repo-name>/`; canonical stays untouched; push feature branches to canonical at shutdown

**Q2: Branch** — which branch do commits land on?
- `current` (default) — commit to the repo's currently checked-out branch
- `feature` — create `feature/auto-<slug>-<YYYYMMDD>` from HEAD; commit there; never merge during session

All four `(location, branch)` combinations are valid:

| Location | Branch | Typical use |
|---|---|---|
| `in-place` | `current` | `.beads/`, `tasks/` — repos where main absorbs session commits |
| `in-place` | `feature` | Changes need review before landing, but in-place visibility is wanted |
| `clone` | `feature` | Main must stay usable by concurrent sessions (chezmoi) |
| `clone` | `current` | Rare — sandbox testing against main without affecting canonical users |

If a per-repo template under `templates/repos/` matches (by `repo_paths` or `repo_name_patterns`), it may pin one or both dimensions. The skill surfaces this as *"template X pins `location=clone`, `branch=feature`; accept?"*. Pinned dimensions override user answers for safety; the user may decline the repo entirely but cannot downgrade a pin.

### Step 3 — Template loading

Five template categories:

- **Repo templates** (`templates/repos/*.md`) — auto-loaded when a target repo matches `applies_to` in the template frontmatter.
- **Convention templates** (`templates/conventions/*.md`) — opt-in; skill lists them with descriptions and asks which to include.
- **Permissions templates** (`templates/permissions/*.yaml`) — opt-in; skill loads `default.yaml` (or user-specified), shows the commented groups, asks which to uncomment, then merges selected entries into the **parent project's** `.claude/settings.local.json`.
- **Alerts templates** (`templates/alerts/*.yaml`) — selects the notification-category policy (sounds, urgency, nag cadence). `default.yaml` is used unless the user picks a variant. Embedded into `prompt.md` so the coordinator knows when to fire each category.
- **Beads templates** (`templates/beads/*.yaml`) — declares the `lifecycle` policy the coordinator follows for every bead it touches: status transitions, metadata set on claim, required transition notes, allowed/forbidden labels, whether `bd create` and `bd remember` are permitted. `default.yaml` is used unless the user picks a variant. Embedded into `prompt.md` and surfaced to the review agent.

Repo, convention, alerts, and beads templates are embedded verbatim into `prompt.md`. Permissions templates are parsed and merged into `.claude/settings.local.json`, not embedded. The skill does not interpret the body text of repo/convention templates — it just loads and embeds.

### Step 4 — Scaffold

The skill invokes `scripts/scaffold-autosession.sh --session-dir <path> --slug <slug>`, which materializes:

```
<project-root>/tasks/sessions/<slug>-<YYYYMMDD>/
  prompt.md                        ← verbatim session prompt (audit artifact; coordinator reads this)
  CLAUDE.md                        ← compaction-resilient rules (rendered from templates/session-claude-md.md)
  run.sh                           ← launcher (rendered from templates/run.sh.tmpl; chmod +x)
  state.json                       ← resumable checkpoint
  execution-log.md                 ← human-readable narrative (coordinator appends)
  events.jsonl                     ← machine-readable event stream (all agents append; POSIX-atomic)
  decisions.md                     ← decision log with reversion plans
  exit-summary.md                  ← (written at shutdown from templates/exit-summary.md)
  hook.log                         ← JSONL two-record hook audit (written by scripts/lib/hook-wrapper.sh)
  hook.log.lock                    ← flock target for serialized writes
  .claude/
    settings.local.json            ← session-scoped hooks (Notification, PreToolUse, SessionStart:compact)
    agents/
      session-reviewer.md          ← symlink into the skill's agents/ dir
  state/
    README.md
    nag-<session-id>.pid           ← (transient; created by hook dispatcher while io-block is active)
  clones/                          ← clone-sandbox repos land here (one subdir per repo)
  agents/                          ← per-subagent working dirs (brief.md, result.md, log.md each)
  execution-log/                   ← per-turn narrative snippets, if the coordinator splits the log
  scratchpad/
    assertions/                    ← facts the coordinator has verified
    conventions/                   ← loaded convention templates + derived rules
    findings/                      ← per-bead discoveries
    goals/                         ← session goals + per-bead sub-goals
    hypotheses/                    ← unverified ideas the coordinator is testing
```

After the scaffold returns, the skill writes `prompt.md` and any permissions merges. `prompt.md` is generated from the elicited scope, sandbox table, loaded templates (repos, conventions, alerts, beads), permissions granted, and the decision/logging/shutdown protocols. The scaffold script is idempotent but refuses to overwrite a non-empty dir without `--force`.

### Step 5 — Approval gate

Skill displays:
- Full `prompt.md` contents
- Scaffold tree (abbreviated; depth 3)
- Sandbox table (repo → location → branch → rationale; pinned dimensions marked)
- Resolved model tiers
- Landmark cadence
- Bead mutation policy summary (from the active `templates/beads/*.yaml`)
- Alerts policy summary (from the active `templates/alerts/*.yaml`)
- Permissions granted

Prompts: `Launch session? (yes / edit prompt / cancel)`. "edit prompt" opens `prompt.md` for user review; the gate re-runs after.

### Step 6 — Launch

On explicit "yes" the skill emits a single instruction:

> Open a fresh terminal and run:
>
> ```sh
> cd <session-dir>
> ./run.sh
> ```

**The skill does not spawn the coordinator itself.** The coordinator runs in a fresh Claude Code session the user starts manually. This keeps session context clean and gives the user a clear resume-or-abandon choice.

`run.sh` performs three guards before `exec claude`:
1. Self-location check (`$SESSION_DIR_ACTUAL == $SESSION_DIR_EXPECTED`) — refuses if the session dir has moved.
2. `prompt.md` exists — refuses if the scaffold is corrupt.
3. `.claude/settings.local.json` exists — refuses, because without it hooks do not fire.

It then exports `AUTOSESSION_SLUG` and `AUTOSESSION_DIR` (so hook scripts can attribute log records without parsing cwd), and `exec`s `claude`.

### Step 7 — Execution loop (coordinator's responsibility)

```
while beads remain and not paused and not over time cap:
    bead = bd ready --top 1
    /start <bead>                              # claim + start timew
    # Claim bookkeeping, per templates/beads/*.yaml lifecycle.on_claim:
    bd update <bead> --set-metadata agent=claude \
                     --set-metadata autosession_slug=<slug> \
                     --remove-label autosession-deferred \
                     --remove-label autosession-blocked
    bd note <bead> "[autosession/<slug> <ISO>] open -> in_progress; claimed via /auto-session"

    implement(bead)                            # possibly via subagents
    verify(bead)                               # tests, dry-run renders, etc.
    commit(bead)                               # per-repo per-sandbox-level commit discipline
    log_event("bead_closed", bead)             # append JSONL + execution-log

    # Finish bookkeeping, per lifecycle.on_finish (custom status 'review', not 'closed'):
    bd update <bead> --status review
    bd note <bead> "[autosession/<slug> <ISO>] in_progress -> review; impl complete, awaits user verification"

    /stop                                      # release timew
    push pre-authorized repos                  # .beads, tasks — per project policy
    if closures_since_review >= landmark_cadence:
        gap_review_subagent()                  # Haiku; output to scratchpad/findings/
        closures_since_review = 0
    save_state()                               # overwrite state.json
```

Defer / block go through lifecycle.on_defer and lifecycle.on_block respectively (see active beads template). Every status transition pairs with a `bd note` using the prefix `[autosession/<slug> <ISO>]`.

### Step 8 — Landmark reviews

Every `landmark_cadence` bead closures, the coordinator spawns a **gap-review subagent** (Haiku, foreground):
- Brief includes: recent commits, closed beads, current scratchpad contents.
- Output written to `agents/gap-review-<timestamp>/result.md`.
- Coordinator reads the summary and logs an event; full result stays in the file.

After any commit on a `feature` or `clone` repo, the coordinator may invoke the **session-reviewer agent** (`subagent_type: "session-reviewer"`) for pattern-compliance review. Output goes to `agents/session-reviewer-<timestamp>/result.md`.

### Step 9 — Shutdown

Triggered by: all beads closed, time cap reached, pause signal, or user interrupt. Coordinator responsibilities:

1. Stop any open timew interval (`bd-timew stop` if active).
2. For each `in-place + current` repo: commit + push if pre-authorized.
3. For each `feature`-branch repo (any location): push the feature branch (never merge).
4. For each `clone` repo: push feature branch to canonical; leave the clone in place for user review.
5. Update `state.json` with final state.
6. Append final execution-log entry.
7. Emit shutdown JSONL event.
8. Write `<session-dir>/exit-summary.md` from `templates/exit-summary.md` (do not skip — this is the input artifact for `/import-session`).

No session-marker file to remove — hooks are session-scoped and the session's `.claude/settings.local.json` becomes inert the moment the coordinator exits.

## Context compaction resilience

Context compaction paraphrases the conversation, including `prompt.md` if it was pasted in. Rules embedded only in `prompt.md` can be silently paraphrased into vague guidance. Three mitigations work together:

1. **`<session-dir>/CLAUDE.md`** (scaffolded from `templates/session-claude-md.md`). Claude Code auto-loads the cwd's CLAUDE.md at every session start and post-compact, so rules that live here survive. The scaffold puts the rehydrate rule, anti-loop clause, working-dir invariant, single-writer invariants, and bead-mutation summary here.

2. **SessionStart:compact hook** (`scripts/lib/post-compact-rehydrate.sh`). Fires immediately after compaction; emits an `additionalContext` payload telling the coordinator to re-read `prompt.md` and CLAUDE.md before its next substantive action. Because this instruction is injected *after* compaction, it cannot be paraphrased by the compaction that just ran.

3. **Size discipline on `prompt.md`.** Keep under ~20KB. Reference repo/convention templates by path rather than embedding them verbatim when a size threshold is exceeded. Re-reads are cheap only if the brief is small.

**Anti-loop clause** (in `templates/session-claude-md.md`): if uncertainty about the brief persists after re-reading once, halt and fire a `decision_block` notification rather than re-reading a second time or guessing. Re-reading more than once in a compaction cycle is a sign the brief is unclear, not that the coordinator needs to try harder.

## Bead mutation policy

The active `templates/beads/<name>.yaml` is the authoritative policy; summary follows.

- **Metadata (cardinality-1, last-write-wins)** — set `agent=claude` and `autosession_slug=<slug>` on every claim. Queryable via `bd list --metadata-field` and `bd list --has-metadata-key`. Use for one-shot classification the coordinator owns.
- **Labels (cardinality-N, user-owned taxonomy)** — the coordinator only adds transient markers: `autosession-deferred`, `autosession-blocked`. Each is removed on the next claim. Forbidden: anything under `src:`, `scope:`, or `area:` (those are classification labels owned by the user's taxonomy).
- **Notes (append-only audit trail)** — every status transition writes `bd note` with the prefix `[autosession/<slug> <ISO-8601>] <from> -> <to>; <rationale>`. Queryable via `bd list --notes-contains`. This is the history; there is no accumulating-label workaround.
- **Comments** — disabled by default. Notes are filterable, comments aren't, so notes are the right tool for everything we care about.
- **Description / graph** — disabled. The coordinator never appends to description and never sets parents/dependencies.
- **`bd create`** — disabled by default. When enabled, any created bead must carry `src:autosession-<slug>` (this is the one case where an accumulating-history label *is* warranted — to flag the provenance of machine-created beads to future humans).
- **`bd remember`** — enabled; prescribed format `autosession[<slug>]: <fact> (see <session-dir>/exit-summary.md#discoveries)`. Memories have `review_on_import: true` — `/import-session` surfaces them for human confirmation before they graduate to un-scoped memories.
- **Custom statuses respected** — `on_finish` maps to `review`, not `closed`, because the user's bd config sets `status.custom review,testing`.

Full policy (including the `allowed_transitions` whitelist and the exact field shapes) is in `templates/beads/default.yaml`.

### Why YAML, not `bd formula` + `bd mol`

The 2026-04-22 tooling survey flagged a cross-cutting finding that most bd-adjacent tools use `bd` as storage-only and ignore the declarative workflow layer (`bd formula`, `bd mol`, `bd cook`, `bd swarm`). A pre-ship probe (J121-7bv.1) tested whether `templates/beads/default.yaml` should be expressed as a bd formula instead. Verdict: **no**.

- `bd formula` describes an **issue-DAG spawn template** — variables, steps, labels on spawned children, parent/child edges, composition via `extends`/`compose`. Cooked via `bd cook` into a proto; instantiated via `bd mol pour` into real beads.
- `templates/beads/default.yaml` describes **runtime coordinator behavior constraints** — `allowed_transitions` whitelist, `transition_prefix` on notes, `can_add`/`can_remove` per label namespace, metadata rewrite timing, `bd remember` format, comments disabled.
- Overlap is ~20% (the `create` subset — labels and parent required on spawned beads). The other ~80% has no CLI-level bd enforcement; a formula cannot constrain what the coordinator does to an *existing* bead it did not spawn.

Converting the 20% would split the policy across two files and two mental models without retiring the YAML side. Ship YAML; the coordinator reads it at session start and self-enforces. Revisit if bd grows runtime-policy primitives (e.g., a `bd gate` shape that blocks status transitions outside an allowed set).

## Notifications

Two categories, driven by session-scoped hooks + direct invocation. The active `templates/alerts/<name>.yaml` declares sounds and nag cadences; dispatcher (`scripts/lib/notify-dispatcher.sh`) consults it via the message-prefix convention.

### Category: io_block

Fired automatically by the session's `Notification` hook when Claude Code needs user input (tool approval, idle prompt). Because hooks are session-scoped (the hook lives in `<session-dir>/.claude/settings.local.json`), the dispatcher fires unconditionally — no marker-gating.

Characteristics:
- Soft sound (`IM` via BurntToast v1.1.0 `-Sound`; falls back to `Reminder` if the shim's ValidSet is narrower)
- Non-urgent; ephemeral on-screen; migrates to Action Center
- **Re-nag on 60s cadence** while blocked, via `scripts/lib/nag-repeater.sh` (detached)
- Hard cap: 30 re-nag iterations (30 minutes)
- Nag killed by `PreToolUse` hook's `scripts/lib/preuse-cancel-nag.sh` (= user responded; a tool call is about to proceed)

### Category: decision_block

Fired directly by the coordinator when it writes a decision-log entry with `blocking: true`:

```sh
wsl-notify-send --urgent --sound=Alarm "Claude Code [$AUTOSESSION_SLUG]: Decision needed: <short title>"
```

Characteristics:
- Urgent BurntToast (`-Urgent`) → persistent on-screen until dismissed
- Alarm sound
- Single fire, no re-nag (persistence makes re-nag redundant)

Coordinator halts after firing and writes the pending decision ID to `state.json`. Resumes only when the user has written `Resolution:` into the decision-log entry.

### Session scoping

Hooks live in `<session-dir>/.claude/settings.local.json` and only load when Claude Code's cwd is the session dir. Interactive sessions never see these hooks. Concurrent auto-sessions each have their own settings file — no cross-contamination, no shared state dir.

Hook invocations are wrapped via `scripts/lib/hook-wrapper.sh`, which writes paired `hook_started` / `hook_ended` records to `<session-dir>/hook.log` under `flock`, with a watchdog timeout (default 30s, `AUTOSESSION_HOOK_TIMEOUT` overrides). The real hook's stdout passes through untouched (preserving Claude Code's hook-response protocol); stderr is captured into the log, bounded at 1KB per record.

## Sandbox mechanics

Two orthogonal dimensions + a pre-empt. Each repo's resolved sandbox is a `(location, branch)` tuple, or `read_only: true` which skips the dimensions.

### Pre-empt: `read_only`

Coordinator may read files via `Read`, `Grep`, `Glob`, `git log`, etc. All writes refused. If the coordinator wants to modify a read-only repo, it must halt, log as a blocking decision, and wait for user re-scope or explicit authorization.

### Location dimension

**`in-place`** — operate on the repo in its canonical filesystem location. Concurrent sessions or interactive shells may touch the same repo; coordinator verifies the working tree is clean before claiming a bead and refuses to proceed on unexpected state.

**`clone`** — first action: `git clone <canonical-path> <session-dir>/clones/<repo-name>`. Coordinator operates entirely within the clone; canonical stays on its checked-out branch. At shutdown: push committed branches to canonical. Clone retained after session end for user review.

### Branch dimension

**`current`** — commits land on the repo's currently checked-out branch at session start. Coordinator verifies the branch matches expectations (typically `main`) before proceeding.

**`feature`** — first action after location setup: `git checkout -b feature/auto-<slug>-<YYYYMMDD>` from HEAD. All commits land on this branch. **Never** `git merge`, `git rebase`, or `git push origin main` during the session. At shutdown: `git push origin feature/auto-<slug>-<YYYYMMDD>` lands the branch; never merged to main by the coordinator.

### Pre-authorized push list

Independent of sandbox config: the project's pre-authorized push list determines whether the coordinator may push *without* asking. For J121 this is `.beads/`, `tasks/`, and chezmoi feature branches (but **not** chezmoi main). Repos not on this list require the coordinator to halt at shutdown and ask the user to authorize the push.

## Per-repo templates

Templates under `templates/repos/*.md` carry frontmatter declaring applicability and optional sandbox pins:

```yaml
---
name: chezmoi
applies_to:
  repo_paths:
    - ~/.local/share/chezmoi
  repo_name_patterns:
    - "*chezmoi*"
sandbox:
  location: clone                  # optional; pins location — user cannot downgrade
  branch: feature                  # optional; pins branch — user cannot downgrade
  # read_only: false               # optional; if true, the other fields are ignored
---
```

Matches are embedded verbatim into `prompt.md` under "## Repo conventions: <repo>". Each `sandbox` field is independently optional.

## Convention templates

Templates under `templates/conventions/*.md` are opt-in at elicit time. Selected templates are embedded into `prompt.md` under "## Conventions". They are also consumed by the review agent (which loads them by path).

Use for code-style preferences, commit-message patterns, project-specific patterns the review agent should check compliance against. Frontmatter `checkable_by_review: true` tells session-reviewer to enumerate rules and report complies / violates / n/a per rule.

## Permissions templates

Autonomous sessions benefit from a larger default allowlist than interactive sessions — every Claude Code permission prompt halts the coordinator and fires an io_block nag until the user responds. Pre-authorizing the specific commands the coordinator needs keeps the run flowing without widening the project's committed `settings.json`.

Templates live under `templates/permissions/*.yaml`. The canonical file is `default.yaml`. Structure:

1. **`autosession_scripts`** — the skill's own `scripts/lib/` entries.
   - `allowed`: empty under `default.yaml` (every lib script is hook-only).
   - `disallowed`: scripts the skill refuses to merge, each with a `reason`. Functions as policy AND documentation — a user who writes `Bash(~/.claude/skills/auto-session/scripts/lib/*)` sees why that's the wrong shape.
2. **`command_permissions`** — opt-in groups, all commented out by default. User uncomments the groups the coordinator needs (bd queries, git writes, chezmoi renders, dotnet build, Jira MCP reads, etc.). Each entry has `pattern` (merged) and `purpose` (discarded).

### Merge behavior

At elicit time:
1. Read `templates/permissions/default.yaml` (or user-chosen alternate).
2. Confirm `autosession_scripts.allowed` (empty by default, so often a no-op).
3. Show uncommented `command_permissions` groups; user toggles.
4. Write resolved entries to **parent project's** `<project-root>/.claude/settings.local.json` under `permissions.allow`:
   - Idempotent: duplicates dropped.
   - Surgical: `jq`-based merge preserves all other keys.
   - Local-only: never touches the committed `settings.json` or `~/.claude/settings.json`.
5. Record the merged patterns in `prompt.md` under "## Permissions granted for this session".

### Removing permissions

Removing an entry from the template does *not* retroactively prune live entries from `settings.local.json`. Permissions added during a session remain unless the user edits them out. A future `/uninstall-permissions` command would automate this; v1 does not include it.

### Authoring custom templates

Copy `default.yaml`, rename under `templates/permissions/<name>.yaml`, edit. The skill offers a template picker when more than one is present. Keep the policy reminders (read-only only, no interpreter wildcards, no `gh api *`, no `Bash(*:*)`).

## Alerts templates

Under `templates/alerts/*.yaml`. Declares per-category behavior: sound, urgency, nag cadence, persistence. `default.yaml` covers `io_block` (IM sound, 60s × 30 nag), `decision_block` (Alarm, urgent, persistent), `compaction` (Reminder, one-shot), `session_end` (Reminder, one-shot). Custom categories may be added.

The dispatcher (`scripts/lib/notify-dispatcher.sh`) reads category from the Notification payload's `message` prefix or a `[category]` tag. Absent → defaults to `io_block`.

## Beads templates

Under `templates/beads/*.yaml`. The authoritative bead-mutation policy — `default.yaml` covers the standard case. Full field shape is in the template; the "Bead mutation policy" section above summarizes the important rules.

When authoring a variant (e.g., `readonly.yaml` for sessions that should never mutate beads), keep the top-level `lifecycle` block shape so the coordinator and review agent can read both uniformly.

## State file schema

`<session-dir>/state.json` is rewritten after every significant coordinator action:

```json
{
  "session_id": "tooling-wave-1-3-20260421",
  "slug": "tooling-wave-1-3",
  "started_at": "2026-04-21T18:00:00-05:00",
  "last_updated": "2026-04-21T19:32:14-05:00",
  "status": "running|paused|shutdown|crashed",
  "current_bead": "J121-9kp.2.8",
  "beads_closed": ["J121-9kp.2.5", "J121-9kp.2.6"],
  "beads_scoped": ["J121-9kp.2.5", "J121-9kp.2.6", "J121-9kp.2.7", "J121-9kp.2.8"],
  "timew_open": true,
  "timew_tag": "J121-9kp.2.8",
  "active_branches": {
    "/home/hactar/Source/J121/tasks/sessions/.../clones/chezmoi": "feature/auto-tooling-wave-1-3-20260421"
  },
  "closures_since_review": 2,
  "pending_decisions": ["D-003"]
}
```

On resume, the coordinator reads `state.json` and picks up at `current_bead` if still open, or the next `bd ready` result.

## Decision log format

`<session-dir>/decisions.md` uses structured entries:

```markdown
## D-<NNN>: <short title>

- **Bead**: <id> (or session-level if cross-cutting)
- **Commit**: <sha> (or pending)
- **Logged at**: <ISO-8601 timestamp>
- **Blocking**: yes | no

### Context
Why a decision was needed.

### Alternatives considered
- **A**: <pros> / <cons>
- **B**: <pros> / <cons>
- **C**: <pros> / <cons>

### Decision
What was chosen. Why.

### Reversion plan
Specific steps to undo:
- Branches to revert
- Beads to reopen
- Files to delete or restore
- Side-effects to reverse (pushed branches, published docs, etc.)

### Resolution
(empty while pending) — filled in by user on review: `accepted` | `reverted` | `deferred` with notes
```

### Blocking threshold

A decision is **blocking** iff:
- It gates more than one subsequent bead, OR
- It involves publishing to an external system (push to a shared branch, post to Jira, etc.), OR
- The coordinator genuinely can't pick between alternatives with the available context

Blocking decisions halt the coordinator and fire a `decision_block` notification. Non-blocking decisions are logged with a reversion plan and the coordinator proceeds.

## Logging

Three parallel logs with distinct audit roles.

### Human-readable: `<session-dir>/execution-log.md`

Written by the coordinator only (never by subagents). Append-only. Prose entries:

```markdown
## 2026-04-21 19:32 — J121-9kp.2.8 implementation

Claimed bead; started timew interval. Read the existing wsl-notify-send shim (~/.local/bin/wsl-notify-send)
to understand the current `-Sound` ValidSet. Identified that `IM` is not currently accepted; the shim only
validates `Reminder` and `Alarm`. Delegated an implementation subagent (Sonnet) to extend the shim's
validation to accept the broader ValidSet; see agents/impl-a1b2/result.md.

Committed to chezmoi feature branch `feature/auto-tooling-wave-1-3-20260421` (clone sandbox) at sha
abc1234. Did not push — per sandbox rules, push happens at shutdown.
```

### Machine-readable: `<session-dir>/events.jsonl`

Written by coordinator AND subagents — POSIX-atomic single-line appends. Every event one JSON object on one line, under 4KB. Schema:

```json
{"ts": "2026-04-21T19:32:00-05:00", "agent": "main", "event": "bead_claimed", "bead": "J121-9kp.2.8"}
{"ts": "...", "agent": "main", "event": "timew_started", "tag": "J121-9kp.2.8"}
{"ts": "...", "agent": "impl-a1b2", "event": "subagent_started", "parent": "main", "bead": "J121-9kp.2.8", "model": "sonnet"}
{"ts": "...", "agent": "impl-a1b2", "event": "subagent_completed", "result_file": "agents/impl-a1b2/result.md"}
{"ts": "...", "agent": "main", "event": "commit", "repo": "chezmoi", "sha": "abc1234", "branch": "feature/auto-tooling-wave-1-3-20260421"}
{"ts": "...", "agent": "main", "event": "decision_logged", "id": "D-003", "blocking": false}
{"ts": "...", "agent": "main", "event": "bead_closed", "bead": "J121-9kp.2.8"}
```

Event types (non-exhaustive):
- `session_started`, `session_paused`, `session_resumed`, `session_shutdown`
- `bead_claimed`, `bead_closed`, `bead_deferred`, `bead_blocked`
- `timew_started`, `timew_stopped`
- `subagent_started`, `subagent_completed`, `subagent_failed`
- `commit`, `push`, `branch_created`
- `decision_logged` (with `blocking` boolean)
- `landmark_review_fired`
- `notification_fired` (with `category` = io_block | decision_block | compaction | session_end)
- `compaction_occurred`

### Hook audit: `<session-dir>/hook.log`

Written only by `scripts/lib/hook-wrapper.sh`. Paired `hook_started` / `hook_ended` records per invocation, correlated via a nanosecond-scoped correlation ID. Writes are serialized under `flock` on `hook.log.lock`. Used for diagnosing hung hooks, timeouts, and hook-side errors without mixing them into the event stream. Opt-in daily rotation via `logrotate.d/claude-auto-session.conf` and `systemd/claude-auto-session-logrotate.{service,timer}` (user-level units).

## Subagent patterns

### Briefing scaffold

Every subagent dispatch:

1. Coordinator writes `agents/<type>-<short-id>/brief.md`:
   - Task statement
   - Relevant context (paths, sha, bead ID)
   - Expected deliverable format (summary in return message; full output to `result.md`)
   - Pointers to scratchpad entries the subagent should read (as paths, not inline content)
2. Coordinator invokes via `Agent` tool, passing brief contents as `prompt`.
3. Subagent writes full output to `agents/<type>-<short-id>/result.md`.
4. Subagent returns a one-paragraph summary in its reply message.
5. Coordinator reads only the summary; drills into `result.md` if detail is needed.

### Result-to-file convention

Subagents must write their full output to `result.md` and return only a summary. Keeps the coordinator's context small regardless of subagent verbosity.

### Model tiers

| Subagent role | Model | Rationale |
|---|---|---|
| Gap review | `haiku` | Read-only analysis; fast; cheap |
| Session-reviewer | `haiku` | Pattern matching against conventions; doesn't need deep reasoning |
| Logging helpers | `haiku` | Mechanical work |
| Implementation | `sonnet` | Default; balanced |
| Architecture escalation | `opus` | Only when coordinator flags genuine ambiguity it can't resolve |

Coordinator picks tier per dispatch. Rationale logged in the subagent's `brief.md`.

### timew + bd — single writer

**Only the coordinator manages timew and bd mutations.** Subagents never invoke `bd-timew start/stop/switch`, `bd update --status`, `bd close`, `bd note`, or `bd remember`. This is a hard invariant — timew supports one active interval, and concurrent bd mutations can race on notes/metadata. Subagents may **read** bead state (`bd show`, `bd list`, `bd query`) but may not mutate it.

## Pause / resume

### Pause semantics

True mid-flight pause of a running subagent is not possible (subagents run their tool-call loop to completion). Pause checkpoints happen at coordinator boundaries — between bead iterations, after each subagent returns.

Pause triggers:
- User creates file `<session-dir>/PAUSE` → coordinator sees it at next boundary, writes state, exits cleanly
- User Ctrl+C / Esc → in-flight tool call is killed; whatever was last written is the resumable state

### Resume

User invokes `/auto-session --resume` (or "resume the paused session"). Skill:
1. Lists `tasks/sessions/*/state.json` entries where `status = paused` or `status = crashed`.
2. User picks one.
3. Skill emits the resume instruction (`cd <session-dir> && ./run.sh`).
4. Coordinator (new Claude Code session) reads `state.json`, rebuilds context by reading `execution-log.md` tail + `decisions.md` pending entries + `scratchpad/` summaries, resumes loop.

No marker file to re-create — the session's `.claude/settings.local.json` is already in place.

### Orphan timew intervals

If `state.json` has `timew_open: true` but the user didn't stop the interval before resume, the coordinator stops it (as zero-duration or elapsed-gap per user preference, elicited at resume) and logs the orphan in `execution-log.md`.

## Startup checklist (coordinator's responsibility)

Before entering the execution loop:
1. Read `prompt.md` end-to-end.
2. Read `CLAUDE.md` (redundant with cwd auto-load but makes the single-writer and compaction rules explicit on cold start).
3. Read `state.json`; detect orphan timew intervals.
4. Verify active branches in `state.json` match actual git state (warn on drift).
5. Re-run `bd ready` to get current dependency-aware bead queue.
6. Emit `session_started` or `session_resumed` JSONL event.

## Shutdown checklist

1. Stop timew if open.
2. Commit + push all `in-place + current` repos with pending changes (pre-authorized only).
3. Push feature branches for `feature`-branch repos.
4. Write final `state.json` (`status: shutdown`).
5. Append shutdown entry to `execution-log.md`.
6. Emit `session_shutdown` JSONL event.
7. Write `<session-dir>/exit-summary.md` from `templates/exit-summary.md` (input artifact for `/import-session`).

## Bundled: session-reviewer agent

The skill bundles `agents/session-reviewer.md`. Available two ways:
- **Global**: `install.sh` symlinks it into `~/.claude/agents/` (or `chezmoi apply` handles the symlink for chezmoi-managed users).
- **Per-session**: `scripts/scaffold-autosession.sh` symlinks it into `<session-dir>/.claude/agents/` automatically. No global install needed for auto-sessions.

Role: pattern-compliance review of chezmoi skill/command/agent/config changes on session feature branches. Invoked as `subagent_type: "session-reviewer"`. Reads convention templates from `templates/conventions/` by path (paths included in its brief).

Deleting this skill (`/remove-skill auto-session`) breaks both symlinks; `chezmoi apply` or manual cleanup removes them.

## References

- `install.sh` — one-time global install (agent symlink only); TTY-guarded; idempotent.
- `scripts/scaffold-autosession.sh` — materializes a new session dir; called by the skill at step 4.
- `scripts/lib/hook-wrapper.sh` — two-record watchdog wrapper around any hook; paired start/end log records with correlation IDs.
- `scripts/lib/notify-dispatcher.sh` — Notification hook entry; fires toast + spawns nag-repeater.
- `scripts/lib/nag-repeater.sh` — detached re-nag loop (60s cadence, 30-iteration cap).
- `scripts/lib/preuse-cancel-nag.sh` — PreToolUse hook entry; kills active nag PIDs.
- `scripts/lib/post-compact-rehydrate.sh` — SessionStart:compact hook entry; emits `additionalContext` rehydrate instruction.
- `hooks/settings-fragment.json` — template fragment for per-session `.claude/settings.local.json`; wrapped via hook-wrapper.sh at scaffold time.
- `agents/session-reviewer.md` — bundled review agent.
- `templates/README.md` — template authoring guide.
- `templates/session-claude-md.md` — scaffold for `<session-dir>/CLAUDE.md`.
- `templates/run.sh.tmpl` — scaffold for `<session-dir>/run.sh`.
- `templates/repos/chezmoi.md` — chezmoi-specific preferences (example repo template).
- `templates/conventions/*.md` — opt-in convention documents embedded into `prompt.md`.
- `templates/permissions/default.yaml` — opt-in allowlist bundles merged into the parent project's `.claude/settings.local.json`.
- `templates/alerts/default.yaml` — notification-category policy.
- `templates/beads/default.yaml` — bead mutation policy (lifecycle, metadata, labels, notes, comments, create, remember).
- `templates/exit-summary.md` — scaffold for `<session-dir>/exit-summary.md`.
- `logrotate.d/claude-auto-session.conf` + `systemd/claude-auto-session-logrotate.{service,timer}` — opt-in hook-log rotation.
- Related skill: `/start`, `/stop`, `/switch`, `/status` (time-tracking) — single-bead workflow.
- Related skill: `claude-mem:do` — phased-plan execution (different use case).
