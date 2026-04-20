# /add-skill — Author a new skill from conversation context

Draft a new skill from recent conversation, present for review, and deploy to
the chezmoi source on explicit confirmation. Defaults to `--create-draft`
rather than inline-review-and-deploy because skills auto-fire across all
future sessions based on trigger-description matching — a badly-scoped skill
can hijack unrelated conversations or inject wrong conventions silently for
weeks before detection. **Skills are the highest-blast-radius config object.**

Arguments: $ARGUMENTS

## Argument shapes

- `/add-skill <name> --trigger="<description>"` — minimum. `--trigger` is
  required; it anchors the skill's auto-invocation logic.
- `/add-skill <name> --trigger="<desc>" --global` — default; writes to
  `~/.local/share/chezmoi/home/dot_claude/skills/<name>/SKILL.md`, then
  `chezmoi apply`.
- `/add-skill <name> --trigger="<desc>" --local` — writes to
  `<project-root>/.claude/skills/<name>/SKILL.md`; no chezmoi.
- `/add-skill <name> --trigger="<desc>" --focus="<hint>"` — natural-language
  pointer to the relevant part of the conversation.
- `/add-skill <name> --trigger="<desc>" --from-file=<path>` — use the file's
  contents as the context source. Overrides `--focus`.
- `/add-skill <name> --trigger="<desc>" --create-draft[=<path>]` — **default
  behavior.** Writes the proposal to `<path>` (or
  `/tmp/claude-drafts/<name>-<timestamp>.md`) and stops. User edits, then
  re-invokes with `--from-draft=<path>` plus `--deploy`.
- `/add-skill <name> --trigger="<desc>" --from-draft=<path> --deploy` —
  skip drafting; load the file as final content, confirm with the user,
  deploy.
- `/add-skill <name> --trigger="<desc>" --deploy` — force inline-review-and-
  deploy instead of the default draft-file flow. Use only when confident.

Mutually exclusive groups:
- `--global` vs. `--local`
- `--from-file` vs. `--focus` (file overrides)
- `--from-draft` vs. `--create-draft`, `--focus`, `--from-file`
- `--deploy` and `--create-draft` modify the review flow, not the draft
  source — they can combine with `--focus`, `--from-file`, or `--from-draft`.

## Instructions

1. **Require a name and a trigger.** If `$ARGUMENTS` is missing either:
   ```
   /add-skill: missing required argument
   usage: /add-skill <name> --trigger="<description>"
                     [--global|--local] [--focus="<hint>"]
                     [--from-file=<path>] [--create-draft[=<path>]]
                     [--from-draft=<path>] [--deploy]
   ```
   The `--trigger` requirement is non-negotiable. A skill without an
   explicit trigger is a skill that will fire at the wrong time.

   Strip a leading `/` or `-` from the name if present. Reject names
   containing `/`, `..`, or whitespace. Skill names become directory names —
   convention is lowercase-with-hyphens.

2. **Parse flags.** Reject unknown flags. Enforce mutual-exclusion rules
   above. If `--deploy` is set, remember to bypass the default draft-file
   flow in step 6.

3. **Determine destination.**
   - Global source:
     `~/.local/share/chezmoi/home/dot_claude/skills/<name>/SKILL.md`.
     Live after `chezmoi apply`: `~/.claude/skills/<name>/SKILL.md`.
   - Local: `<project-root>/.claude/skills/<name>/SKILL.md`. Create
     `.claude/skills/<name>/` if missing. If the current directory doesn't
     look like a project root (no `.git`, no `CLAUDE.md`, no `.claude/`),
     **ask before creating.**
   - If a file exists at the destination, **halt and suggest `/edit-skill`
     instead.** Never overwrite.

4. **Survey existing skills for trigger overlap.** List the current skill
   corpus (global: `~/.claude/skills/*/SKILL.md`, plus local if relevant)
   and scan their `description` fields for overlap with the proposed
   `--trigger`. Two failure modes matter:
   - **Overlap** — two skills that would both fire on the same trigger
     words. The user must decide which takes precedence or merge them.
   - **Contradiction** — a new skill that directly contradicts an existing
     one (different conventions for the same domain).

   Report findings. If overlap is high, **halt and ask** — this is exactly
   the drift scenario that motivates skills' draft-default safety.

