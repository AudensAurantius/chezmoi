#!/usr/bin/env python3
"""Scan recent Claude Code transcripts for tool-call frequencies.

Companion to the built-in `fewer-permission-prompts` skill. Pure
mechanical extraction — this script does NOT classify commands as
read-only vs. mutating. Classification is policy that lives in the
skill's instructions; this script just reports counts.

The skill's pipeline is:
  1. Run this script (frequency extraction)
  2. Apply the skill's classification rules to filter the output
  3. Produce the final allowlist proposal
  4. Merge into the project's .claude/settings.json

Usage:
  scan.py [--max-files N] [--projects-dir PATH] [--min-count N] [--json]

Output:
  - Default: human-readable table of top Bash + MCP tool calls
  - --json:  machine-readable JSON dump

Defaults:
  --projects-dir ~/.claude/projects/
  --max-files    50 (most-recently-modified .jsonl transcripts)
  --min-count    3  (threshold for inclusion in output)
"""
import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path


def parse_bash(cmd: str):
    """Extract leading command + first subcommand from a Bash invocation.

    Strips env-var prefixes (FOO=bar baz qux), leading sudo/timeout, and
    truncates at the first pipe/redirect/control character.

    Returns (command, subcommand). subcommand is '' if absent or doesn't
    look like a subcommand (starts with -, /, or contains =).
    """
    s = cmd.strip()
    # Strip env-var prefixes: FOO=bar baz, FOO="bar baz" qux, FOO='bar' qux
    while True:
        m = re.match(r"^[A-Z_][A-Z0-9_]*=(?:\"[^\"]*\"|'[^']*'|\S+)\s+", s)
        if not m:
            break
        s = s[m.end():]
    # Strip leading sudo / timeout (each may take a flag arg)
    while True:
        m = re.match(r'^(?:sudo(?:\s+-[A-Za-z]+)?|timeout(?:\s+\S+)?)\s+', s)
        if not m:
            break
        s = s[m.end():]
    # Truncate at first pipe / redirect / shell-control
    s = re.split(r'[|;&<>]|&&|\|\|', s)[0].strip()
    parts = s.split()
    if not parts:
        return None, None
    cmd_name = parts[0]
    sub = parts[1] if len(parts) > 1 else ''
    if sub and (sub.startswith('-') or sub.startswith('/') or '=' in sub):
        sub = ''
    return cmd_name, sub


def find_recent_transcripts(projects_dir: Path, max_files: int):
    """Find the N most-recently-modified .jsonl files under projects_dir."""
    if not projects_dir.is_dir():
        return []
    candidates = []
    for jsonl in projects_dir.rglob('*.jsonl'):
        try:
            candidates.append((jsonl.stat().st_mtime, jsonl))
        except OSError:
            continue
    candidates.sort(key=lambda x: -x[0])
    return [p for _, p in candidates[:max_files]]


def scan_transcript(path: Path, bash_counter: Counter, mcp_counter: Counter):
    """Accumulate tool-call frequencies from one transcript file. Returns
    count of tool-uses observed."""
    count = 0
    try:
        with path.open('rb') as fh:
            for line in fh:
                try:
                    obj = json.loads(line)
                except (json.JSONDecodeError, UnicodeDecodeError):
                    continue
                if obj.get('type') != 'assistant':
                    continue
                msg = obj.get('message', {}) or {}
                content = msg.get('content', [])
                if not isinstance(content, list):
                    continue
                for c in content:
                    if not isinstance(c, dict):
                        continue
                    if c.get('type') != 'tool_use':
                        continue
                    name = c.get('name', '')
                    inp = c.get('input', {}) or {}
                    count += 1
                    if name == 'Bash':
                        cmd, sub = parse_bash(inp.get('command', ''))
                        if cmd:
                            bash_counter[(cmd, sub)] += 1
                    elif name.startswith('mcp__'):
                        mcp_counter[name] += 1
    except (IOError, OSError):
        pass
    return count


def main():
    ap = argparse.ArgumentParser(
        description=__doc__.split('\n\n')[0],
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    ap.add_argument('--projects-dir', type=Path,
                    default=Path.home() / '.claude' / 'projects',
                    help='Claude transcripts dir (default: ~/.claude/projects/)')
    ap.add_argument('--max-files', type=int, default=50,
                    help='Max transcripts to scan (default: 50)')
    ap.add_argument('--min-count', type=int, default=3,
                    help='Minimum count threshold for output (default: 3)')
    ap.add_argument('--json', action='store_true',
                    help='Emit machine-readable JSON instead of a table')
    args = ap.parse_args()

    files = find_recent_transcripts(args.projects_dir, args.max_files)
    if not files:
        print(f'No .jsonl transcripts found under {args.projects_dir}',
              file=sys.stderr)
        sys.exit(1)

    bash_counter: Counter = Counter()
    mcp_counter: Counter = Counter()
    total = 0
    for fp in files:
        total += scan_transcript(fp, bash_counter, mcp_counter)

    bash_results = [
        {'command': cmd, 'subcommand': sub, 'count': count}
        for (cmd, sub), count in bash_counter.most_common()
        if count >= args.min_count
    ]
    mcp_results = [
        {'name': name, 'count': count}
        for name, count in mcp_counter.most_common()
        if count >= args.min_count
    ]

    if args.json:
        json.dump({
            'transcripts_scanned': len(files),
            'tool_calls_observed': total,
            'bash': bash_results,
            'mcp': mcp_results,
        }, sys.stdout, indent=2)
        print()
    else:
        print(f'Scanned {len(files)} transcripts; {total} tool-uses observed.')
        print()
        print(f'Bash commands (count >= {args.min_count}):')
        print('-' * 60)
        for r in bash_results[:40]:
            label = f"{r['command']} {r['subcommand']}".rstrip()
            print(f"  {r['count']:5d}  {label}")
        print()
        print(f'MCP tools (count >= {args.min_count}):')
        print('-' * 60)
        for r in mcp_results[:25]:
            print(f"  {r['count']:5d}  {r['name']}")


if __name__ == '__main__':
    main()
