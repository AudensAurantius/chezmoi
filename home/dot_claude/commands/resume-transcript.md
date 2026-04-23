---
name: resume-transcript
description: Resume a paused transcript spool — catch up any records since pause and mark it active again
argument-hint: "[<out.md>]"
author: Michael Haynes
scope: global
tags: [transcript, session, logging]
timestamps:
  - action: created
    at: 2026-04-23T00:00:00-05:00
    actor: Claude Opus 4.7
comments:
  - "If the current Claude Code session is different from the one that owned the spool at /pause-transcript time, the backend re-detects the current session's JSONL and updates state accordingly."
  - "context-only spools are not resumable — they leave no backend state. /start-transcript <path> --context-only must be re-run each time."
related: [/start-transcript, /pause-transcript, /stop-transcript]
---

# /resume-transcript — Resume a paused transcript spool

Append any turns recorded since the last pause and mark the spool active. If this session differs from the one that started the spool, the backend switches to tracking the current session's JSONL.

Arguments: $ARGUMENTS (optional out-path; optional `--session <jsonl>`)

## Instructions

1. **Parse args.** First non-flag token is the out-path (optional). `--session <jsonl>` is an explicit override for the session JSONL (rarely needed; the backend auto-detects).

2. **Invoke the backend:**

   ```
   ~/.claude/scripts/transcript.py resume [<out.md>] [--session <jsonl>]
   ```

   Surface stdout/stderr verbatim.

3. **If the backend reports "session changed":** that's informational — the spool is now tracking the new session's JSONL. Acknowledge the switch in your response so the user knows the cross-session hop happened.

4. **On "no active spools":** if nothing to resume, suggest `/start-transcript <out.md> [--mode]` instead of guessing.

## Related

- `/start-transcript` — begin a new spool.
- `/pause-transcript` — pause an active spool.
- `/stop-transcript` — final catch-up + remove state.
