---
name: stop-transcript
description: Finalize an active transcript spool — catch up to the current turn and remove its state
argument-hint: "[<out.md>]"
author: Michael Haynes
scope: global
tags: [transcript, session, logging]
timestamps:
  - action: created
    at: 2026-04-23T00:00:00-05:00
    actor: Claude Opus 4.7
comments:
  - "Differs from /pause-transcript only in whether state is removed. /pause keeps state so /resume can continue; /stop removes state and the spool must be restarted with /start-transcript."
  - "The rendered Markdown and verbatim JSONL files are untouched — only the backend's state JSON is removed."
related: [/start-transcript, /pause-transcript, /resume-transcript]
---

# /stop-transcript — Finalize a transcript spool

Catch the transcript up to the latest turn, then remove the backend's state entry for it. The rendered files stay in place; only the spool registration is dropped. Resumption requires `/start-transcript` (not `/resume-transcript`).

Arguments: $ARGUMENTS (optional out-path)

## Instructions

1. **Parse optional out-path.** First non-flag token in `$ARGUMENTS`, if present. Empty args → backend auto-selects if exactly one spool is active.

2. **Invoke the backend:**

   ```
   ~/.claude/scripts/transcript.py stop [<out.md>]
   ```

   Surface stdout/stderr verbatim. On success the backend prints the final path.

3. **On "multiple active spools":** relay the list and ask the user to specify which to stop. Do not guess.

4. **After stop:** acknowledge the rendered files are still on disk (backend does not delete them) so the user knows nothing was lost.

## Related

- `/start-transcript` — begin a new spool.
- `/pause-transcript` — pause without removing state.
- `/resume-transcript` — resume a paused spool.
