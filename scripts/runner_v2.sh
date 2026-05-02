#!/usr/bin/env bash
# runner_v2.sh — fail-closed runner that doesn't trust stdout.
#
# Two changes from runner_legacy.sh:
#   1. The agent's authoritative output is a structured JSON file at $OUTPUT_FILE,
#      not stdout. Stdout is for humans; the file is for the runner.
#   2. If the file is missing OR the agent's exit code is non-zero, fail closed.
#      A crashed agent that produced no file = automatic fail. No silent green.
#
# In a real Claude Code setup, this is implemented as a Stop hook (see
# .claude/settings.json) running after a subagent invocation — the hook checks
# the same invariant (output file present + parseable + status field) and
# blocks the parent session from proceeding if any of them fail.

set -uo pipefail

AGENT_NAME="${AGENT_NAME:-governance-compliance}"
MODULE="${MODULE:-demo}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export OUTPUT_FILE="${OUTPUT_FILE:-/tmp/agent-output.json}"

echo "=== ${AGENT_NAME} — Module ${MODULE} (v2 runner, fail-closed) ==="

# Pre-clear the output file so we don't read a stale one.
rm -f "$OUTPUT_FILE"

# Run the agent. We DO NOT swallow its exit code.
bash "${SCRIPT_DIR}/agent.sh"
agent_exit=$?

# Validate the structured output exists.
if [[ ! -f "$OUTPUT_FILE" ]]; then
  echo ""
  echo "FAIL: agent produced no output file at ${OUTPUT_FILE}."
  echo "      Agent exit code was ${agent_exit}."
  echo "      This is the silent-pass case the legacy runner ships green on."
  exit 2
fi

# Parse the file's status field.
status=$(python3 -c "import json,sys; print(json.load(open('${OUTPUT_FILE}')).get('status','missing'))")
crashed=$(python3 -c "import json,sys; print(json.load(open('${OUTPUT_FILE}')).get('crashed', True))")

echo ""
echo "Structured output:"
cat "$OUTPUT_FILE"
echo ""
echo "Status: ${status}"
echo "Crashed flag: ${crashed}"
echo "Agent exit code: ${agent_exit}"

# Fail-closed checks.
if [[ "$crashed" != "False" ]]; then
  echo "Result: FAIL (crashed flag set)"
  exit 1
fi
if [[ "$status" == "error" ]]; then
  echo "Result: FAIL (error-level finding)"
  exit 1
fi
if [[ $agent_exit -ne 0 ]]; then
  echo "Result: FAIL (non-zero exit)"
  exit 1
fi

echo "Result: PASS"
exit 0
