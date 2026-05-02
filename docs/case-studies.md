# Case Studies — Where Each Approach Wins

Six real workloads from the `aispire` 19-agent stack, with the orchestration choice that fits each and why. Several alternative frameworks are flagged where they offer comparable or better fits than the two primary contenders.

---

## 1. QA harness that hides crashed agents

**Workload:** A QA fleet of six auditors runs against every curriculum module before merge. Each auditor is a `claude --print` subprocess wrapped by a shell runner that infers status from stdout markers. A crashed auditor produces no output; the runner ships green.

**Best fit: Claude-native (subagents + `Stop` hook).** Define each auditor as a proper subagent with a structured-output protocol; enforce the invariant via a `Stop` hook that fails closed when the output file is missing. Five minutes of `.claude/settings.json` work; the existing prompts carry over largely unchanged.

**What Gas City would add:** Marginal value here. Gas City's formulas have explicit exit criteria per step, which formalize the same invariant — but installing a daemonized orchestrator to fix a single fail-closed gap is over-engineered. **Skip Gas City for this case unless you're already running it for other reasons.**

**Alternative open-source options:**
- **Pydantic AI** (https://github.com/pydantic/pydantic-ai) — typed structured outputs are non-optional by construction; the framework refuses to return anything that doesn't validate against the declared schema. Solves the same class of bug in Python applications.
- **BAML** (https://github.com/BoundaryML/baml) — compiles structured-output schemas into typed clients across languages. Same protection at the structured-output layer rather than the lifecycle layer.

**Reproduction:** [`examples/silent-pass/`](../examples/silent-pass/) in this repo.

---

## 2. Curriculum module build that survives mid-flight crashes

**Workload:** Building a single course module is a 9-step process: scaffold, draft build packet, implement deliverables, validate, push template repos, etc. A session may take 90+ minutes. A crash at step 6 should resume at step 6, not lose state to a stale `HANDOFF.md`.

**Best fit: durable task ledger.** Two viable approaches:

- **Beads (`bd`) standalone.** `bd init` in the repo. Each step transitions a bead through labels (`needs-section-a`, `section-a-approved`, `needs-validation`, `qa-clean`). On restart, `bd ready` shows exactly where the session was. Git-native — the journal travels with the repo.

- **Hand-rolled `_state.json`** per pipeline. Lower ceiling, zero new dependencies. Already proven in `aispire`'s lecture pipeline (`_deck-state.json`). Best when you don't need cross-pipeline querying.

**What Gas City would add:** **Significant value** if you're running multiple module builds in parallel. Gas City's per-rig isolation lets each module build run independently while sharing a beads database. `gc events` gives a unified audit log across all rigs. `gc handoff` on PreCompact emits structured session snapshots. `gc dashboard` provides a single-pane view of every active build. **Pick Gas City over bd alone when you need observability across many concurrent runs.**

**Alternative open-source options:**
- **Temporal** (https://github.com/temporalio/temporal) — industrial-grade durable workflow engine with deterministic replay. Right answer if you're already running Temporal for other workloads or need cross-language durability with strong SLAs. Heavier ops than bd.
- **Restate** (https://github.com/restatedev/restate) — single-binary durable execution; lighter ops than Temporal. Note: BSL license, converts to Apache-2.0 after a delay.
- **LangGraph** (https://github.com/langchain-ai/langgraph) — graph-based with checkpointing; good fit if the build pipeline is shaped like a state graph and you want time-travel debugging. License: MIT.

---

## 3. Cohort-pulse daemonized monitor

**Workload:** A background agent watches the cohort-feedback Google Sheet daily. When submission rates drop or unusual patterns emerge, it surfaces a finding to the lead instructor. No human is in the session loop most of the time.

**Best fit: Gas City — significant value here.** This is the use case where the daemonized-orchestrator value shows up clearly:

- **Orders (polling gates):** an order at `formulas/orders/cohort-pulse-intake/order.toml` defines the wake condition (e.g., a daily timer or a label match on a freshly-imported sheet snapshot bead). The daemon's `patrol_interval` polls the order's check expression at a fixed interval.
- **Formulas (multi-step workflows):** the agent's behavior is a `*.formula.toml` with declared steps, preconditions, and exit criteria. Reproducible across runs.
- **Per-rig isolation:** the cohort-pulse rig is independent of other agents; its state and beads live in their own namespace.
- **`gc events` + `gc dashboard`:** an audit trail across many runs, and a visual surface for the lead instructor to see the agent's recent activity.

**What Claude-native primitives would offer:** Hooks fire on session-bounded events (`SessionStart`, `Stop`, etc.), not on continuous polling against external state. Without an external scheduler, Claude-native primitives don't address this workload.

**Alternative open-source options:**
- **Inngest** (https://github.com/inngest/inngest) — event-driven step-function runner with AI helpers. Right pick when the trigger is webhook-shaped (e.g., a Sheets change notification) rather than a polling check.
- **Trigger.dev** (https://github.com/triggerdotdev/trigger.dev) — TypeScript-first equivalent.
- **Temporal** — durable scheduled workflows; right pick if you already run Temporal.
- **Plain cron + a Python script** that calls the Anthropic API. Lowest-overhead v0; upgrade to Gas City or Inngest when the cron approach starts to fray (multiple workloads, retries, observability).

---

## 4. Multi-agent QA cross-referencing during a single run

**Workload:** Six QA auditors review the same module. The Governance-Compliance auditor flags a missing token URL. The Learner-Experience auditor independently confirms the same URL is referenced in a learner-facing guide. The two findings should be linked into a single elevated finding rather than reported as two unrelated issues.

**Best fit: depends on whether the coordination is *during* a single run or *across* runs.**

**During-run coordination — agent framework (LangGraph or Mastra):**
- **LangGraph** (https://github.com/langchain-ai/langgraph) — explicit state graph with shared state across nodes. Multiple agents can read each other's findings via the shared graph state. Right pick for synchronous multi-agent workflows in Python.
- **Mastra** (https://github.com/mastra-ai/mastra) — TypeScript equivalent with workflows and shared agent state. Right pick in a TS stack.
- **CrewAI** (https://github.com/crewAIInc/crewAI) — role-based coordination with shared task context. Faster prototyping but mixed production reviews.

**Across-run coordination — Gas City — significant value:**
- Slings (`gc sling <rig>--<agent> <bead-id>`) route work between agents via the durable journal. Auditor A's finding becomes a bead; auditor B sees it via `bd ready --label=cross-reference-pending`. The handoff is asynchronous and durable.
- This lets the system run six auditors as separate sessions over hours, with the coordination layer (the bead journal) outliving any one of them.

**What Claude-native primitives offer:** The Task tool can invoke multiple subagents from a parent and aggregate structured returns. This works for shallow coordination patterns (parent collects all findings, runs cross-reference logic itself) but doesn't extend to multi-step bidirectional handoffs. **Sufficient for a single-pass aggregation; insufficient for genuine collaborative workflows.**

**Note: live agent-to-agent coordination in Anthropic Managed Agents** is gated behind a separate access request as of 2026-04 and not in the public beta.

---

## 5. Live learner-facing tutor with persistent memory across sessions

**Workload:** A student-facing virtual employee that remembers a learner's progress, prior questions, and conceptual gaps across many sessions over a 16-week course. Adapts its explanations to the learner over time.

**Best fit: memory-bearing runtime.**

- **Letta (formerly MemGPT)** (https://github.com/letta-ai/letta) — agent server with first-class core/archival memory blocks. Self-editing memory; persists across sessions. **Right pick when memory is the dominant requirement and you want an open-source server.**
- **Anthropic Managed Agents (commercial)** with Memory Stores. Hosted runtime, no server to operate, but vendor lock-in and runtime cost ($0.08/hr active).

**What Claude-native primitives offer:** Skills, hooks, and subagents are session-bounded. Persistent cross-session memory is not directly addressed. A hand-rolled solution (writing to disk in a hook, reading on session start) works but lacks the affordances Letta or Managed Agents provide.

**What Gas City offers:** Beads can record the learner's interaction history (every conversation as a bead), and `gc prime` could load relevant context at session start. **A real but partial fit** — beads is a task journal, not a memory primitive. The data shape (chronological events with labels) is wrong for "what does this learner know" queries. Use beads to track *what the agent did* alongside Letta or Managed Agents handling *what the agent remembers*.

**Alternative open-source options:**
- **Anthropic Claude Agent SDK** (https://github.com/anthropics/claude-agent-sdk-python) — open-source library exposing Claude Code's agent loop. Pair with hand-rolled memory storage for full control.
- **OpenAI Agents SDK** (https://github.com/openai/openai-agents-python) — analogous primitive on the OpenAI side.

---

## 6. Build-time parallel auditor invocation

**Workload:** Run all six QA auditors against a freshly-built module concurrently, aggregate their structured findings, gate the merge on the aggregate.

**Best fit: Claude-native subagents + parallel Task invocation.** The parent session spawns six subagents in parallel via the Task tool, collects each one's structured JSON return, aggregates per-finding severity, and either passes the gate or surfaces the failures. The fail-closed `Stop` hook from case study 1 still applies per-subagent.

**What Gas City would add:** If the auditors emit beads (case studies 2 and 4 patterns), the aggregate is queryable across runs as well as within the run. **Useful but not load-bearing** for this workload — the parallel-invocation primitive matters more than the audit trail.

**Alternative open-source options:**
- **AutoGen** (https://github.com/microsoft/autogen) or **AG2** (https://github.com/ag2ai/ag2) — multi-agent conversation frameworks. Workable if the coordination is conversational rather than gate-and-aggregate. The fork between AutoGen and AG2 fragments the ecosystem; pick based on your team's existing stack.
- **CrewAI** — fast prototype, weaker production ergonomics.
- **Anthropic Claude Agent SDK** — if you want to express this without the Claude Code CLI.

---

## Summary table

| Workload | Best fit | Gas City's specific value | Cross-vendor alternative |
|---|---|---|---|
| Silent-pass fix | Claude-native subagent + `Stop` hook | Marginal | Pydantic AI, BAML |
| Build resumption after crash | beads or hand-rolled state | Significant if many concurrent builds | Temporal, Restate, LangGraph |
| Daemonized background monitor | Gas City | Significant — orders + patrol + audit log | Inngest, Trigger.dev, cron+script |
| Multi-agent during a run | LangGraph / Mastra / Claude Task | Marginal during-run; significant across-run | LangGraph, Mastra, CrewAI |
| Live tutor with persistent memory | Letta or Managed Agents | Partial — task journal, not memory | claude-agent-sdk, openai-agents-python |
| Parallel auditor invocation | Claude-native subagents (Task tool) | Useful for cross-run aggregation | AutoGen / AG2, claude-agent-sdk |

## Notes on the framework landscape

**A non-exhaustive list of currently-maintained open-source orchestration frameworks worth knowing,** beyond Claude-native primitives and Gas City. Verify license and maintenance status against the project's GitHub before depending on any of these — the agent framework landscape moves fast and several have shifted licensing or pivoted to managed-only between 2024 and 2026:

- **Graph / workflow:** LangGraph, LlamaIndex Workflows
- **Durable runtimes:** Temporal, Restate, Inngest, Trigger.dev
- **Multi-agent:** CrewAI, AutoGen, AG2, Letta
- **Agent libraries:** Mastra (TS), Agno (formerly Phidata), Pydantic AI
- **Prompt / type layers:** DSPy, BAML
- **Vendor SDKs:** Anthropic Claude Agent SDK, OpenAI Agents SDK, Google ADK
- **Lightweight:** Smolagents
- **UI:** CopilotKit + AG-UI Protocol
- **Standards (not orchestrators):** MCP for tool calling, A2A for agent-to-agent

The choice between any of these and Claude-native + Gas City is rarely about which is "best." It's about which layer you're solving for, what languages your team writes in, and whether you want to install and operate a separate substrate or work within the file system as the substrate. The case studies above identify the layer first; the framework selection follows.
