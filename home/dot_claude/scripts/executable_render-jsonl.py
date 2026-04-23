#!/usr/bin/env python3
"""Render a Claude Code session JSONL into a human-readable Markdown transcript.

Ground truth is the JSONL; this script produces a lossy, readable view. When
fidelity matters, diff against the source `.jsonl` file.

Usage:
  render-jsonl.py <session.jsonl> [<out.md>]
  render-jsonl.py --append <session.jsonl> <out.md>

`--append` renders only records not already present in <out.md>, identified by
their `uuid` (embedded in an HTML comment on each turn header). Idempotent: safe
to run repeatedly as a session grows.

Session JSONL files live under ~/.claude/projects/<project-slug>/<session-id>.jsonl
by default. Find the current session id in the SessionStart hook output or via
`ls -t ~/.claude/projects/*/` + the session's cwd.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


UUID_MARKER = re.compile(r"<!--[^>]*?\buuid=([0-9a-f-]{36})[^>]*?-->")


def block_text(block: dict) -> str:
    t = block.get("type")
    if t == "text":
        return block.get("text", "")
    if t == "tool_use":
        name = block.get("name", "?")
        inp = block.get("input", {})
        payload = json.dumps(inp, indent=2, ensure_ascii=False)
        if len(payload) > 1500:
            payload = payload[:1500] + "\n… [truncated; see .jsonl]"
        return f"\n\n> **Tool call:** `{name}`\n>\n> ```json\n{payload}\n> ```\n"
    if t == "tool_result":
        content = block.get("content", "")
        if isinstance(content, list):
            content = "\n".join(
                b.get("text", "") for b in content if isinstance(b, dict)
            )
        body = str(content)
        if len(body) > 1500:
            body = body[:1500] + "\n… [truncated; see .jsonl]"
        return f"\n\n> **Tool result:**\n>\n> ```\n{body}\n> ```\n"
    if t == "thinking":
        return ""  # Omit thinking blocks from the readable view.
    return f"<!-- unhandled block type={t} -->"


def message_text(msg) -> str:
    if isinstance(msg, str):
        return msg
    if isinstance(msg, dict):
        content = msg.get("content", "")
        if isinstance(content, str):
            return content
        if isinstance(content, list):
            return "".join(block_text(b) for b in content if isinstance(b, dict))
    return str(msg)


def text_only(msg) -> str:
    """Concatenate only `type=text` blocks — skip tool_use, tool_result, thinking."""
    if isinstance(msg, str):
        return msg
    if isinstance(msg, dict):
        content = msg.get("content", "")
        if isinstance(content, str):
            return content
        if isinstance(content, list):
            return "".join(
                b.get("text", "") for b in content
                if isinstance(b, dict) and b.get("type") == "text"
            )
    return ""


def render_record(rec: dict, turn_idx: int, mode: str = "full") -> str | None:
    """Return a Markdown chunk for one record, or None to skip it.

    mode="full": all block types rendered (tool_use + tool_result summarised).
    mode="conversation": only user prompts (text, not tool_result) + assistant
    text blocks; intermediate tool-only turns are skipped entirely.
    """
    t = rec.get("type")
    ts = rec.get("timestamp", "")
    uid = rec.get("uuid", "")
    if t == "user":
        body = (text_only if mode == "conversation" else message_text)(
            rec.get("message", {})
        ).strip()
        if not body:
            return None
        if mode == "conversation":
            return (
                f"\n---\n\n## You <!-- ts={ts} uuid={uid} -->\n\n{body}\n"
            )
        return (
            f"\n---\n\n## Turn {turn_idx} — user "
            f"<!-- ts={ts} uuid={uid} -->\n\n{body}\n"
        )
    if t == "assistant":
        body = (text_only if mode == "conversation" else message_text)(
            rec.get("message", {})
        ).rstrip()
        if not body:
            return None
        if mode == "conversation":
            return f"\n### Claude <!-- ts={ts} uuid={uid} -->\n\n{body}\n"
        return f"\n### Assistant <!-- ts={ts} uuid={uid} -->\n\n{body}\n"
    return None  # Skip system/attachment/snapshot/custom-title/last-prompt.


def existing_uuids(md_path: Path) -> set[str]:
    if not md_path.exists():
        return set()
    return set(UUID_MARKER.findall(md_path.read_text()))


def count_user_turns(md_path: Path) -> int:
    if not md_path.exists():
        return 0
    return len(re.findall(r"^## Turn \d+ — user", md_path.read_text(), re.M))


def _header(src: Path, mode: str) -> str:
    if mode == "conversation":
        return (
            f"# Conversation: `{src.name}`\n\n"
            "> **Rendered view — authoritative source is the sibling `.jsonl` file.**\n"
            "> Conversation mode: user prompts + assistant text only. "
            "Tool calls, tool results, thinking, and tool-only assistant turns "
            "are omitted. Each turn carries a `uuid=…` marker for append-merge.\n"
        )
    return (
        f"# Session transcript: `{src.name}`\n\n"
        "> **Rendered view — authoritative source is the sibling `.jsonl` file.**\n"
        "> Tool-use blocks are summarised (input truncated at 1500 chars). "
        "`thinking` blocks are omitted. System / attachment / snapshot records "
        "are omitted. Each turn carries a `uuid=…` marker for append-merge.\n"
    )


def render_full(src: Path, mode: str = "full") -> str:
    lines: list[str] = [_header(src, mode)]
    turn = 0
    with src.open() as f:
        for raw in f:
            raw = raw.strip()
            if not raw:
                continue
            try:
                rec = json.loads(raw)
            except json.JSONDecodeError:
                continue
            if rec.get("type") == "user":
                turn += 1
            chunk = render_record(rec, turn, mode)
            if chunk:
                lines.append(chunk)
    return "\n".join(lines)


def render_append(src: Path, dst: Path, mode: str = "full") -> tuple[int, int]:
    seen = existing_uuids(dst)
    turn_idx = count_user_turns(dst)
    added = 0
    scanned = 0
    with dst.open("a") if dst.exists() else dst.open("w") as out:
        if not seen:
            out.write(_header(src, mode))
        with src.open() as f:
            for raw in f:
                raw = raw.strip()
                if not raw:
                    continue
                try:
                    rec = json.loads(raw)
                except json.JSONDecodeError:
                    continue
                scanned += 1
                uid = rec.get("uuid", "")
                if uid and uid in seen:
                    continue
                if rec.get("type") == "user":
                    turn_idx += 1
                chunk = render_record(rec, turn_idx, mode)
                if chunk:
                    out.write(chunk)
                    added += 1
    return added, scanned


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(prog="render-jsonl")
    ap.add_argument("--append", action="store_true",
                    help="append only new records (by uuid)")
    ap.add_argument("--mode", choices=("full", "conversation"), default="full",
                    help="'full' = all tool-use summarised; "
                         "'conversation' = user prompts + assistant text only")
    ap.add_argument("src", type=Path, help="path to the session .jsonl")
    ap.add_argument("dst", type=Path, nargs="?",
                    help="output .md (default: sibling of src)")
    args = ap.parse_args(argv[1:])

    dst = args.dst or args.src.with_suffix(".md")
    dst.parent.mkdir(parents=True, exist_ok=True)

    if args.append:
        added, scanned = render_append(args.src, dst, args.mode)
        print(f"append[{args.mode}]: scanned={scanned} new={added} -> {dst}")
    else:
        dst.write_text(render_full(args.src, args.mode))
        print(f"wrote[{args.mode}] {dst} ({dst.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
