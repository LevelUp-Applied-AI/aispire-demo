# Orchestration Comparison

Two orchestration patterns evaluated side-by-side against the operational shape of `aispire`'s 19-agent stack.

## The honest framing

These approaches solve **adjacent problems**, not the same problem. Treating them as alternatives is the bias trap; treating them as layers is the productive frame.

| Layer | What it answers | Claude-native answer | Software Factory answer |
|---|---|---|---|
| Agent definition | What is this agent's role, scope, tool allowlist, model? | Subagent file at `.claude/agents/<name>.md` | Pack at `packs/<agent>/pack.toml` |
| Lifecycle / fail-closed | What guarantees the agent's output is valid before the parent proceeds? | `Stop` and `PostToolUse` hooks in `.claude/settings.json` | Hooks installed via `gc` plus formula exit criteria |
| Context loading | How does an agent get its rules and current state at session start? | `SessionStart` hook + path-scoped rules with glob frontmatter | `gc prime` hook plus manifest reads |
| Procedure invocation | How is a multi-step workflow expressed and discovered? | Skills (`.claude/skills/<name>/SKILL.md`), invoked as `/skill-name <args>` | Formulas (`*.formula.toml`) with declared steps, preconditions, exit criteria |
| Durable cross-session task state | Where does in-flight work live so a crash doesn't lose it? | **Not directly addressed.** Subagents return summaries to the parent; nothing persists. | Beads (`bd`) — Git-native task ledger with labels, dependencies, history |
| Background / always-on workers | How do agents react to events when no human is in session? | Not native. External cron required. | Orders (polling gates) + daemon (`patrol_interval`) |
| Multi-agent coordination | How do agents hand work to each other? | Subagent invocation from the parent (one-direction, summary back). No agent-to-agent. | Slings (`gc sling <rig>--<agent> <bead>`) routing work via labels |
| Org-wide context | How does behavior persist across machines and operators? | Versioned `.claude/settings.json` + `.claude/rules/` + repo CLAUDE.md | Versioned `city.toml` + packs + manifests |

## Where each is the right answer

### Claude-native primitives are right when

- The work is interactive or session-bounded; an operator is in the loop.
- The needed gate is at the lifecycle boundary (`SessionStart`, `PreToolUse`, `Stop`, etc.).
- The orchestration question is "how do I define this agent and verify its output," not "how do I track work across many runs."
- You don't want to install a separate orchestrator — you want primitives in the same repo as the rest of the project.
- Reproducibility matters more than runtime — config files in `.claude/` are versionable and reviewable.

### Software Factory primitives are right when

- The work spans many sessions; durability across crashes is required.
- An audit trail of all task transitions is operationally important.
- Multiple agents need to hand work to each other based on state, not direct invocation.
- A human is not always in session; agents need to wake on conditions.
- The same task ledger is useful across multiple repos or environments — beads' Git-native database makes the journal portable.

### Either works (pick on style)

- A single audit run that produces a structured report. Either subagents-with-Stop-hook or a Gas City formula handles this; pick the one that matches the surrounding stack.
- A short-lived script that runs once a week. Cron + the chosen orchestrator's smallest unit is fine in either system.

## The capability gap that matters most

The single most consequential gap, observed across the `aispire` stack: **subagents return summaries to the parent, not persistent queryable state.** A subagent run in session A is invisible to session B. If session A crashes mid-run, the parent's view is gone.

Beads (or any durable task ledger — including a hand-rolled `_state.json` per pipeline) closes this gap. The two layers are complementary:

- Subagents define and isolate the agent. The parent gets a structured response.
- Beads record the task's journey. Any session, now or later, can query the same database.

The Software Factory pattern (`gc`) builds on top of beads to add the orchestration substrate. Adopting beads alone, without `gc`, gets you the durable journal at the cost of one tool to install. The `aispire` stack's current direction is to use Claude-native primitives for definition + lifecycle and beads for durable state, with `gc` reserved for the daemonized-background-worker case if and when that workload materializes.

## Where managed runtimes (Claude Managed Agents) fit

Managed Agents is in the API tier of the stack, not the Claude Code tier. It addresses a different question: "how do I run a stateful, sandbox-executing, memory-bearing agent without writing my own runtime?" That question becomes relevant when:

