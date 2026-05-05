---
name: spawn-agents
description: Pre-flight protocol for invoking the Agent tool. TRIGGER before any Agent tool call, especially when spawning multiple agents in parallel or agents whose tool needs span web fetches, web search, or domains/patterns not already in the project's allowlist. Predicts the tool set, pre-loads deferred-tool schemas, declares expected tools to the user for batch approval, and dispatches only after approval — minimizing in-flight blocking prompts that interrupt the user during agent execution.
author: Michael Haynes
scope: global
tags: [agents, permissions, workflow, friction-reduction]
---

# Spawn-agents pre-flight

Procedure for invoking the Agent tool such that all permission decisions
are surfaced upfront, before any agent runs, so the user can approve in
batch and step away during execution.

## When this applies

Before any `Agent` tool invocation, regardless of `subagent_type`,
parallelism, or model. The procedure is constant; the depth of the
prediction step varies with task complexity.

## Five-step pre-flight

### 1. Predict tool usage per agent

Enumerate the tools each spawned agent is likely to need, based on the
task description you'll give them. Be concrete:

- **`WebFetch`** — which domains? `github.com`? Specific tool docs sites?
  Unknown-set?
- **`WebSearch`** — yes/no?
- **`Bash`** — which command patterns? Read-only (e.g. `gh repo view *`)
  or potentially mutating (e.g. `git push`, `pip install`)?
- **`Read` / `Grep` / `Glob`** — local-filesystem only, usually safe.
- **MCP tools** — which ones, and are they read-style (search/list/get)
  or write-style?

For obviously-bounded tasks (e.g. an `Explore` agent reading a known
local path with `Read` and `Grep`), this step is trivial. For research
tasks fetching arbitrary external content, it's where most of the work
lives.

### 2. Pre-load deferred-tool schemas

For tools in the prediction that are deferred (e.g. `WebFetch`,
`WebSearch`, `Monitor`), call `ToolSearch(query="select:Tool1,Tool2,...")`
in the parent session to resolve their schemas. Doesn't help spawned
agents directly — they have their own deferred-tool state — but
eliminates a class of preflight round-trip in the parent.

### 3. Declare expected tool set to the user

Surface the prediction explicitly. Format example:

> "Agents will use: `WebFetch` (domains: github.com, e2b.dev,
> sigs.k8s.io), `WebSearch`, `Bash` (`gh repo view *`, `git clone:*`),
> `Read`, `Grep`. Approve as a batch?"

Wait for explicit approval before continuing. If the user proposes
broader allowlisting (adding to `~/.claude/settings.json` or the
project's `.claude/settings.json`), defer to them — they may want a
permanent policy instead of one-shot approval. The
`fewer-permission-prompts` skill is the right tool for permanent
allowlisting.

### 4. Escape clause: unpredictable tool usage

If the agents' tool needs aren't reasonably predictable from the task
description (e.g. fully open-ended exploration, "investigate X with no
methodology constraints"), state that:

> "Cannot reliably predict the agents' tool usage in advance. Blocking
> prompts may surface during execution. Confirm dispatch anyway?"

Wait for explicit confirmation. The user may choose to:

- **Accept the friction** (proceed)
- **Add `--dangerously-skip-permissions` for sandboxed agents** (Phase 1+
  endpoint — see [`SANDBOX_GUIDE.md`](../../docs/SANDBOX_GUIDE.md) in
  claude-config)
- **Narrow the task description** so prediction becomes feasible

### 5. Dispatch

Once batch approval is received, invoke the Agent tool. Use parallel
dispatch (single message with multiple Agent tool uses) when agents are
independent.

## Long-term: when the sandbox subsumes prompts

Once Phase 1 of `claude-config` ships, agents running inside the bwrap
sandbox can be invoked with `--dangerously-skip-permissions` because the
OS-level isolation is the actual trust boundary. At that point this
procedure relaxes — sandboxed dispatch doesn't need batch-approval-up-front
because the sandbox enforces what the prompts checked. See
`~/Source/claude-config/docs/SANDBOX_GUIDE.md` (section "Permission
prompts vs OS-level sandboxing") for the composition principle.

## What this procedure does NOT do

- Doesn't add tools to the global/project allowlist automatically. That's
  the `fewer-permission-prompts` skill's job, and the user's decision per
  pattern.
- Doesn't override the user's permission_mode (default vs. auto vs.
  bypassPermissions). Those are session-level levers; this is procedural.
- Doesn't apply to direct tool invocations from the parent session (only
  to agents spawned via the `Agent` tool).