5. **Summarize intent.** *Mandatory — never skip.* State in one or two
   sentences:
   - What the skill does in practice;
   - When it should auto-fire (restate the trigger in your own words);
   - What it should *not* fire on (the edges — skills are dangerous when
     they fire too broadly).

   Draw on `--focus` if provided, `--from-file` contents if provided, or
   recent conversation otherwise. Example:

   ```
   Skill: /foo — drafts ADF-formatted Snowflake query explainers for
   the BOLD Orange engagement.
   Fires on:    "explain this query", "what does this SP do", when user
                references a .sql file under snowflake_migrations/.
   Does NOT fire on: generic SQL questions outside the Snowflake corpus,
                or non-BOLD engagements.
   Confirm or redirect?
   ```

   Ask the user to confirm. If the user says "fires on anything
   SQL-related," that is the vague-signal red flag — push back, do not
   draft.

6. **Draft the content.** On confirmation, produce the SKILL.md with:
   - YAML frontmatter containing `name` and `description`. The
     `description` is where the trigger goes — phrase it so it reads as
     both a skill summary *and* an auto-invocation cue. Follow the
     convention seen in existing skills: `"<short summary>. TRIGGER when
     <specific situations>. <Key invariants, references, or canonical
     exemplars>."`
   - Body in markdown: what the skill codifies, must-know rules, related
     references, canonical exemplars, when to invoke autonomously.

   Models to follow: `~/.claude/skills/jira-conventions/SKILL.md`,
   `~/.claude/skills/time-tracking/SKILL.md`,
   `~/.claude/skills/python-scripting/SKILL.md`.

   **If the signal is weak, halt and ask** — do not invent. A vague
   `--focus="the important bit"` is not enough. An unfocused conversation
   is not enough. For skills specifically, a vague `--trigger` is also
   disqualifying — `--trigger="when working with code"` is too broad to
   ship. Halt, explain the problem, invite the user to narrow it.

7. **Present for review.**
   - **Default (no `--deploy`):** write the proposed content to
     `--create-draft=<path>` (or `/tmp/claude-drafts/skill-<name>-<timestamp>.md`
     if no path given). Print the path, explain that the draft-file flow
     is the skill default because of blast radius, and stop. Tell the user
     to review, edit if needed, then re-invoke with
     `--from-draft=<path> --deploy`.
   - **`--deploy` (or `--from-draft` + `--deploy`):** print the full
     proposed content inline and ask
     `Deploy this skill? (yes / edits / cancel)`.

8. **On confirm + deploy.**
   - Create the destination directory if needed.
   - Write final content to `<destination>/SKILL.md`.
   - `--global`: run `chezmoi apply` via Bash; surface any errors verbatim.
   - Print:
     ```
     Wrote:   <destination source path>
     Live at: <live path>             (global only, after chezmoi apply)
     Commit:  pending in chezmoi repo (global only)
     Trigger: <one-line trigger summary>
     ```
   - Remind the user to commit chezmoi when ready. **Never commit.**

9. **On cancel.** Discard the proposal. No writes. If `--create-draft` was
   in play, leave the draft file — the user asked for it.

## Invariants

- **`--trigger` is required.** No skill ships without an explicit trigger.
- **Default is draft-file, not deploy.** Skills auto-fire; silent bad skills
  are the worst failure mode in this family. The `--deploy` flag exists for
  confident authors, not as a default.
- **Never overwrite an existing skill.** `/edit-skill` is the explicit path.
- **Never commit.** Chezmoi repo hygiene is the user's call.
- **Never skip the intent-summary step.** For skills it is doubly cheap and
  doubly valuable — the trigger articulation is the whole point.
- **Halt rather than draft on vague signal.** A `--trigger` like
  "when working with code" or "when the user mentions files" is
  disqualifying. Push back, invite narrowing, do not ship.
- **Flag overlap with existing skills.** Two skills firing on the same
  triggers is a collision the user must resolve before shipping.

## Related

- `/edit-skill <name>` — modify an existing skill.
- `/remove-skill <name>` — delete with echo-to-confirm friction.
- `/add-command`, `/add-agent` — same shape for other config object kinds.
- `/resolve <name>` — locate the live source of a skill, flag shadowing.
- `/audit --skill <name>` *(future)* — behavioral audit of an existing
  skill's trigger, overlap, and potential over-firing.