- You have a live customer-facing or staff-facing virtual employee that needs persistent memory across user sessions (a learner-facing tutor with progress tracking, for example).
- You want sandboxed code execution without managing the container infrastructure yourself.
- You're willing to pay $0.08/hr active runtime + standard token rates for the affordances.

For build-time pipelines (curriculum production, lecture generation, QA passes) the Managed Agents value proposition is weak — the work is batch-shaped and human-gated, and a hosted stateful runtime adds runtime cost without proportional benefit. For runtime-shaped agents (live staff or learner copilots) Managed Agents is the leading 2026 option.

## Beyond the two: other open-source orchestrators worth knowing

A non-exhaustive list of currently-maintained OSS frameworks that solve adjacent or overlapping problems. Several of these are the right pick over Claude-native or Gas City for specific workloads — see [`case-studies.md`](case-studies.md) for which workload picks which.

| Project | Layer | License | When it fits |
|---|---|---|---|
| [LangGraph](https://github.com/langchain-ai/langgraph) | Graph orchestration | MIT | Stateful branching workflows; you want explicit graph topology + checkpointing |
| [LlamaIndex Workflows](https://github.com/run-llama/llama_index) | Event-driven workflows | MIT | RAG-heavy pipelines with event-based steps |
| [Temporal](https://github.com/temporalio/temporal) | Durable runtime | MIT | Production agents needing exactly-once semantics + crash recovery at scale |
| [Restate](https://github.com/restatedev/restate) | Durable runtime | BSL→Apache | Lighter-ops alternative to Temporal |
| [Inngest](https://github.com/inngest/inngest) | Workflow runner | Apache-2.0 (SDK) | Event-triggered durable workflows |
| [Trigger.dev](https://github.com/triggerdotdev/trigger.dev) | Workflow runner | Apache-2.0 (core) | TypeScript-first equivalent to Inngest |
| [CrewAI](https://github.com/crewAIInc/crewAI) | Multi-agent | MIT | Quick prototypes of role-based agent teams |
| [AutoGen](https://github.com/microsoft/autogen) / [AG2](https://github.com/ag2ai/ag2) | Multi-agent | MIT / Apache-2.0 | Conversational multi-agent patterns |
| [Letta](https://github.com/letta-ai/letta) | Memory-bearing agent | Apache-2.0 | Agents that need persistent memory across many sessions |
| [Mastra](https://github.com/mastra-ai/mastra) | TS agent framework | Apache-2.0 | TypeScript stacks needing batteries-included agent dev |
| [Agno](https://github.com/agno-agi/agno) (formerly Phidata) | Python agent framework | MPL-2.0 | Lightweight Python multi-agent without LangChain |
| [Pydantic AI](https://github.com/pydantic/pydantic-ai) | Typed agents | MIT | Python teams wanting strong typing + structured output by default |
| [DSPy](https://github.com/stanfordnlp/dspy) | Prompt optimization | MIT | Programmatic LM composition with automatic optimization |
| [BAML](https://github.com/BoundaryML/baml) | Structured-output DSL | Apache-2.0 | Reliable typed LM outputs across a polyglot stack |
| [claude-agent-sdk](https://github.com/anthropics/claude-agent-sdk-python) | Anthropic SDK | MIT | Building agents that share Claude Code's loop outside the CLI |
| [OpenAI Agents SDK](https://github.com/openai/openai-agents-python) | OpenAI SDK | Apache-2.0 | Cross-vendor counterpart to claude-agent-sdk |
| [Google ADK](https://github.com/google/adk-python) | Google SDK | Apache-2.0 | Gemini-native equivalent |
| [Smolagents](https://github.com/huggingface/smolagents) | Lightweight | Apache-2.0 | Minimalist code-execution agents |
| [CopilotKit](https://github.com/CopilotKit/CopilotKit) | UI layer | MIT | React surface for in-app copilots; pairs with any backend |

License and maintenance status drift fast in the agent-framework space; verify against the project's GitHub LICENSE file and recent commit activity before depending on any of these.

## What the comparison is not

This is not a benchmark or a winner-takes-all framing. The `aispire` stack uses both Claude-native primitives and beads in production. It does not use Gas City as the operational orchestrator (the Software Factory was evaluated as a methodology; the daemonized-orchestrator surface area isn't justified at current volume). The comparison's purpose is to map each approach to the layer it actually serves, not to advocate for a single tool.
