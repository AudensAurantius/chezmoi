---
name: beads-migration
description: Migrating beads, bd memories, and project auto-memory from one repo to another. TRIGGER when the user asks to "split off", "migrate", "extract", or "spin up beads in" a project that's currently tracked in another bd instance; when a bead has accumulated subtasks that warrant a dedicated project; when factoring shared tooling out of a coordination repo. Encapsulates the end-to-end procedure including known bd-init/bd-timew bugs and their workarounds.
author: Michael Haynes
scope: global
tags: [beads, bd, bd-timew, migration, claude-mem, auto-memory, dolt]
---

# Beads Migration Skill

Procedure for moving a logical project's tracking state — beads, `bd remember`
memories, and auto-memory files — from a source repo's bd instance to a fresh
bd instance in a target repo.

This skill exists because the migration involves several independent stores
(beads database, bd memories, auto-memory markdown files, claude-mem corpus)
and several known bugs in the init tooling that have non-obvious workarounds.
Following the steps in order avoids the bugs and produces a verifiable
end-state.

## When this applies

- The user is "splitting off" or "extracting" a project that has accumulated
  enough beads to deserve its own instance, out of a coordination repo's
  shared bd database.
- The user is initializing beads in a project that already has tracked work
  in another bd instance.
- A subtree of beads (epic + descendants) under a label like
  `area:<topic>` has grown large enough that the topic warrants its own repo.

If the user just wants `bd init` in a fresh project with no migration
component, this skill is overkill — just run `bd init --server` (with the
caveats in step 1 below) and stop.

## Five stores to think about

| Store | What it is | Migration mechanism |
|---|---|---|
| Beads issues | Tasks, deps, comments in the source bd's Dolt DB | `bd export` / `bd import` |
| bd memories | `bd remember` content, also in the Dolt DB | Same — included in `bd export` by default |
| Auto-memory | Markdown files in `~/.claude/projects/<source-hash>/memory/` with `MEMORY.md` index | Manual file copy |
| claude-mem observations | Hosted MCP corpus, keyed by project path | Don't migrate; rebuilds organically per project |
| bd-timew sidecar | `.beads/bd-timew.yaml` billing-tuple config | Author fresh in the target repo |

## Steps

### 1. Initialize beads in the target repo

**Known bug to work around:** `bd init --server` enables JSONL-backup
auto-push by default whenever a git remote is configured on the target
repo. The backup pushes to `refs/heads/main` via regular `git push`, which
conflicts with normal git activity on the same branch and hangs for
~10 min per attempt as the rejected push retries.

This is **independent** of bd's `no-push` setting (which gates dolt-push
after writes, NOT the JSONL backup). It's also independent of dolt's own
server-side replication (which is off by default — checked via
`SELECT @@dolt_replicate_to_remote`). The JSONL backup is a third
mechanism with its own config key: `backup.git-push`.

**Safe init path:**

```bash
cd <target-repo>
bd init --server

# Disable JSONL-backup auto-push immediately, before any further writes
# trigger it. Direct file edit avoids the chicken-and-egg of `bd config set`
# itself triggering the hang.
cat >> .beads/config.yaml <<'YAML'

backup:
  git-push: false
YAML
```

Pointing the dolt remote at the same git repo as the source code is fine
(it uses the `refs/dolt/data` ref namespace, which doesn't collide with
`refs/heads/*`). Only the JSONL backup uses `refs/heads/main` and needs
to be disabled.

Then run bd-timew init-project:

```bash
bd-timew init-project --server
```

After bd-timew init-project completes, edit `.beads/bd-timew.yaml` for the
target project's billing-tuple defaults. Keep `patterns:` empty if the
target project has a single billing category; copy the relevant pattern
rules from the source repo's sidecar otherwise.

Apply the standard performance settings:

```bash
bd config set dolt.auto-commit batch
bd config set no-push true
```

Smoke test:

```bash
bd ready                                                       # should be empty
bd create --title="smoke" --type=task --priority=4
bd list && bd close <id> && bd ready                            # should be empty again
```

### 2. Audit the source bd instance for beads to migrate

In the source repo, identify the bead set that belongs in the target. The
typical filter is one of:

```bash
bd list --label=area:<topic> --json    # all beads under a specific area
bd list --label-pattern='area:<topic-prefix>*' --json
bd show <epic-id> --tree                # an epic and all descendants
```

Produce a candidate list and **classify each** as:

- **Migrate** — clearly belongs in the target repo
- **Plugin candidate** — belongs in target, but represents a workflow
  integration that may later be extracted into a plugin (tag with
  `area:plugin-candidate` after import to make later extraction easy to
  query)
- **Leave in source** — context is too coupled to source-specific work
  (e.g., source-only pipelines, source-only schemas, source-team
  responsibilities)
- **Defer** — can't decide; skip this round, revisit later

Capture the classification in a one-shot doc at
`docs/migration/bead-migration-plan.md` in the target repo. Include source
ID, title, status, and classification rationale per row. This doc gets
deleted after migration completes.

### 3. Verify the bd export/import round-trip on a sample

Before bulk migration, test that hierarchy and labels survive:

```bash
# In source
cd <source-repo>
bd show <parent-id> --json > /tmp/parent.jsonl
bd show <child-id>  --json > /tmp/child.jsonl

# In target
cd <target-repo>
bd import < /tmp/parent.jsonl   # parents must be imported before children
bd import < /tmp/child.jsonl
bd show <new-child-id> --tree   # confirm parent link survived
```

If parent-child links don't survive import, fall back to manual recreation
via `bd create --parent <new-parent-id>`. Document the workaround in the
migration plan.

### 4. Bulk-migrate beads + memories together

`bd export` includes memories from `bd remember` by default (use
`--no-memories` to exclude). Single export covers both stores.

```bash
# In source
cd <source-repo>
bd export -o /tmp/migration-export.jsonl
# (Filter to the migration set if the source has unrelated content.
# `bd export --label=area:<topic>` style filters; check `bd export --help`
# for current flags.)

# In target
cd <target-repo>
bd import < /tmp/migration-export.jsonl
```

Verify after import:

```bash
bd list                              # spot-check titles
bd show <new-id>                     # spot-check labels, status, parent
bd memories                          # confirm migrated memories present
```

### 5. Filter migrated bd memories

Because `bd export` mixes beads and memories, expect post-import housekeeping:

```bash
bd memories                          # list all
bd memories <topic-keyword>          # search for a specific topic

# Forget memories that don't belong in the target:
bd forget <memory-id>
```

If a memory belongs in BOTH the source and the target, it's fine to leave
it in both — separate instances, no global uniqueness constraint.

### 6. Migrate auto-memory files

Auto-memory lives at `~/.claude/projects/<path-hash>/memory/`. The hash is
derived from the project path, so the source and target have different
directories.

```bash
SRC=~/.claude/projects/<source-path-hash>/memory
DST=~/.claude/projects/<target-path-hash>/memory
mkdir -p "$DST"
```

Walk through `$SRC/MEMORY.md` (the index) and classify each entry:

- **Migrate:** copy the file to `$DST/`, add an entry in `$DST/MEMORY.md`,
  remove the entry from `$SRC/MEMORY.md`.
- **Leave in source:** no action.
- **Both:** copy to `$DST/`, keep in `$SRC/`, add to both indexes.

For migrated files, audit the frontmatter `description:` field — if it
references the source repo by name, update to match the target's framing.

### 7. Update cross-references in the source repo

If the source's CLAUDE.md or docs link to memory files that have moved,
update those references. Either:

- Replace with a one-line stub at the source location pointing to the
  target's path, or
- Update the link target to the target repo's auto-memory directory, or
- Remove the link entirely if the content is no longer relevant to source.

