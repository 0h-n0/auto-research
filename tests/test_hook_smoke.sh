#!/usr/bin/env bash
# tests/test_hook_smoke.sh — post-experiment-log.sh への dummy 入力で events.jsonl が出るか
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="${ROOT}/hooks/post-experiment-log.sh"
TMP=$(mktemp -d)
trap 'rm -rf "${TMP}"' EXIT

cd "${TMP}"
bash "${ROOT}/scripts/init_state.sh" hook-smoke-test >/dev/null
mkdir -p ".research/hook-smoke-test/06_RUNS/20260509-120000-aaaaaaa-bbbbbb"

# Case 1: uv run コマンドが events.jsonl に append される
INPUT=$(jq -nc \
  --arg cmd 'uv run python -m foo.train' \
  '{tool_name:"Bash", tool_input:{command:$cmd, description:"test"},
    tool_response:{output:"step 1 loss 0.5", exit_code:0, duration_ms:1234}}')
echo "${INPUT}" | bash "${HOOK}"

EVENTS=".research/hook-smoke-test/06_RUNS/20260509-120000-aaaaaaa-bbbbbb/events.jsonl"
if [[ ! -f "${EVENTS}" ]]; then
  echo "✗ events.jsonl was not created" >&2; exit 1
fi
LINES=$(wc -l < "${EVENTS}")
[[ ${LINES} -ge 1 ]] || { echo "✗ events.jsonl is empty" >&2; exit 1; }

# 必須フィールド全部含むか
LAST=$(tail -n1 "${EVENTS}")
for field in event level ts run_id duration_ms exit_code cmd git_rev; do
  echo "${LAST}" | jq -e ".${field}" >/dev/null 2>&1 \
    || { echo "✗ missing field: ${field}" >&2; exit 1; }
done

# Case 2: ls (uv run でない) は events.jsonl に append されないこと
LINES_BEFORE=${LINES}
INPUT2=$(jq -nc \
  --arg cmd 'ls -la' \
  '{tool_name:"Bash", tool_input:{command:$cmd, description:"unrelated"},
    tool_response:{output:"file1 file2", exit_code:0, duration_ms:5}}')
echo "${INPUT2}" | bash "${HOOK}"
LINES_AFTER=$(wc -l < "${EVENTS}")
[[ ${LINES_AFTER} -eq ${LINES_BEFORE} ]] \
  || { echo "✗ non-uv-run command should not be logged" >&2; exit 1; }

echo "hook smoke test: pass (uv run logged, non-uv-run filtered)"
