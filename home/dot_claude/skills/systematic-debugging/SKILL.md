---
name: systematic-debugging
description: Four-phase methodology for debugging bugs, test failures, and unexpected behavior. Investigate root cause before proposing any fix; escalate to architectural discussion after 3+ failed fix attempts. Use for any non-trivial bug, especially under time pressure.
author: Michael Haynes
scope: global
tags: [debugging, methodology, escalation]
timestamps:
  - action: created
    at: 2026-04-20T01:20:51-05:00
    actor: Michael Haynes
comments:
  - "Source: methodology refined from repeated J121 debugging sessions (SQL injection characterization, CSP nonce investigation, Terraform privilege-gap analysis). Common pattern: premature fix attempts before understanding root cause wasted hours."
  - "Motivation: under time pressure, Claude (and humans) default to 'try the obvious fix' without first understanding *why* the bug exists. This skill enforces the investigate-first discipline and adds an escalation gate after 3 failed fix attempts to surface architectural misunderstanding earlier."
  - "Projected use: fires on any non-trivial bug report, failing test, or unexpected behavior. Not for typos, off-by-one, or other 'look at the diff' bugs — the methodology is overkill there."
---

# Systematic Debugging

Random fixes waste time and create new bugs. Quick patches mask underlying issues.

**Core principle:** Find the root cause before attempting a fix. A symptom fix is a failure, not a shortcut.

## The Iron Law

```
NO FIXES WITHOUT ROOT-CAUSE INVESTIGATION FIRST
```

If Phase 1 isn't complete, no fix can be proposed — not even a "quick one to see if it works."

## When to use

Any technical issue: test failures, production bugs, unexpected behavior, performance regressions, build failures, integration issues. **Especially** when:

- Under time pressure (emergencies make guessing tempting)
- A "just one quick fix" feels obvious
- Multiple fixes have already been tried
- The previous fix didn't work
- The issue isn't fully understood

Don't skip for "simple" issues — simple bugs have root causes too, and the process is fast when the root cause is shallow. Rushing guarantees rework.

## The four phases

Complete each phase before advancing. Skipping a phase means returning to it later, with more context lost.

### Phase 1 — Root-cause investigation

1. **Read error messages and stack traces completely.** Line numbers, file paths, error codes, exit statuses. They often contain the exact answer.
2. **Reproduce consistently.** Can the issue be triggered reliably? What are the exact steps? If it's not reproducible, gather more data — don't guess.
3. **Check recent changes.** `git log`, `git diff` against last-known-good, recent dependency bumps, config changes, environmental differences. Who / what / when.
4. **For multi-component systems, instrument diagnostic logging at each boundary.** Before proposing fixes, add logging that answers *which component is failing*:
   ```
   For each component boundary:
     - What data enters the component?
     - What data exits?
     - Is env/config propagating correctly?
     - What's the state at each layer?
   ```
   Run once to gather evidence. Analyze evidence to identify the failing component. Investigate *that* component. Example: CI → build → signing → publish chain — log secret presence at layer 1, env vars at layer 2, keychain state at layer 3, exit codes at layer 4. Reveals which boundary breaks.
5. **Trace data flow backward.** When the error is deep in a call stack, ask: where does the bad value originate? What called this with a bad value? Walk up until the source appears. Fix at the source, not the symptom.

### Phase 2 — Pattern analysis

1. **Find working examples.** Where in the same codebase does a similar pattern work? What's the difference between that and what's broken?
2. **Compare against references completely.** If following a pattern or reference implementation, read every line. Skimming guarantees missing details.
3. **List every difference, however small.** Don't pre-dismiss "that can't matter" — often it does.
4. **Map dependencies and assumptions.** What other components does the broken code need? What settings, env, config? What does it assume about state, ordering, types?

### Phase 3 — Hypothesis and testing

1. **State a single specific hypothesis.** "I think X is the root cause because Y." Be specific, not vague. Write it down.
2. **Test minimally.** The smallest possible change that would confirm or refute the hypothesis. One variable at a time. Never combine multiple fixes.
3. **Verify before continuing.** Did it work? → Phase 4. Didn't work? → new hypothesis. Do not layer more fixes on top.
4. **When the cause isn't known, say so.** "I don't understand X" is honest and productive. Pretending to know leads to fix-stacking.

