# Global Claude Instructions

These instructions apply to all projects. Project-specific CLAUDE.md files may extend or override them.

## Session Discipline

- Follow conventional commits: `<type>(<scope>): <description>` with `Co-Authored-By` trailer
- Make commits modular — one logical unit per commit. For multi-step features, commit each layer as you validate it (e.g., domain models, then storage, then service, then config wiring, then routes, then tests). Never batch an entire feature into a single commit.
- Use feature branches for significant work. Branch off the primary working branch, develop incrementally with modular commits, merge back when complete. This keeps the working branch clean and makes changes reviewable.

## Persistent State

Three stores, split by purpose:

- **`bd remember` + `bd memories`** — project-technical facts (pitfalls, naming conventions, environment quirks). Auto-injected at `bd prime` time. Persists via the project's `.beads/` nested repo; requires off-machine sync (push the nested repo, or use Dolt sync) for true account-rotation resistance.
- **Auto-memory** (`~/.claude/projects/<project>/memory/`) — user-specific preferences, collaboration feedback, cross-project user facts. Typed topic files (user/feedback/project/reference) loaded on demand via the auto-memory `MEMORY.md` index. Update organically during sessions when new facts emerge; no ritual "update before /clear" needed.
- **CLAUDE.md** (this file and project-local) — always-on rules and one-line pointers to frequently-relevant auto-memory topics. Graduate durable, broadly-applicable feedback into CLAUDE.md one-liners; keep the "Why:/How to apply:" detail in auto-memory.

Hygiene rules that persist:
- Keep the auto-memory `MEMORY.md` index under 200 lines; archive stale content to `~/.claude/projects/<project>/memory/history.md`
- Create checkpoint files at `~/.claude/projects/<project>/memory/checkpoint-YYYY-MM-DD-<topic>.md` for sessions that advance a roadmap item or make significant decisions — claude-mem observations cover mechanical activity, but gestalt / "where we left off" narrative still benefits from explicit capture. **Checkpoints live in auto-memory, NOT in the project source tree** (e.g., `~/Source/<project>/memory/`); cross-session discoverability matters more than git-versioning for this content
- Do not maintain a repo-root `MEMORY.md` as a state-tracking artifact — it fragments across accounts and duplicates what `bd remember` now handles
- When a doc says "`memory/...`" with no leading path, it means **auto-memory** (`~/.claude/projects/<project>/memory/`). Do not create or look in a `memory/` directory at the project source root

## Network ops in beads workflows

- Do NOT run `bd dolt push` as part of session-end automation, cleanup, or checkpointing. The Dolt-side push is the user's responsibility to run interactively when convenient.
- The JSONL state (the human-readable issues export) IS pushed via plain `git push` from the project's `.beads/` directory. That's small, fast, and adequate for cross-session visibility into bead state.
- This convention exists because `bd dolt push` can stall on transient network issues (LSO bugs, PMTU blackholes, TCP metrics cache poisoning — see project pitfall docs); blocking session-end on it is unacceptable. The JSONL push is reliable; the Dolt push is best-effort.

## Implementation Approach

- Implement features depth-first: complete and validate one unit before starting the next
- Never generate parallel implementations before validating any of them
- For multi-part work, screen each part with minimal effort before committing to full treatment
- Prioritize working software over scaffolding — a running feature beats a planned architecture
- For small-scope work (< 2 hours), prefer a plan-mode discussion followed by implementation over creating a separate planning document. The conversation is the plan; don't persist it as an artifact unless the scope grows

## Verification Before Claiming Completion

Before saying "done", "fixed", "passing", "working", or any equivalent — in the same message that carries the claim:

- **Run the verification command fresh.** Prior-run output doesn't count. "I ran it earlier and it passed" is a claim, not evidence.
- **Mind the gap between tools.** Linter passing ≠ compiler passing. Tests passing ≠ feature works. An agent reporting "success" ≠ code actually changed — check `git diff`.
- **Regression tests need a red-green-red cycle.** If you wrote a test to catch a specific bug, revert the fix, re-run (must fail), restore the fix, re-run (must pass). A test that only passes once isn't a regression test.
- **Multi-item requirements need a checklist.** "Tests pass" ≠ "all requirements met". Re-read the plan, enumerate each item, verify each one. Report gaps explicitly.
- **"Should work now", "I'm confident", and "just this once" are red flags.** They usually mean the command wasn't run. Run it.

## Standing Instructions

- Push back against any aspect of a prompt that seems misguided, vague, ill-informed, or overly ambitious — be direct, not diplomatic
- Discuss alternatives to the proposed approach, summarizing trade-offs concisely
- When a design decision is significant enough to affect the project's direction, flag it and suggest adding it to the project's decision log
- Do not soften feedback to be polite; clarity matters more than comfort

### Beads (bd) Performance

- **Slow `bd` commands** (5-30s): caused by journal bloat or commit history growth in the embedded Dolt store. Fix: `bd compact --days 7 --force && bd gc --skip-decay --force`. Nuclear reset: `bd flatten --force && bd gc --skip-decay --force`. See `~/.claude/references/beads-performance.md`.
- **New project setup**: always run `bd config set dolt.auto-commit batch` and `bd config set no-push true` after `bd init`. Add the daily maintenance cron (commit + compact + gc). Details in the reference file.

### Collaboration Preferences (see auto-memory for full context)

- **Jira comments**: lead with context/methodology, integrate links, connect to team knowledge; avoid prescriptive "next steps" in analysis comments. See `feedback-jira-comment-style.md`.
- **Jira drafts**: track posting status (`posted`, `comment_id`, `target_status`) in YAML frontmatter; always use `contentFormat: "adf"`. See `feedback-jira-draft-frontmatter.md`.
- **Chezmoi edits**: respect templating layers and known pitfalls when modifying dotfiles. See `feedback-chezmoi-patterns.md`.
- **Chezmoi worktree testing**: `chezmoi apply` always reads from the canonical source (`~/.local/share/chezmoi/`), not the active feature worktree. To test from a worktree: `chezmoi apply --source ~/Source/chezmoi-features --force <target>`.

## Review Checkpoints

- After completing each feature or roadmap item, offer a brief review checkpoint
- Review checkpoints should summarize: what changed, decisions made, new bugs/pitfalls found, roadmap impact
- For team projects, persist review summaries to `docs/reviews/`; for personal projects, a verbal summary suffices unless the user requests persistence

## Documentation Practices

- Maintain a single source of truth — never create overlapping summary documents
- Use Markdown links from higher-level docs to detailed explanations rather than duplicating content
- When referencing code, include file paths and line numbers
- Distinguish confirmed facts from hypotheses in all analysis
- Keep documentation proportional to the project's complexity and audience
