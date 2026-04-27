---
name: tutor
description: Interactive technical primer on any topic — structured overview, trade-offs, examples, and follow-up paths; accepts optional reference materials
argument-hint: "[<topic description>] [--reference <url-or-path-or-citation>]... [--save <path>]"
author: Michael Haynes
scope: global
tags: [learning, tutorial, documentation, exploration]
timestamps:
  - action: created
    at: "2026-04-23T00:00:00-05:00"
    actor: Michael Haynes
  - action: modified
    at: "2026-04-27T00:00:00-05:00"
    actor: Michael Haynes
    note: "Added --save/--file/--transcript flag for writing primer output to a file"
comments:
  - "Source: redo build system primer session (2026-04-22); the five-section
    structure (overview / trade-offs / API / examples / follow-ups) produced a
    dense, reusable reference in one pass. Command name reserved in J121-014
    planning (2026-04-20); created here for immediate use."
  - "Motivation: recurring need to get oriented on an unfamiliar tool, system,
    or paper quickly — with enough depth to evaluate it and enough concreteness
    to try it. The --reference flag extends this to 'explain and discuss this
    paper/doc for me' without a separate command."
  - "Projected use: invoke before picking up any unfamiliar technology, library,
    build system, protocol, or CS concept. Pass --reference to anchor the
    session to specific papers, docs, or URLs rather than general knowledge."
related: [session-checkpoint]
---

# /tutor — Interactive technical primer on any topic

## Step 0 — Parse arguments

Extract from `$ARGUMENTS`:

- **Topic**: all text that is not a `--reference` or `--save`/`--file`/`--transcript` flag and its value. May be
  empty if only `--reference` flags are present.
- **References**: each `--reference <value>` where `<value>` is a URL, a local
  file path, or a plain citation string (author / title / year). Collect all
  of them; the flag may appear multiple times.
- **Save path**: `--save <path>`, `--file <path>`, or `--transcript <path>` (all three are synonyms). If present, the primer output will be written to this file after Step 3. At most one save path may be specified.

**Reference resolution** (do this before Step 1):
- URL → fetch with WebFetch and read the content.
- Local path → read with the Read tool.
- Plain citation → work from training knowledge; note explicitly when doing so
  and flag any uncertainty about the specific version or edition.

**References-only mode**: if the topic is empty after extraction, treat the
command as a request to condense, summarize, and explain the reference(s), then
invite further discussion. Skip Step 1's clarification questions about scope;
instead open with a brief statement of what the reference(s) cover and ask if
there is a particular angle or question to focus on.

## Step 1 — Scope check

Before producing any output, assess whether the topic needs scoping:

- **Clear and specific** (e.g. "the redo build system", "CRDT data structures",
  "POSIX select(2)", or a supplied reference with a narrow focus): proceed
  directly to Step 2.
- **Broad or ambiguous** (e.g. "distributed systems", "functional programming",
  "build tools"): ask 2–4 targeted clarifying questions before continuing.

**If references were supplied**, also check:
- Do the references match the stated topic? If there is a clear mismatch (e.g.
  topic is "TLS handshake" but the reference is a paper on database indexing),
  name the mismatch explicitly and ask the user to confirm intent before
  proceeding.

Clarifying questions to draw from as needed (ask only those that would
materially change the output):
1. Which aspect should anchor the primer? (theory / practical usage / comparison
   with a specific alternative / implementation internals)
2. What level of prior knowledge should be assumed? (novice / practitioner in
   adjacent areas / expert in related tools)
3. Is there a language preference for worked examples? (default: the most
   natural language for the topic)
4. Is there a particular use-case or constraint that motivated the question?
   (e.g. "I'm evaluating this for a project that currently uses X")

## Step 2 — Produce the primer

Generate Sections 1–4 in order. Do not truncate or abbreviate any section.
Section 5 (minimal implementation) is **omitted by default** — include it only
if the user explicitly asks for it (e.g. "include an implementation" or
"show me how to build a toy version").

