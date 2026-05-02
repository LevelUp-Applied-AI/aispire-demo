# aispire-demo

Silent-pass bug reproduction from `aispire`'s production QA harness, with a fail-closed alternative.

## Context

`aispire` is a 16-week full-time Applied AI & ML Systems course run as a small org where nineteen AI employees across seven departments outnumber the human team. The fix demonstrated here is one piece of a broader evaluation of two orchestration approaches: Claude Code's 2026-native primitives (subagents, hooks, skills) and the Software Factory pattern (beads, Gas City). They solve adjacent problems — subagents and hooks fix agent definition, isolation, and lifecycle; task ledgers fix durable cross-session state; managed runtimes fix infra. They stack; they don't substitute. This repo demonstrates the first layer's invariant.

## The bug

The production QA harness wrapped each agent invocation roughly as:

```bash
AGENT_OUTPUT=$(run_agent 2>&1) || true
errors=$(echo "$AGENT_OUTPUT" | grep -c '\[ERROR\]')
[[ $errors -eq 0 ]] && echo "PASS"
```

If the agent crashes before producing output, `AGENT_OUTPUT` is empty, the grep returns `0`, and the runner reports green. The same shape recurs in any harness that infers status from stdout markers.

## The fix

Require the agent to write structured output to a known file path. The runner reads that file post-execution. Missing file or non-zero exit code → fail closed.

In Claude Code, the equivalent enforcement is a `Stop` hook in `.claude/settings.json` that validates the structured output before the session ends.

## Layout

| File | Purpose |
|---|---|
| `scripts/agent.sh` | Synthetic agent. `AGENT_MODE` env var selects behavior (`ok`, `warn`, `error`, `crash`). |
| `scripts/runner_legacy.sh` | Stdout-grep harness. Ships green on a crashed agent. |
| `scripts/runner_v2.sh` | Fail-closed runner. Requires structured JSON at `$OUTPUT_FILE` (default `/tmp/agent-output.json`). |

## Run

```bash
# Reproduce the bug
AGENT_MODE=crash bash scripts/runner_legacy.sh   # exit 0

# Fail closed on the same crash
AGENT_MODE=crash bash scripts/runner_v2.sh       # exit 2
```

All four agent modes work in both runners. The discrepancy is most visible in the `crash` case.

## Out of scope

- Not a Claude Code subagent + hook configuration. The v2 runner demonstrates the invariant a `Stop` hook would enforce, expressed as a portable bash script.
- Not an orchestration framework (Gas City, beads, LangGraph, etc.). The synthetic agent has no LLM dependency.

## License

MIT.
