---
name: alert-timer
description: Timer loop with conditional out-of-session notifications via wsl-notify-send or ntfy.sh — extends /reminder for when the user may have stepped away
argument-hint: "[<cadence>] [<message>] [--start=<time>] [--stop-at=<time>] [--stop-when=<cond>]... [--action=<prompt>] [--result=<spec>] [--alert-when=<cond>]... [--alert-message=<text>] [--backend=wsl|ntfy|<path>] [--topic=<ntfy-topic>] [--once]"
author: Michael Haynes
scope: global
tags: [notifications, timer, loop, wsl, ntfy, monitoring]
timestamps:
  - action: created
    at: "2026-04-23T00:00:00-05:00"
    actor: Michael Haynes
comments:
  - "Source: alert-command-spec.md (~/Documents/personal/claude/) + clarification session 2026-04-23.
    Generalizes the M365 watch-loop pattern (ScheduleWakeup + conditional notification) into a
    reusable command."
  - "Motivation: /reminder covers 'user is watching the terminal'; /alert-timer covers 'user is
    in a different window' (wsl-notify-send toast) and 'user stepped away' (ntfy.sh push to phone).
    Also supports loop-action-based conditional alerting (check X, alert if Y)."
  - "Projected use: 'alert me when the build finishes', 'every 15m check the queue depth and notify
    me if > 100', 'remind me at 5pm via phone'. Simple time+message requests that look like /reminder
    should go through the gate in Step 2."
related: [reminder, loop]
---

# /alert-timer — Timer loop with out-of-session notifications

## Step 0 — Detect mode

If `$ARGUMENTS` contains `--_iter=<N>`, this is a loop wake-up. Skip to **Step 5 — Iterate**.
Otherwise this is a fresh invocation; proceed with Steps 1–4.

## Step 1 — Parse arguments

Extract from `$ARGUMENTS`:

| Flag | Aliases | Notes |
|---|---|---|
| positional arg 1 | `--cadence=<time>`, `Cadence(<time>)` | Required unless `--once` with no cadence makes sense as one-shot |
| positional arg 2 | `--alert-message=<text>`, `Message(<text>)` | Optional fixed notification body |
| `--start=<time>` | `Start(<time>)` | When to begin; natural-language or datetime string; default: now |
| `--stop-at=<time>` | `StopAt(<time>)` | Hard cutoff; supercedes all other stop logic when reached |
| `--stop-when=<cond>` | `StopWhen(<cond>)` | State condition checked at iteration start; may be specified multiple times (OR semantics) |
| `--action=<prompt>` | `Action(<prompt>)` | What Claude does each iteration; optional |
| `--result=<spec>` | `Result(<spec>)` | How to extract a scalar from the action output for use in alert conditions |
| `--alert-when=<cond>` | `AlertWhen(<cond>)` | Condition that triggers the notification; multiple = OR; omit for "always alert" |
| `--alert-message=<text>` | | Fixed notification body; if absent, Claude composes from iteration context |
| `--backend=<id>` | | `wsl`, `ntfy`, or an absolute path to an executable |
| `--topic=<topic>` | | ntfy.sh topic name; required when backend is `ntfy` |
| `--once` / `--onetime` | | Stop the loop after the first alert fires |

Reject unknown flags. `--stop-when` and `--alert-when` may appear multiple times.

After parsing, record the resolved cadence in seconds as `cadence_seconds` for use in
ScheduleWakeup calls.

## Step 2 — Simple reminder gate

If **all** of the following are true, this looks like a `/reminder` call with a backend override:
- No `--action`
- No `--stop-when`
- No `--alert-when`
- A cadence and/or message is all that was provided

Ask:
> This looks like a straightforward timer. Will you be watching this Claude session while
> the timer runs, or might you step away?
>
> - **Watching** → `/reminder` is sufficient (Windows toast, no loop needed).
>   I'll translate this for you.
> - **Stepping away** → continue with `/alert-timer` to push via `<backend>`.

