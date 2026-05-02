# silent-pass

A QA harness wraps an agent invocation in a subprocess call and infers the agent's verdict from stdout markers. When the agent crashes before producing any output, the runner's grep finds zero `[ERROR]` markers and reports success. The harness ships green on a crashed run.

This is a real bug class. It appears in any DIY agent rig that reads stdout to determine whether the agent passed or failed. Autograding systems explicitly forbid this pattern in education — running pytest against an empty stub silently passes for the same reason. The same defect class hides in agent harnesses across the industry.

## The pattern, faithfully

`runner_legacy.sh` reproduces the canonical broken shape:

```bash
AGENT_OUTPUT=$(run_agent 2>&1) || true
errors=$(echo "$AGENT_OUTPUT"  | grep -c '\[ERROR\]')
warnings=$(echo "$AGENT_OUTPUT" | grep -c '\[WARN\]')
passed=$(echo "$AGENT_OUTPUT"  | grep -c '\[OK\]')

[[ $errors -eq 0 ]] && echo "PASS"
```

Three failure modes:

- The `|| true` swallows the agent's exit code.
- The `2>&1` lumps stderr into the same stream that's being grepped — but if the agent crashes before writing anything, both streams are empty.
- `grep -c` returns `0` for "pattern matched zero lines," indistinguishable from "no lines were inspected."

Result: a crashed agent produces an empty `AGENT_OUTPUT`, all three counters land at zero, and the runner concludes PASS.

## The fail-closed pattern

`runner_v2.sh` enforces a different invariant:

1. The agent's authoritative result is a structured JSON file at `$OUTPUT_FILE`, not stdout. Stdout is for humans; the file is for the runner.
2. The runner pre-clears the file before invocation so a stale file from a prior run cannot pass for a fresh one.
3. After the agent exits, the runner requires (a) the file exists, (b) the file parses as JSON with a `status` field, and (c) the agent's exit code is zero.
4. Any of those failing → fail closed.

The runner does not swallow exit codes. The runner does not infer outcomes from stdout. A crashed agent that produced no file is detected before any downstream step proceeds.

## In Claude Code terms

The same invariant is enforceable as a `Stop` hook in `.claude/settings.json` that runs after a subagent invocation completes:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "test -f /tmp/agent-output.json && python3 -c \"import json; assert 'status' in json.load(open('/tmp/agent-output.json'))\" || exit 1"
          }
        ]
      }
    ]
  }
}
```

The hook fires when the parent session is about to end. Missing or malformed structured output causes the hook to exit non-zero, blocking the Stop event. The lifecycle gate enforces the same invariant the v2 runner does, but at the Claude Code session boundary instead of in a wrapper script.

## Synthetic agent

`agent.sh` stands in for `claude --print` invocations of a real subagent prompt. Behavior is selected by the `AGENT_MODE` env var so the example runs deterministically, with no LLM dependency:

| `AGENT_MODE` | stdout | output file | exit |
|---|---|---|---|
| `ok` | `[OK] ...` line | clean JSON, `status: ok`, `crashed: false` | 0 |
| `warn` | `[WARN] ...` line | JSON with one warn finding | 0 |
| `error` | `[ERROR] ...` line | JSON with one error finding, `status: error` | 1 |
| `crash` | (empty) | (no file) | 137 |

Every mode is worth running through both runners. The discrepancy between the two harnesses is most visible in the `crash` case but is also informative in the `error` case (the legacy runner catches it because it still produces an `[ERROR]` line; the bug is specifically about *missing* output, not malformed output).

## Run

```bash
# Reproduce the bug
AGENT_MODE=crash bash runner_legacy.sh   # Result: PASS, exit 0

# Fail closed on the same crash
AGENT_MODE=crash bash runner_v2.sh       # FAIL: agent produced no output file, exit 2

# Sanity-check the happy path
AGENT_MODE=ok bash runner_v2.sh          # Result: PASS, exit 0

# Compare error handling
AGENT_MODE=error bash runner_legacy.sh   # Result: FAIL, exit 1 (caught — error in stdout)
AGENT_MODE=error bash runner_v2.sh       # Result: FAIL, exit 1 (caught — status field)
```

Side-by-side:

```bash
for mode in ok warn error crash; do
  echo "=== mode=$mode ==="
  AGENT_MODE=$mode bash runner_legacy.sh; echo "  legacy exit=$?"
  AGENT_MODE=$mode bash runner_v2.sh;     echo "  v2     exit=$?"
done
```

## What this example does *not* prove

- It does not prove that subagents are categorically better than wrapper scripts. The fail-closed invariant is the active ingredient; it can be enforced in many ways. This example uses bash for portability and determinism.
- It does not prove that any specific orchestration framework would have prevented the bug. A manually-written subagent + Stop hook also requires discipline; an inattentive operator can wire a Stop hook that doesn't actually validate anything.
- It does not address the durable-state question (what happens to in-flight work when a session crashes mid-run). That's a different invariant — see the parent README's case studies.
