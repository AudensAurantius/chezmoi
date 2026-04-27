---
name: exit-summary
description: Structured session-close document produced at shutdown. Lives at <session-dir>/exit-summary.md (not memory/). Imported into project-native conventions by /import-session.
---

<!--
This template is copied by the coordinator to <session-dir>/exit-summary.md at shutdown and filled in.
Field placeholders are <bracketed> or TODO. Remove this HTML comment and the frontmatter above before finalizing.

The exit summary is the canonical "what happened in this session" artifact. It references but does not duplicate:
- decisions.md (decision log with reversion plans)
- execution-log.md (narrative)
- events.jsonl (machine-readable event stream)
- state.json (resumable state)
- agents/*/result.md (subagent outputs)

Keep the exit summary terse and indexical — point at those files for detail, don't re-paginate.
-->

# Exit summary — <session-slug> (<YYYY-MM-DD>)

<!--
One paragraph: who ran the session, what model tier, what scope, what was accomplished at a high level, where it landed. Mirrors the lead of a J121 memory/checkpoint-*.md but framed as exit rather than checkpoint.
-->

<Lead paragraph.>

## Session metadata

- **Slug**: <session-slug>
- **Session dir**: <absolute path to tasks/sessions/<slug>-<date>/>
- **Started at**: <ISO-8601>
- **Ended at**: <ISO-8601>
- **Coordinator model**: <sonnet | opus>
- **Subagent model tiers**: <as configured in scope>
- **Scope**: <one-line summary of the bead set>
- **Beads in scope**: <count>; **closed**: <count>; **deferred**: <count>

## What changed

<!--
Group by bead. For each bead that was worked (whether closed or partial), one subsection with: bead ID + title, repos touched, commits (with sha + one-line purpose), key files, link to subagent result files if relevant, link to decision entries if any were logged for this bead.

If a bead was deferred without work, note it under Deferred instead.
-->

### <J121-xxx> — <bead title>

- **Repos**: <list>
- **Commits**:
  - `<sha>` (<repo>): <one-line purpose>
- **Files**: <key paths>
- **Subagent results**: <agents/<type>-<id>/result.md>, ...
- **Decisions**: D-<nnn>, ...

<!-- Repeat per bead -->

## Decisions

<!--
Pointer table, not duplication. One row per decision logged during the session. User (on /import-session or manual review) decides which get promoted to project decision logs, which get archived, which get reverted.
-->

| ID | Title | Blocking | Resolution | Pointer |
|---|---|---|---|---|
| D-001 | <short title> | no | pending / accepted / reverted / deferred | decisions.md#d-001 |
| D-002 | <short title> | yes | ... | decisions.md#d-002 |

See `decisions.md` for full context, alternatives, rationale, and reversion plans.

## Discoveries

<!--
Technical findings, pitfalls, environment quirks discovered during the session. These are candidates for bd remember (durable project facts) or auto-memory (user-specific preferences) promotion via /import-session.

Phrase each as a standalone fact the next session could act on without reading the surrounding narrative.
-->

- <fact> — <one-line context + pointer to scratchpad/findings/<file> or commit sha>
- <fact>

## Pending at exit

<!--
For resume-or-not decisions. What's incomplete, what's unpushed, what's in flight.
-->

- **Beads open (claimed or in_progress)**: <list>
- **Branches unpushed**: <repo → branch>
- **Local-only state**: <e.g., clones retained at session-dir/clones/>
- **Timewarrior**: <stopped cleanly | orphan interval detected and closed | N/A>
- **Session status** (per state.json): <shutdown | paused | crashed>

## Artifacts produced

<!--
Files the session created or substantively modified outside of the session working dir. Targets for /import-session promotion.

Do NOT list every file touched; list deliverables a human reviewer would want to know about.
-->

- **New skills/commands/agents (chezmoi)**:
  - `home/dot_claude/<path>` — <purpose>
- **New references**:
  - `home/dot_claude/references/<name>.md` — <purpose>
- **Project docs updated** (e.g., CLAUDE.md, docs/*):
  - <path> — <change summary>
- **Checkpoint / summary files written**:
  - `<session-dir>/exit-summary.md` (this file)

## Deferred

<!--
Work identified during the session but postponed. Typically: new beads filed, existing beads annotated, open questions captured. Each item should be actionable by a future session without re-reading the execution log.
-->

- **New beads filed**: J121-xxx, J121-yyy — <one-line summary each>
- **Annotated beads**: J121-zzz — <what was added>
- **Open questions** (no bead yet): <list>

## Blockers

<!--
What's blocked at exit. If nothing, say "None." Be specific: which bead, what's blocking it, what resolution looks like.
-->

<list or "None">

## Recommended next steps

<!--
What the next session should pick up. Two-to-four bullets, each concrete enough to act on. Ordering suggestion welcome.
-->

1. <step>
2. <step>

## Active state at draft time

<!--
Snapshot of the concrete world state at shutdown. Supports resume and /import-session without requiring re-running git status everywhere.
-->

- **Session status**: <shutdown | paused>
- **Timer**: <stopped | running on J121-xxx>
- **Beads pending close**: <list or "none">
- **For each modified repo**:
  - **<repo-path>** (sandbox: <location>+<branch>)
    - Working tree: <clean | dirty with N modified / M untracked>
    - Current branch: <name>
    - Unpushed commits: <count> (<sha list if ≤ 6>)
    - Untracked files of note: <list or "none">

## Import hints for /import-session

<!--
OPTIONAL but recommended: hints for the /import-session command about how to map these deliverables into project-native conventions. Keep it concrete.
-->

- **Checkpoint file suggestion**: `memory/checkpoint-<YYYY-MM-DD>-<topic>.md`, topic = <slug or derived>
- **bd remember candidates**: <list of discoveries that should be promoted>
- **auto-memory candidates**: <list of user-preference facts discovered>
- **MEMORY.md index entries to add**: <list or "none">
- **decisions to promote to docs/reviews/**: <list of D-nnn with suggested filenames>
