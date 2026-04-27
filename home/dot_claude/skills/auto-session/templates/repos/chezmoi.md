---
name: chezmoi
applies_to:
  repo_paths:
    - ~/.local/share/chezmoi
  repo_name_patterns:
    - "*chezmoi*"
sandbox:
  location: clone              # pinned — chezmoi main must stay usable by the primary interactive session
  branch: feature              # pinned — never commit directly to chezmoi main during an autonomous session
---

# Chezmoi repo preferences

Repo-specific directives for autonomous-session work in the chezmoi source tree. Applied whenever the session targets the canonical chezmoi repo at `~/.local/share/chezmoi`.

## Why both dimensions are pinned

- **`location: clone`** — the canonical chezmoi repo is the source of truth for live dotfiles. The primary interactive session (and `chezmoi apply` in regular shells) operates against its main branch. Modifying main during an autonomous session would either (a) block the primary session from using chezmoi, or (b) create divergent commits that fight each other.
- **`branch: feature`** — config objects (skills, commands, agents, hooks, settings) are high-blast-radius. A bad skill auto-fires across all sessions until caught; a bad hook affects every Claude Code invocation. Feature-branch discipline ensures the user reviews before anything lands on main and before `chezmoi apply` picks it up.

Both dimensions are pinned because **either** alone is insufficient. `clone` alone with `branch: current` would still push to main at shutdown. `feature` alone with `location: in-place` would still contend with the primary session for the working tree.

## Working-copy location

Clone lands at `<session-dir>/clones/chezmoi/`. All chezmoi commands in the session must use `--source=<clone-path>` to point chezmoi at the clone:

```bash
chezmoi --source=$SESSION_CLONE execute-template home/dot_claude/skills/foo/SKILL.md.tmpl
chezmoi --source=$SESSION_CLONE apply --dry-run --destination=/tmp/chezmoi-test-dest
chezmoi --source=$SESSION_CLONE diff
```

The coordinator should export `SESSION_CLONE=<session-dir>/clones/chezmoi` once at launch and re-use it.

## Render-only command allowlist

These commands are safe during the session (they don't mutate the user's live dotfiles):

- `chezmoi --source=<clone> execute-template <file>` — render a `.tmpl` file's output; pure function of source + chezmoi data
- `chezmoi --source=<clone> apply --dry-run` — compute the diff chezmoi *would* apply; does not write
- `chezmoi --source=<clone> apply --dry-run --destination=<throwaway-dir>` — same, but targeting a temp dir for inspection
- `chezmoi --source=<clone> diff` — show differences between chezmoi source and destination
- `chezmoi --source=<clone> status` — list files chezmoi would manage
- `chezmoi --source=<clone> data` — dump the template data context
- `chezmoi --source=<clone> managed` — list files under chezmoi's management

Git operations on the clone are safe (branch ops, commits, diffs, log). These do not affect the canonical repo until shutdown push.

## Forbidden commands

**Never run any of these during an autonomous session**, even with `--dry-run` variations not listed:

- `chezmoi apply` **without** `--dry-run` — mutates live dotfiles
- `chezmoi apply` **without** `--source=<clone>` — applies canonical source, bypassing the session's isolation
- `chezmoi update` — pulls and applies; mutates live dotfiles
- `chezmoi re-add` / `chezmoi add` against the canonical repo — adds live files to canonical source, bypassing the clone
- `git push origin main` (from the clone) — would overwrite canonical main
- `git merge` / `git rebase` **from feature branch to main** — same effect
- `chezmoi edit` — writes to canonical source
- `chezmoi cd` (in a way that drops the session into a canonical-source shell) — not strictly forbidden but risky; prefer `cd <clone-path>`

If the coordinator finds itself wanting to run a forbidden command, that's a signal to **halt and log a blocking decision** — not a signal to find a workaround.

## Branch naming

- Feature branch: `feature/auto-<session-slug>-<YYYYMMDD>`
- Example: `feature/auto-tooling-wave-1-3-20260421`
- One branch per session; do not create multiple feature branches within a single session without explicit user sign-off

If a session is resumed and the feature branch already exists on canonical, the coordinator:
1. Verifies no conflicting changes have been made to main in the interim (`git fetch origin main && git merge-base --is-ancestor <base-sha> origin/main`)
2. Continues committing to the existing branch
3. If main has advanced and the branch can't cleanly continue, halts and logs a blocking decision

## Push policy at shutdown

- Push `feature/auto-<slug>-<YYYYMMDD>` to `origin` (= canonical chezmoi repo) if there are any commits
- **Do not** fast-forward main
- **Do not** delete the feature branch after push
- Leave the clone in place at `<session-dir>/clones/chezmoi/` for user review

Push command:
```bash
cd $SESSION_CLONE
git push origin feature/auto-<slug>-<YYYYMMDD>
```

This is pre-authorized — chezmoi feature branches are on J121's push-without-asking list. Main is not.

## Validation limits

There is no dry-run equivalent for functional validation of a skill or command. `chezmoi apply --dry-run` verifies that template rendering doesn't fail and that the rendered files match expected attributes; it does not verify that a skill's trigger language behaves correctly at auto-fire time, or that a slash command's instructions produce correct results when invoked.

Functional validation is deferred to the user's post-session review. The coordinator should not claim a chezmoi change "works" based only on successful rendering — it should claim "renders cleanly" and flag the functional-validation gap in the execution log.

## Known pitfalls

- **Chezmoi symlink source-file prefix**: files named `symlink_foo.md` in chezmoi source become symlinks at apply time, with the file contents specifying the target path. Do not edit these as if they were regular files; use `chezmoi edit` or write the symlink declaration explicitly.
- **`modify_` source-file prefix**: files named `modify_foo` are scripts that modify existing files rather than overwriting them. Used for files like `settings.json` where only specific keys should be managed. When editing these, remember the script's job is to merge, not replace.
- **Executable prefix**: `executable_<name>` makes the rendered file executable. Don't strip the prefix when renaming.
- **Template syntax**: `.tmpl` suffix marks files as Go templates. Typos in template syntax produce render errors at `chezmoi apply` time, which the session's `--dry-run` will catch — but only if the session actually renders the template. Always render after editing.
