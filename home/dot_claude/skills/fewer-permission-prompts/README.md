# fewer-permission-prompts: companion artifacts

This directory holds **companion files** for the built-in
`fewer-permission-prompts` skill. The skill itself ships with Claude
Code (its `SKILL.md` lives in the Claude Code distribution, not here).
Files in this directory are not loaded as a separate skill — Claude
Code only treats a directory as a skill if it contains `SKILL.md`,
which we deliberately omit here so the built-in keeps working.

## scan.py

Frequency counter for tool calls in recent Claude Code transcripts.
Pure mechanical extraction — does NOT classify commands as read-only
vs. mutating. Classification is policy that lives in the skill's
instructions; this script just reports counts.

**When the skill is invoked**, the canonical pipeline is:

1. Run `scan.py --json` to get structured frequency data
2. Apply the skill's filtering rules to the output
3. Produce the final allowlist proposal
4. Merge into the project's `.claude/settings.json`

```bash
python3 ~/.claude/skills/fewer-permission-prompts/scan.py --json
```

### Options

| Flag | Default | Notes |
|---|---|---|
| `--projects-dir PATH` | `~/.claude/projects/` | Where to look for transcripts |
| `--max-files N` | 50 | Most-recently-modified .jsonl files to scan |
| `--min-count N` | 3 | Drop entries with fewer occurrences than this |
| `--json` | (off) | Emit machine-readable JSON instead of a table |