```bash
grep -rE 'memory/<migrated-filename>' <source-repo>/CLAUDE.md <source-repo>/docs/
```

### 8. Close source beads with reasons

For each migrated bead, close it in the source instance with a reason
referencing the new ID:

```bash
cd <source-repo>
bd close <old-id> --reason="Migrated to <target-project> (new id: <new-id>)"
```

Close parent epics last (after all children).

### 9. Verify and clean up

- Open a Claude session in the target repo and confirm migrated memories
  appear in the SessionStart context.
- Open a session in the source repo and confirm migrated memories are gone
  (only source-specific memories remain).
- `grep` source for any reference to a migrated filename to confirm no
  broken links.
- Delete the migration plan doc (`docs/migration/bead-migration-plan.md`
  in the target).
- Add a memory in the target about the migration date, source repo, and
  bead-ID-mapping summary if useful for future audit.

### 10. claude-mem observations (no action required)

claude-mem observations are in a hosted/MCP corpus keyed by project path.
Migration is not file-based; there's nothing to copy.

Two facts worth knowing:

1. **`mem-search` and `query_corpus` span corpora** — searches return
   matching observations regardless of source project. Migration isn't
   required for cross-project recall.
2. **The target project's corpus seeds itself organically** as soon as
   sessions begin. No manual intervention needed.

If specific source observations should surface at SessionStart in the
target, distill them into auto-memory checkpoint files (step 6) — that's
where persistent value belongs.

## Verification checklist

Before declaring the migration complete:

- [ ] Target repo has working `.beads/` (smoke test from step 1 passes)
- [ ] All beads in the migration plan's "migrate" classification appear in
      `bd list` in the target with correct labels, status, and hierarchy
- [ ] Plugin-candidate beads are tagged `area:plugin-candidate` for later
      extraction queries
- [ ] `bd memories` in target shows the migrated memories; non-migrated
      ones are absent or were `bd forget`-ed
- [ ] Auto-memory files copied; source and target `MEMORY.md` indexes
      reflect the split
- [ ] Cross-references in source CLAUDE.md / docs are updated or removed
- [ ] Source beads closed with migration-pointer reasons
- [ ] Migration plan doc removed from target repo

## Known issues and their workarounds

- **`bd init --server` enables JSONL-backup auto-push on `refs/heads/main`
  when a git remote exists.** This conflicts with the source code on the
  same branch and hangs for ~10 min per push attempt. Always disable
  `backup.git-push` immediately after `bd init --server` per step 1, BEFORE
  running any further bd writes (including `bd-timew init-project`, which
  itself does writes).

  Diagnostic clue: `cat .beads/dolt-server.log` shows
  `main -> main (non-fast-forward)` errors. This is regular git, not
  dolt's own replication — `SELECT @@dolt_replicate_to_remote` returns
  empty in a default `bd init --server` setup.

  Three independent push mechanisms exist; don't conflate them:

  1. `no-push` (bd config) — gates bd's own dolt-push after writes
  2. `dolt_replicate_to_remote` (dolt persisted var) — server-side
     replication; off by default
  3. `backup.git-push` (bd config) — JSONL backup git push; **on by
     default when a git remote exists** ← the gotcha

- **`bd export` parent-child link preservation** — confirmed working in
  bd 1.0.2+ (parent-child hierarchy survives round-trip intact). Always
  test on a sample first (step 3) in case behavior differs in your version.
  Fall back to manual `bd create --parent` if links break.

- **`bd export --no-memories` exists** for cases where you want to migrate
  beads without memories. Useful when the source repo's memories are too
  source-specific to be worth filtering after import.

- **bd ID preservation on import (bd 1.0.2+).** IDs are preserved on
  import — the source prefix and number carry over unchanged into the
  target instance. This simplifies cross-referencing during the transition
  window (no mapping table needed when closing source beads). Confirm
  with the round-trip test in step 3; older versions may behave differently.
