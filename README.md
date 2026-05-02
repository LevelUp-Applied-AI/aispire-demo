# aispire-demo

Minimal silent-pass reproduction — the live 30-second beat in *Hiring 19 AI Employees: Field Notes from a Production EdTech Startup* (AI Tinkerers Seattle Science Fair, 2026-05-01).

The talk's substance runs against real production repos (`aispire-14005` for the Claude-native side, `~/Projects/factory/lab_l4/l4-gc-factory` for the Software Factory side). This repo exists for one purpose: a safe place to crash an agent on stage and watch the legacy QA runner ship green, then run the same crash through a fail-closed v2 runner.

## What's here

| File | Purpose |
|---|---|
| `scripts/agent.sh` | Synthetic QA agent. `AGENT_MODE` controls behavior (`ok` / `warn` / `error` / `crash`). Crashes silently with no stdout, no output file, exit 137. |
| `scripts/runner_legacy.sh` | Faithful reproduction of `aispire-14005/scripts/qa-agents/runner.sh:198–210`. Wraps the agent in `$(... 2>&1) \|\| true` and counts errors via `grep '\[ERROR\]'`. Ships green on a crashed agent. |
| `scripts/runner_v2.sh` | Fail-closed runner. Requires structured JSON output at `$OUTPUT_FILE`; missing file or non-zero exit fails closed. The pattern a Claude Code `Stop` hook would enforce. |

## Run the demo locally

```bash
# The bug: legacy runner ships green on a crashed agent
AGENT_MODE=crash bash scripts/runner_legacy.sh   # exit 0 — green

# The fix: v2 runner fails closed on the same crash
AGENT_MODE=crash bash scripts/runner_v2.sh       # exit 2 — red
```

Side-by-side run:
```bash
echo "=== LEGACY ==="; AGENT_MODE=crash bash scripts/runner_legacy.sh; echo "exit=$?"
echo "=== V2 ==="; AGENT_MODE=crash bash scripts/runner_v2.sh; echo "exit=$?"
```

## What this is *not*

Not a full Claude Code subagent + hook setup. The v2 runner *demonstrates the pattern* a `Stop` hook would enforce — same fail-closed invariant, same "missing structured output = crash" detection — but as a bash script for stage reliability. The real `.claude/agents/` definition + `Stop` hook config lives in production aispire-14005's planning, not here.

Not a Software Factory / Gas City demo. The talk's right terminal walks through `~/Projects/factory/lab_l4/l4-gc-factory`, an existing rig from the Software Factory intensive workshop. Real city, real formulas, real history.

## See also

- The on-stage script: `aispire-planning/2026-may-1-demo-script.md`
- Talk planning, employee org chart, refactor plan, orchestration evaluation: `aispire-planning/`
- The actual silent-pass bug in production: `aispire-14005/scripts/qa-agents/runner.sh:198–210`
