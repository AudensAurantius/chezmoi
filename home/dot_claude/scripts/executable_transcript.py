#!/usr/bin/env python3
"""Manage conversation-transcript spools.

Backs the /start-transcript, /pause-transcript, /resume-transcript,
/stop-transcript slash commands. Delegates rendering to the sibling
`render-jsonl.py` script.

State lives in ~/.claude/state/transcripts/<short-hash>.json, one file per
active spool. Multiple spools can be active at once (different out-paths).

Subcommands:
  start <out.md> --mode {full|conversation|context-only} [--session <jsonl>]
  pause [<out.md>]        # append + mark paused (state retained)
  resume [<out.md>]       # append + mark active
  stop  [<out.md>]        # final append + remove state (alias: pause+rm)
  status                  # list active + paused spools
  append [<out.md>]       # catch up without changing status (internal)

When <out.md> is omitted on pause/resume/stop/append and exactly one spool
is known, it is used implicitly. With multiple, the command errors.

context-only mode is a no-op here — the slash command handles it in
Claude directly; no state is persisted.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

STATE_DIR = Path.home() / ".claude" / "state" / "transcripts"
RENDER_SCRIPT = Path.home() / ".claude" / "scripts" / "render-jsonl.py"
PROJECTS_DIR = Path.home() / ".claude" / "projects"


def slug_for_cwd(cwd: Path) -> str:
    """Replicate Claude Code's project-directory naming: /a/b/c -> -a-b-c."""
    return "-" + str(cwd.resolve()).replace("/", "-").lstrip("-")


def detect_current_session() -> Path | None:
    """Return the most-recently-modified JSONL under the current project's dir."""
    slug = slug_for_cwd(Path.cwd())
    candidates = sorted(
        (PROJECTS_DIR / slug).glob("*.jsonl"),
        key=lambda p: p.stat().st_mtime,
        reverse=True,
    ) if (PROJECTS_DIR / slug).exists() else []
    return candidates[0] if candidates else None


def state_path(out_md: Path) -> Path:
    """State file for a given out-path. Deterministic; survives rename."""
    h = hashlib.sha256(str(out_md.resolve()).encode()).hexdigest()[:12]
    return STATE_DIR / f"{h}.json"


def load_state(state_file: Path) -> dict:
    return json.loads(state_file.read_text())


def save_state(state_file: Path, data: dict) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    state_file.write_text(json.dumps(data, indent=2))


def now_iso() -> str:
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


def list_states() -> list[dict]:
    if not STATE_DIR.exists():
        return []
    out = []
    for f in sorted(STATE_DIR.glob("*.json")):
        try:
            d = json.loads(f.read_text())
            d["_state_file"] = str(f)
            out.append(d)
        except Exception:
            continue
    return out


def resolve_state_file(out_md: Path | None) -> tuple[Path, dict]:
    """Given a possibly-omitted out-path, return (state_file, state_data)."""
    if out_md:
        sf = state_path(out_md)
        if not sf.exists():
            print(f"transcript: no active spool for {out_md}", file=sys.stderr)
            sys.exit(2)
        return sf, load_state(sf)
    existing = list_states()
    if not existing:
        print("transcript: no active spools", file=sys.stderr)
        sys.exit(2)
    if len(existing) > 1:
        print("transcript: multiple active spools — specify the out path:",
              file=sys.stderr)
        for e in existing:
            print(f"  {e.get('out_md')} [{e.get('status')}]", file=sys.stderr)
        sys.exit(2)
    d = existing[0]
    return Path(d["_state_file"]), d


def run_render(src: Path, dst: Path, mode: str, append: bool) -> int:
    cmd = [str(RENDER_SCRIPT)]
    if append:
        cmd.append("--append")
    cmd += ["--mode", mode, str(src), str(dst)]
    return subprocess.run(cmd).returncode


