#!/usr/bin/env bash
# runner_legacy.sh — reproduction of the silent-pass bug from
# aispire-14005/scripts/qa-agents/runner.sh:198–203.
#
# What this does (faithfully): wraps the agent invocation in
#   AGENT_OUTPUT=$(... 2>&1) || true
# and counts errors by grepping stdout for [ERROR] markers.
#
# Why it's broken: if the agent crashes BEFORE producing output,
# AGENT_OUTPUT is empty, the grep counts zero, and the runner
# reports "0 errors, 0 warnings, 0 passed" — exit code 0.
# Green on a crashed run.
#
# This is the bug the demo's v2 runner fixes.

set -uo pipefail

AGENT_NAME="${AGENT_NAME:-governance-compliance}"
MODULE="${MODULE:-demo}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== ${AGENT_NAME} — Module ${MODULE} (LEGACY runner) ==="

# Faithful reproduction of the broken pattern.
AGENT_OUTPUT=$(bash "${SCRIPT_DIR}/agent.sh" 2>&1) || true

agent_errors=$(echo "$AGENT_OUTPUT" | grep -c '\[ERROR\]' || true)
agent_warnings=$(echo "$AGENT_OUTPUT" | grep -c '\[WARN\]' || true)
agent_passed=$(echo "$AGENT_OUTPUT" | grep -c '\[OK\]' || true)

echo ""
echo "Agent stdout:"
echo "${AGENT_OUTPUT:-<empty>}"
echo ""
echo "Counted: ${agent_errors} errors, ${agent_warnings} warnings, ${agent_passed} passed"

if [[ $agent_errors -gt 0 ]]; then
  echo "Result: FAIL"
  exit 1
fi

echo "Result: PASS"
exit 0
