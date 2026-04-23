---
name: start-transcript
description: Begin spooling the current conversation to a file — rendered Markdown + optional verbatim JSONL sibling
argument-hint: "<out.md> [--full | --conversation | --context-only]"
author: Michael Haynes
scope: global
tags: [transcript, session, logging]
timestamps:
  - action: created
    at: 2026-04-23T00:00:00-05:00
    actor: Claude Opus 4.7
comments:
  - "Source: 2026-04-22 auto-session design session. Snapshotting the design discussion to `.transcripts/` revealed the need for a reusable spool primitive."
  - "Backend: ~/.claude/scripts/transcript.py (state in ~/.claude/state/transcripts/); rendering: ~/.claude/scripts/render-jsonl.py --mode {full|conversation}."
  - "Three fidelity modes: `--full` = exact replay with summarised tool calls + byte-verbatim .jsonl sibling; `--conversation` = user prompts + assistant text only, no tool-use or thinking, Markdown-readable; `--context-only` = what Claude remembers in-context (no JSONL reach-back)."
  - "Companion commands: /pause-transcript, /resume-transcript, /stop-transcript. Pause and Stop differ only in whether state is retained."
related: [/pause-transcript, /resume-transcript, /stop-transcript]
---

# /start-transcript — Begin spooling this conversation

Start a transcript spool. The output path is mandatory. Fidelity mode is one of `--full` (default), `--conversation`, or `--context-only`.

Arguments: $ARGUMENTS

## Instructions

1. **Require an out-path.** Parse `$ARGUMENTS`. The first non-flag token is the output Markdown path; treat `.md` suffix as idiomatic but don't force it. If no path is given, print:

   ```
   /start-transcript: missing output path
   usage: /start-transcript <out.md> [--full | --conversation | --context-only]
     e.g. /start-transcript ~/notes/2026-04-23-session.md --conversation
   ```

   and stop.

2. **Parse the mode flag.** Exactly one of `--full`, `--conversation`, `--context-only` may appear. Default to `--full` when none given. If more than one, error:

   ```
   /start-transcript: pick one mode flag (--full, --conversation, --context-only)
   ```

   Mode semantics:
   - `--full` — exact-replay rendering (tool calls, tool results summarised; `thinking` blocks omitted). Also drops a **byte-verbatim `.jsonl` sibling** next to the Markdown, so fidelity-critical consumers can diff against ground truth.
   - `--conversation` — Markdown-formatted, user prompts + final assistant text only; intermediate tool-use turns, tool results, and thinking are omitted entirely. Use when the goal is readable review rather than audit.
   - `--context-only` — render from Claude's current in-memory context. No JSONL reach-back. Lossy, inexact (prior turns may paraphrase); no `.jsonl` sibling; no state registered with the backend. One-shot; not resumable via `/resume-transcript`.

3. **For `--full` and `--conversation`:** invoke the backend. Use a Bash call:

   ```
   ~/.claude/scripts/transcript.py start <out.md> --mode <full|conversation>
   ```

   Surface its stdout/stderr verbatim. Typical output on success:
   ```
   transcript: started [full] /path/to/out.md
     verbatim JSONL copy: /path/to/out.jsonl
     source session:      /home/hactar/.claude/projects/-…/<session-id>.jsonl
   ```

   If the backend reports *"spool already registered"*, tell the user and suggest `/stop-transcript <out>` then retry.

4. **For `--context-only`:** do **not** call the backend. Instead, render the conversation-so-far from your own context buffer directly into the file:
   - Use Markdown headings `## You` / `## Claude` per turn pair.
   - Include every user message verbatim as far as it survives in your context.
   - For assistant turns, include only your user-facing prose — skip any tool-use narration.
   - Add a preamble warning: *"Rendered from Claude's in-memory context only. Fidelity is best-effort; prior turns may have been paraphrased or compacted. The authoritative record is the session JSONL at `~/.claude/projects/<slug>/<id>.jsonl` — use `/start-transcript <out> --full` instead for ground truth."*
   - Do **not** claim byte fidelity. Do **not** invent content you don't have.
   - After writing, print: `transcript: wrote context-only transcript to <path> (not resumable — re-run /start-transcript to refresh)`.

5. **Success reporting.** On completion, one line summary: what mode, what path, and (for non-context-only) that `/pause-transcript`, `/resume-transcript`, and `/stop-transcript` will find this spool automatically if no out-path is given.

## Invariants

- **Never silently overwrite an existing active spool.** The backend errors if one already registered; surface that error and let the user decide.
- **Never pretend context-only is byte-exact.** Be explicit about the fidelity downgrade when the user chose that mode.
- **Do not run the backend for context-only mode.** The backend has no context-only code path on purpose; it would be a no-op state entry with no source of truth.

## Related

- `/pause-transcript` — catch up + mark paused (state retained for /resume).
- `/resume-transcript` — catch up + mark active.
- `/stop-transcript` — final catch up + remove state (alias of pause + rm).
- `~/.claude/scripts/transcript.py status` — list all active/paused spools.