If the user confirms they'll be watching, invoke `/reminder` with the equivalent arguments
and stop. Do not proceed with the loop setup.

## Step 3 — Resolve backend

If `--backend` was not specified, infer:
- If the request mentions phone, mobile, push, or away → `ntfy`
- Otherwise → `wsl` (visible+audible toast; the same channel as `/reminder`)

If `ntfy` is selected (inferred or explicit) and `--topic` was not provided, ask for the topic
before continuing.

If a custom executable path was given, verify it is an absolute path. Note that its calling
convention will be confirmed in Step 4.

## Step 4 — Confirm notification shape

Compose a draft notification based on the parsed arguments and backend, then present it for
confirmation **before starting the loop**. Do not start any ScheduleWakeup until confirmed.

### Draft format by backend

**`wsl` (wsl-notify-send → BurntToast):**
```
Title:    <title>
Body:     <body>
Scenario: reminder   (or alarm if cadence-less one-shot)
Command:  wsl-notify-send -t "<title>" "<body>"
```

**`ntfy` (ntfy.sh HTTP push):**
```
Topic:    <topic>
Title:    <title>
Body:     <body>
Priority: default   (or urgent if --stop-at is imminent, low for low-cadence passive monitors)
Tags:     <1-2 emoji tags inferred from action/message context>
Command:  curl -s \
            -H "Title: <title>" \
            -H "Priority: <priority>" \
            -H "Tags: <tags>" \
            -d "<body>" \
            "https://ntfy.sh/<topic>"
```

**Custom executable:**
```
Path:     <path>
Called as: <path> "<title>" "<body>"
           (confirm calling convention with user if uncertain)
```

### Content when no `--action` and no `--alert-message`

Use these defaults and confirm them explicitly:
- Title: `Claude timer fired`
- Body: `<cadence> timer elapsed` (or `One-time timer elapsed` for one-shots)

### Confirmation prompt

Present the full draft and ask:
> Deploy this notification shape? (yes / edit title / edit body / change backend / cancel)

Accept freeform edits inline. Do not start the loop until the user confirms with "yes" or
equivalent.

On cancel: discard everything. No ScheduleWakeup is ever called.

## Step 4b — Schedule start (if `--start` was given)

Resolve `--start` to an absolute datetime. Compute `delay_seconds = start_time - now`.

Call ScheduleWakeup with:
- `delaySeconds`: `delay_seconds`
- `prompt`: the iteration prompt (see Step 5 format)
- `reason`: `alert-timer: first iteration at <start_time>`

Print:
```
Alert timer set. First iteration at <start_time> (<delay> from now).
Cadence: <cadence>  |  Stop: <stop_at or "manual">  |  Backend: <backend>
```
Then stop — the loop will begin at the scheduled time.

If no `--start`, proceed immediately to Step 5.

## Step 5 — Iterate

*This step runs on every ScheduleWakeup wake-up (and immediately after Step 4 when no `--start`).*

Reconstruct state from the `--_iter=<N>` argument and the other embedded `--_*` flags in the
wakeup prompt (see Step 6 for how these are encoded).

### 5a — Stop-at check

If `--stop-at` was specified and `now >= stop_at`:
- Print: `alert-timer: stop-at time reached — loop terminated.`
- Do **not** send a notification.
- Halt. Do not call ScheduleWakeup.

### 5b — Stop-when checks

For each `--stop-when=<condition>`:

1. **Shell exit-code form** (`condition` starts with `$(`  or looks like a shell command):
   Run the command via Bash. If exit code == 0 → condition is true.

2. **Structured comparison form** (`result > 80`, `result contains "ERROR"`, `exit_code == 0`):
   Evaluate symbolically against the most recent `result` value (null on first iteration before
   action runs). If undecidable (result not yet available), skip and continue.

