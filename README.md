# aispire-demo

A reference repository for evaluating orchestration approaches in a production AI-employee org. Built around `aispire`, a 16-week full-time Applied AI & ML Systems course where nineteen AI agents across seven departments outnumber the human team. Includes a working reproduction of a silent-pass bug class found in a production QA harness, side-by-side analysis of two orchestration patterns, and case studies covering several adjacent open-source frameworks.

You might be interested in this if you're:

1. **Operator of production AI-employee orgs** — practical references for orchestration choices a growing org has to make.
2. **Engineer evaluating Claude Code's 2026-native primitives vs. Gas City Sofware Factory** — side-by-side mapping of capabilities to layers.
3. **Anyone diagnosing silent-pass bugs in a QA harness** — a deterministic reproduction with a fail-closed alternative.

## What "AI employees" means here

AI agents are treated as hires rather than code. The framing forces commitment to four things human hires get: 
- a job description (system prompt)
- a scope (allowed tools, file paths)
- a quality bar (structured output protocol)
- accountability (chain or lifecycle gates). 

The `aispire` org chart, sanitized for this repository, looks like this as of May 2026:

| Department | Employees | What they do |
|---|---|---|
| Curriculum | 2 | Drafts module and pre-course build packets; scaffolds and validates artifacts |
| Content Production | 7 | Drafts slide specs, generates and audits images, audits speaker notes, manages asset library |
| Curriculum QA | 6 | Audits build artifacts for learner-experience consistency, autograder quality, governance compliance, grading alignment, technical flow, difficulty calibration |
| Instructional Design Science | 1 | Verifies runtime evidence supports declared learning outcomes |
| Learner Experience | 1 | Plays a pilot-cohort learner; reports issues with the assignment instructions |
| Cohort Insights | 1 | Staff-facing chatbot synthesizing live weekly learner feedback |
| External Comms | 1 | Builds external communication/community talks |

Models are mixed by role: 14 employees use Claude (Code or API), 3 use Gemini (Pro or 2.5-flash-image, for visual audit), 1 uses OpenAI (Responses API with the `image_generation` tool, for image generation). Each role uses the model that fits the work and the budget.

## Orchestration

Once you have several AI employees, agent orchestration becomes more important — the same problems growing human teams face: specialization, scope, handoffs, and accountability. Each fixes a specific layer of the agent stack:

- **Subagents** fix agent definition, isolation, and lifecycle.
- **Hooks** fix lifecycle enforcement and session-boundary state.
- **Skills** fix discoverable procedure invocation.
- **Task ledgers** (beads, Gas City) fix durable state across sessions.
- **Managed runtimes** (Claude Managed Agents, Letta) fix sandboxed execution and cross-session memory.
- **Workflow runners** (Temporal, Inngest, Restate) fix industrial-grade durability with retries and replay.
- **Agent frameworks** (LangGraph, Mastra, CrewAI, AutoGen) fix synchronous multi-agent coordination during a single run.

These layers stack – identify the layer first and the tool second.

For the side-by-side mapping, see [`docs/orchestration-comparison.md`](docs/orchestration-comparison.md).
For workload-specific recommendations, see [`docs/case-studies.md`](docs/case-studies.md).

## Examples reproduced here

Across `aispire`'s six Curriculum QA auditors, status was originally inferred from `claude --print` stdout via `grep -c '\[ERROR\]'`. A crashed auditor produced no output; the harness counted zero errors and reported a clean pass. The same pattern appears in any DIY agentic system that reads stdout to determine pass/fail — a defect class we want to explicitly forbid in educational autograding.

The reproduction at [`examples/silent-pass/`](examples/silent-pass/) includes:

- `agent.sh` — a synthetic agent with deterministic modes (`ok` / `warn` / `error` / `crash`), so the example runs without any LLM dependency.
- `runner_legacy.sh` — a reproduction of the broken pattern. Ships green on a crashed agent.
- `runner_v2.sh` — a fail-closed runner that requires structured JSON output at a known file path. Missing file or non-zero exit code → fail closed.

Quick run:

```bash
git clone https://github.com/LevelUp-Applied-AI/aispire-demo
cd aispire-demo

# Reproduce the bug
AGENT_MODE=crash bash examples/silent-pass/runner_legacy.sh   # exit 0 — green on a crash

# Fail closed on the same crash
AGENT_MODE=crash bash examples/silent-pass/runner_v2.sh       # exit 2 — red on a crash
```

In Claude Code, the v2 runner's invariant is enforceable as a `Stop` hook in `.claude/settings.json` that validates the structured output file before allowing the session to end. Five minutes of config work.

## Other workloads, other answers

Six representative workloads are covered in [`docs/case-studies.md`](docs/case-studies.md):

1. **QA harness that hides crashed agents** → Claude-native subagents + `Stop` hook
2. **Curriculum module build that survives mid-flight crashes** → durable task ledger (beads, or hand-rolled state)
3. **Cohort-pulse daemonized monitor** → Gas City (orders + patrol), or Inngest, or cron+script
4. **Multi-agent QA cross-referencing during a single run** → LangGraph or Mastra (during-run); Gas City slings (across-run)
5. **Live learner-facing tutor with persistent memory** → Letta or Anthropic Managed Agents
6. **Build-time parallel auditor invocation** → Claude-native Task tool

For each, the case studies file is explicit about Gas City's specific value when it's the right pick (significant for case 3; partial for cases 4 and 5; marginal for cases 1 and 6) and lists comparable open-source alternatives.

## Repository layout

```
aispire-demo/
├── README.md                            ← this file
├── docs/
│   ├── orchestration-comparison.md     ← Claude-native vs. Software Factory side-by-side
│   └── case-studies.md                 ← six workloads with framework-specific recommendations
├── examples/
│   └── silent-pass/                    ← deterministic reproduction + fail-closed alternative
│       ├── README.md
│       ├── agent.sh
│       ├── runner_legacy.sh
│       └── runner_v2.sh
└── LICENSE
```

## Out of scope (and why)

- **Not a full Claude Code subagent + hook configuration.** The v2 runner demonstrates the invariant a `Stop` hook would enforce, expressed as a portable bash script. Production `aispire` repos hold the actual subagent definitions and hook configurations.
- **Not a Gas City installation guide.** Gas City lives outside this repository; the case studies cover when adopting it is justified.
- **Not a benchmark.** No timing comparisons, no throughput claims. The "right answer" varies by workload, not by raw performance.

## License

MIT.