### Phase 4 — Implementation

1. **Create a failing test first.** Simplest reproducible case; automated if the framework allows, one-off script otherwise. The fix can only be verified against a test that fails without it.
2. **One targeted fix.** Address the root cause identified in Phase 3. No "while I'm here" improvements. No bundled refactoring.
3. **Verify the fix.** Does the failing test pass now? Did any other tests break? Is the original issue actually resolved (re-run the original reproduction)?
4. **If the fix doesn't work, stop and count.**
   - If fewer than 3 fixes attempted: return to Phase 1 with the new information.
   - If 3 or more fixes attempted: **do not attempt fix #4.** Escalate to architectural review.

### The 3-fix escalation rule

When three attempted fixes have failed, the pattern usually indicates an architectural problem, not a series of failed hypotheses:

- Each fix reveals a new shared-state / coupling / invariant problem in a different place
- Fixes require "massive refactoring" to implement cleanly
- Each fix creates new symptoms elsewhere

Stop and question fundamentals: is this pattern sound, or is it being kept through inertia? Should the architecture be refactored rather than the symptom patched? **Discuss with the user before attempting more fixes.** This is a wrong-architecture signal, not a failed-hypothesis signal.

## Red flags

If any of these thoughts appear, stop and return to Phase 1:

- "Quick fix for now, investigate later."
- "Just try changing X and see if it works."
- "Let me make these few changes together and run the tests."
- "Skip the test — I'll verify manually."
- "It's probably X, let me fix that."
- "I don't fully understand it but this might work."
- "The pattern says X but I'll adapt it differently."
- Proposing solutions before tracing data flow.
- "One more fix attempt." (when 2+ have already failed)

## Signals from the user that the process is off

Watch for redirections like:
- *"Is that actually happening?"* — assumption without verification.
- *"Will the logs / output show us...?"* — missing evidence-gathering step.
- *"Stop guessing."* — fixes being proposed without understanding.
- *"Think harder about this."* — symptom-level thinking; need to question fundamentals.
- *"We're stuck?"* — the current approach isn't working; return to Phase 1.

Any of these mean: stop, acknowledge, restart at Phase 1.

## Common rationalizations

| Excuse | Reality |
|--------|---------|
| "Issue is simple, don't need process." | Simple bugs have root causes too. Process is fast when they're shallow. |
| "Emergency, no time for process." | Systematic debugging is faster than guess-and-check thrashing. |
| "Just try this first, investigate if it fails." | The first approach sets the pattern. Do it right from the start. |
| "I'll write a test after confirming the fix works." | Untested fixes don't stick. Test first proves the fix; test-last proves nothing. |
| "Multiple fixes at once saves time." | Can't isolate what worked. Creates new bugs. |
| "Reference is long; I'll adapt the pattern." | Partial understanding guarantees bugs. Read it completely. |
| "I see the problem, let me fix it." | Seeing symptoms ≠ understanding root cause. |
| "One more fix attempt." (after 2+ failures) | 3+ failures = architectural problem. Escalate instead. |

## When investigation reveals no root cause

Occasionally an issue is genuinely environmental, timing-dependent, or external. When systematic investigation confirms this:

1. Document what was investigated.
2. Implement appropriate handling: retry with backoff, explicit timeout, clear error message, alerting.
3. Add monitoring or logging to catch the next occurrence.

**Caveat:** 95% of "no root cause" cases are incomplete investigation. Recheck Phase 1 before concluding.

## Quick reference

| Phase | Activities | Done when |
|-------|-----------|-----------|
| **1. Root cause** | Read errors, reproduce, check changes, instrument boundaries, trace data flow backward | The *what* and *why* are understood |
| **2. Pattern** | Find working analogs, compare, list differences, map dependencies | The delta between working and broken is explicit |
| **3. Hypothesis** | State one specific hypothesis, test minimally | Hypothesis confirmed or replaced |
| **4. Implementation** | Write failing test, apply one fix, verify | Test passes, no regressions, reproduction no longer reproduces |

## Related

- The "Verification Before Claiming Completion" section in global CLAUDE.md — Phase 4's "verify the fix" is its most common trigger.
- `bd remember` / project-technical pitfalls — check these before Phase 1 for known environmental quirks relevant to the current codebase.