3. **Natural-language form** (everything else):
   Evaluate using Claude's judgment against observable context (filesystem, prior action output,
   session state). If undecidable, skip and continue — do not halt on ambiguity.

If **any** stop-when condition is true:
- Print: `alert-timer: stop-when condition met ("<condition>") — loop terminated.`
- Do **not** send a notification (stop-when is a termination signal, not an alert trigger).
- Halt. Do not call ScheduleWakeup.

### 5c — Execute action (if `--action` was given)

Run the action prompt. Capture the full output as `action_output`.

If `--result=<spec>` was given, extract a scalar `result` from `action_output` per the spec.
The spec may be:
- A natural-language description: "the number on the last line"
- A regex: `result ~ /([0-9]+) errors/` → capture group 1
- A jq expression (if output is JSON): `.status`

If extraction fails, set `result = null` and note the failure in the iteration log line.

### 5d — Evaluate alert conditions

If no `--alert-when` flags were given → alert fires unconditionally.

Otherwise, evaluate each `--alert-when=<condition>` using the same three-form logic as 5b,
but against `result` (or `action_output` if no result spec). Alert fires if **any** condition
is true (OR semantics).

If all conditions are false or undecidable → no alert this iteration. Proceed to Step 6.

### 5e — Compose and dispatch notification

**Body:** If `--alert-message` was given, use it verbatim. Otherwise compose a one-sentence
summary of what triggered the alert (action result, condition that fired, iteration number).

**Title:** Use the confirmed title from Step 4.

Dispatch using the confirmed backend command, substituting the composed body.

Print a one-line iteration log:
```
[iter <N> | <timestamp>] alert fired → <backend>: "<title>" / "<body>"
```

If `--once` / `--onetime` was set:
- Print: `alert-timer: --once flag set — loop terminated after first alert.`
- Halt. Do not call ScheduleWakeup.

## Step 6 — Schedule next iteration

Call ScheduleWakeup:
- `delaySeconds`: `cadence_seconds` (respect the 60–3600s clamp; if cadence < 60s, clamp to 60
  and note this)
- `reason`: `alert-timer iter <N+1>: <one-phrase summary of what the loop is monitoring>`
- `prompt`: the full `/alert-timer` iteration prompt, encoding all state as flags:

```
/alert-timer --_iter=<N+1> \
  --_cadence_seconds=<N> \
  --_stop_at="<ISO-8601 or empty>" \
  --_stop_when="<cond1>" --_stop_when="<cond2>" \
  --_action="<prompt or empty>" \
  --_result="<spec or empty>" \
  --_alert_when="<cond1>" --_alert_when="<cond2>" \
  --_alert_message="<text or empty>" \
  --_backend="<wsl|ntfy|path>" \
  --_topic="<topic or empty>" \
  --_once=<true|false> \
  --_title="<confirmed title>" \
  --_priority="<ntfy priority or empty>" \
  --_tags="<ntfy tags or empty>"
```

Print a one-line iteration log:
```
[iter <N> | <timestamp>] no alert — next in <cadence> (<next_time>)
```

## Invariants

- Never call ScheduleWakeup before the user confirms the notification shape in Step 4.
- Never send a notification on a stop-at or stop-when termination — those are loop exits, not alerts.
- Never evaluate a stop-when or alert-when condition that depends on the action result before
  the action has run (skip + continue rather than halt on undecidable).
- Never start an implicit polling loop inside a stop-when or alert-when condition. If a condition
  requires continuous observation, ask the user to reformulate as a loop action.
- Always clamp ScheduleWakeup delaySeconds to [60, 3600]. If the user's cadence is outside this
  range, note the clamp explicitly at setup time.
- The `--_*` flags in iteration prompts are internal state; never surface them in user-visible
  output.
- When adding a new backend in the future: add its draft format to Step 4, its dispatch command
  to Step 5e, and document its calling convention in comments. No other steps need changing.
