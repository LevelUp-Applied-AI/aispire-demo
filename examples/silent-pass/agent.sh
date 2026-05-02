#!/usr/bin/env bash
# agent.sh — synthetic QA agent.
#
# Stands in for `claude --print` invocations of the real qa-agents/*.md prompts.
# Behavior is controlled by the AGENT_MODE env var so we can demo all paths
# without actually calling an LLM (latency and flake risk on stage).
#
# Modes:
#   AGENT_MODE=ok      → emits a clean structured finding, exits 0
#   AGENT_MODE=warn    → emits a warning-level finding, exits 0
#   AGENT_MODE=error   → emits an error-level finding, exits 1
#   AGENT_MODE=crash   → emits NOTHING and dies (the silent-pass bug)
#
# Output protocol (when not crashed):
#   - Stdout receives bracketed log lines: [OK] / [WARN] / [ERROR]  ← the legacy runner greps these
#   - $OUTPUT_FILE receives a structured JSON finding              ← the v2 runner reads this

set -uo pipefail

OUTPUT_FILE="${OUTPUT_FILE:-/tmp/agent-output.json}"
MODE="${AGENT_MODE:-ok}"
AGENT_NAME="${AGENT_NAME:-governance-compliance}"
MODULE="${MODULE:-demo}"

case "$MODE" in
  ok)
    echo "[OK] ${AGENT_NAME} on ${MODULE}: 4 checks passed."
    cat > "$OUTPUT_FILE" <<EOF
{
  "agent": "${AGENT_NAME}",
  "module": "${MODULE}",
  "status": "ok",
  "findings": [],
  "crashed": false
}
EOF
    exit 0
    ;;
  warn)
    echo "[WARN] ${AGENT_NAME} on ${MODULE}: 1 advisory finding."
    cat > "$OUTPUT_FILE" <<EOF
{
  "agent": "${AGENT_NAME}",
  "module": "${MODULE}",
  "status": "warn",
  "findings": [{"severity": "warn", "id": "GC-2", "msg": "stretch spec missing rubric"}],
  "crashed": false
}
EOF
    exit 0
    ;;
  error)
    echo "[ERROR] ${AGENT_NAME} on ${MODULE}: rule violation detected."
    cat > "$OUTPUT_FILE" <<EOF
{
  "agent": "${AGENT_NAME}",
  "module": "${MODULE}",
  "status": "error",
  "findings": [{"severity": "error", "id": "GC-1", "msg": "personal name in repo file"}],
  "crashed": false
}
EOF
    exit 1
    ;;
  crash)
    # Silent crash — no output, no JSON, non-zero exit.
    # This is the case the legacy runner ships green on.
    rm -f "$OUTPUT_FILE"
    exit 137
    ;;
  *)
    echo "[ERROR] agent.sh: unknown AGENT_MODE='${MODE}'" >&2
    exit 2
    ;;
esac
