---
name: pause-transcript
description: Catch up an active transcript spool to the current turn and mark it paused (state retained for /resume-transcript)
argument-hint: "[<out.md>]"
author: Michael Haynes
scope: global
tags: [transcript, session, logging]
timestamps:
  - action: created
    at: 2026-04-23T00:00:00-05:00
    actor: Claude Opus 4.7
comments:
  - "Paired with /start-transcript, /resume-transcript, /stop-transcript. Differs from /stop-transcript only in that state is retained, so /resume-transcript can continue without rerunning the initial setup."
  - "Argument optional: if exactly one spool is active, it's selected implicitly."
related: [/start-transcript, /resume-transcript, /stop-transcript]
---

# /pause-transcript — Pause an active transcript spool

Catch the transcript up to the latest turn and mark it paused. State is retained; use `/resume-transcript` to continue later.

Arguments: $ARGUMENTS (optional out-path)

## Instructions

1. **Parse optional out-path.** First non-flag token in `$ARGUMENTS`, if present, is the transcript output path. Empty args is fine — the backend auto-selects when exactly one spool is active.

2. **Invoke the backend:**

   ```
   ~/.claude/scripts/transcript.py pause [<out.md>]
   ```

   Surface stdout/stderr verbatim.

3. **On "no active spools":** report that clearly — do not attempt to re-derive a spool from conversation context.

4. **On "multiple active spools":** the backend prints the list; relay it and ask the user to specify which one.

5. **On success:** one-line confirmation, nothing more. State stays on disk; `/resume-transcript` will pick up cleanly.

## Related

- `/start-transcript <out.md> [--mode]` — begin a new spool.
- `/resume-transcript [<out.md>]` — resume a paused spool.
- `/stop-transcript [<out.md>]` — finalize and remove state.