When references were supplied, draw on their specific content, terminology, and
examples throughout. Prefer citing the reference over paraphrasing general
knowledge where the two differ.

### Section 1: Conceptual Overview

- What is it? What problem does it solve, and for whom?
- What is the **key insight** or design decision that makes it distinctive?
  State this as precisely as possible — this is the sentence the reader should
  walk away remembering.
- Brief history / provenance if relevant (who built it, why, what came before).
- 3–4 paragraphs maximum. Dense and precise over broad and padded.

### Section 2: Use-Cases and Trade-Offs

- When should you reach for this? What is it genuinely better at than the
  obvious alternatives?
- When should you not use it? What are the real costs — not generic "small
  ecosystem" boilerplate but the specific failure modes that matter here.
- A comparison table if there are 3+ meaningful alternatives. Columns should
  capture the dimensions that actually differentiate the options.

### Section 3: Design and API

- Core concepts / mental model: the 3–5 things you need to understand to use
  the system or read the work. Named precisely as the source names them.
- Key commands, functions, types, protocols, or theoretical constructs. For
  each: what it does, its signature or form, and any non-obvious behavior.
- Configuration, conventions, or environmental assumptions a new user will
  immediately encounter.
- Cover the 20% that handles 80% of usage — do not enumerate every option.

### Section 4: Worked Examples

- 3–5 examples, ordered from minimal to non-trivial.
- Each example should be self-contained and runnable (or clearly structured
  when runtime is not applicable).
- At least one example should demonstrate a non-obvious capability or a case
  where this approach handles something that alternatives handle badly.
- Label each example with a one-line description of what it demonstrates.

### Section 5: Minimal Implementation (on request only)

A bare-bones implementation of the core of the system in a base language
(shell, Python, or the most natural choice for the domain). Goal: illuminate
*how* the design works, not produce production code. ~100–200 lines. Include a
brief note listing what a production implementation adds that this omits.

## Step 3 — Follow-up suggestions

After the main content, add a **Further Exploration** section with:

- 3–6 specific follow-up topics, questions, or angles worth investigating next.
  Make these concrete (not "learn more about X" but "how does X handle Y when Z
  is true?").
- Key references if appropriate: papers, books, canonical blog posts, or
  specification documents. Prefer primary sources. If references were supplied
  by the user, note related works cited within them.
- If the session revealed an open question or genuine uncertainty, name it
  explicitly rather than papering over it.

## Step 4 — Save output (only if --save/--file/--transcript was supplied)

If no save path was specified, skip this step entirely.

1. **Check whether the file exists** using the Bash tool: `test -f <path> && echo exists || echo new`.

2. **If the file does not exist**: write the primer output directly with the Write tool. Confirm in one line: `Saved to <path>`.

3. **If the file already exists**: do NOT write yet. Tell the user:
   > `<path>` already exists. Default: **append** the primer below the existing content. Alternatives: **overwrite** (replaces the file) or **skip** (don't save).
   >
   > Reply with `append`, `overwrite`, or `skip` — or just press Enter to append.

   Then wait for the user's reply before acting. On `append` (or empty/Enter): use Bash to append (`cat >> <path>`). On `overwrite`: use the Write tool. On `skip`: confirm skipped, do nothing.

4. **Content to write**: the primer only — Sections 1–4 (and Section 5 if it was produced), the Further Exploration section, and nothing else. Do not include the clarifying-question exchange, tool-use output, or this confirmation dialogue.

## Invariants

- Never skip Step 0 argument parsing. The references-only mode and
  reference-mismatch check both depend on it.
- Never skip the scope check in Step 1 for broad topics. A misfired primer on
  the wrong angle wastes more time than a short clarification exchange.
- Never include Section 5 unless the user explicitly requests it.
- If the topic is a moving target or knowledge-cutoff-sensitive, flag this
  explicitly at the top of the primer rather than presenting uncertain content
  as settled.
- When drawing on supplied references, prefer their specific content over
  general training knowledge where the two differ — and say so.