def cmd_start(args: argparse.Namespace) -> int:
    out_md = Path(args.out).resolve()
    out_md.parent.mkdir(parents=True, exist_ok=True)
    mode = args.mode
    if mode == "context-only":
        print("transcript: context-only mode is handled by the slash command "
              "(no daemon state). Have Claude render current context to the "
              "output path directly.", file=sys.stderr)
        return 3

    if args.session:
        session_jsonl = Path(args.session).resolve()
    else:
        detected = detect_current_session()
        if not detected:
            print(f"transcript: could not detect current session JSONL under "
                  f"{PROJECTS_DIR}/{slug_for_cwd(Path.cwd())}/. "
                  f"Pass --session explicitly.", file=sys.stderr)
            return 4
        session_jsonl = detected

    sf = state_path(out_md)
    if sf.exists():
        print(f"transcript: spool already registered for {out_md}. "
              f"Use /stop-transcript first if you want to re-start.",
              file=sys.stderr)
        return 5

    # Initial render (full rewrite, not append).
    if run_render(session_jsonl, out_md, mode, append=False) != 0:
        return 6

    out_jsonl: str | None = None
    if mode == "full":
        sib = out_md.with_suffix(out_md.suffix + ".jsonl") \
            if out_md.suffix != ".jsonl" else out_md.with_suffix(".source.jsonl")
        # Prefer the cleaner ".jsonl" sibling (replace .md suffix if present).
        if out_md.suffix == ".md":
            sib = out_md.with_suffix(".jsonl")
        shutil.copy(session_jsonl, sib)
        out_jsonl = str(sib)

    save_state(sf, {
        "out_md": str(out_md),
        "out_jsonl": out_jsonl,
        "mode": mode,
        "session_jsonl": str(session_jsonl),
        "status": "active",
        "started_at": now_iso(),
        "updated_at": now_iso(),
    })
    print(f"transcript: started [{mode}] {out_md}")
    if out_jsonl:
        print(f"  verbatim JSONL copy: {out_jsonl}")
    print(f"  source session:      {session_jsonl}")
    return 0


def _append_and_sync(data: dict) -> None:
    """Render-append + refresh verbatim JSONL copy if applicable."""
    src = Path(data["session_jsonl"])
    dst = Path(data["out_md"])
    mode = data.get("mode", "full")
    run_render(src, dst, mode, append=True)
    if data.get("out_jsonl"):
        shutil.copy(src, data["out_jsonl"])
    data["updated_at"] = now_iso()


def cmd_pause(args: argparse.Namespace) -> int:
    sf, data = resolve_state_file(Path(args.out).resolve() if args.out else None)
    _append_and_sync(data)
    data["status"] = "paused"
    save_state(sf, data)
    print(f"transcript: paused {data['out_md']}")
    return 0


def cmd_resume(args: argparse.Namespace) -> int:
    sf, data = resolve_state_file(Path(args.out).resolve() if args.out else None)
    # On resume: re-detect current session if different from stored.
    if args.session:
        data["session_jsonl"] = str(Path(args.session).resolve())
    else:
        detected = detect_current_session()
        if detected and str(detected) != data.get("session_jsonl"):
            print(f"transcript: session changed — now tracking {detected}")
            data["session_jsonl"] = str(detected)
    _append_and_sync(data)
    data["status"] = "active"
    save_state(sf, data)
    print(f"transcript: resumed {data['out_md']}")
    return 0


def cmd_stop(args: argparse.Namespace) -> int:
    sf, data = resolve_state_file(Path(args.out).resolve() if args.out else None)
    _append_and_sync(data)
    sf.unlink()
    print(f"transcript: stopped {data['out_md']} (state removed)")
    return 0


def cmd_append(args: argparse.Namespace) -> int:
    sf, data = resolve_state_file(Path(args.out).resolve() if args.out else None)
    _append_and_sync(data)
    save_state(sf, data)
    print(f"transcript: appended {data['out_md']}")
    return 0


def cmd_status(_args: argparse.Namespace) -> int:
    spools = list_states()
    if not spools:
        print("transcript: no active spools")
        return 0
    for d in spools:
        print(f"{d.get('status', '?'):8}  {d.get('mode', '?'):13}  "
              f"{d.get('out_md')}")
        print(f"          source: {d.get('session_jsonl')}")
        if d.get("out_jsonl"):
            print(f"          jsonl:  {d.get('out_jsonl')}")
        print(f"          since:  {d.get('started_at')}  "
              f"updated: {d.get('updated_at')}")
    return 0


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(prog="transcript")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p_start = sub.add_parser("start")
    p_start.add_argument("out", help="output markdown path")
    p_start.add_argument("--mode", choices=("full", "conversation", "context-only"),
                         default="full")
    p_start.add_argument("--session", help="path to session JSONL (auto-detect if omitted)")
    p_start.set_defaults(func=cmd_start)

    for name, fn in [("pause", cmd_pause), ("resume", cmd_resume),
                     ("stop", cmd_stop), ("append", cmd_append)]:
        p = sub.add_parser(name)
        p.add_argument("out", nargs="?", help="output markdown path (optional if only one active spool)")
        if name == "resume":
            p.add_argument("--session", help="override stored session JSONL")
        p.set_defaults(func=fn)

    p_status = sub.add_parser("status")
    p_status.set_defaults(func=cmd_status)

    args = ap.parse_args(argv[1:])
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
