#!/usr/bin/env bash
# scripts/tinker_run.sh — autonomous tinker mode runner (v0.9.0+)
#
# Usage:
#   bash scripts/tinker_run.sh <slug> [--budget N]
#
# Runs `tinker/train.py` with a strict wall-clock timeout, parses
# `tinker/result.json`, appends one JSON line to events.jsonl, updates
# `tinker/RESULTS.md` and `tinker/BEST.json`, and snapshots train.py
# under `tinker/history/`.
#
# Inspired by karpathy/autoresearch (https://github.com/karpathy/autoresearch, MIT, 2026).
# See skills/research.autonomous.tinker/SKILL.md for full attribution.

set -uo pipefail

SLUG=""
BUDGET="${TINKER_BUDGET_SECONDS:-300}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --budget) BUDGET="$2"; shift 2 ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      if [[ -z "${SLUG}" ]]; then
        SLUG="$1"; shift
      else
        echo "ERROR: unexpected arg: $1" >&2; exit 2
      fi
      ;;
  esac
done

if [[ -z "${SLUG}" ]]; then
  echo "Usage: $0 <slug> [--budget N]" >&2
  exit 2
fi

PROJECT_DIR=".research/${SLUG}"
TINKER_DIR="${PROJECT_DIR}/tinker"

if [[ ! -d "${TINKER_DIR}" ]]; then
  echo "ERROR: ${TINKER_DIR} not found. Run research.autonomous.tinker scaffold first." >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq required" >&2; exit 2
fi

# Resolve / create a 06_RUNS/<run_id>/ for this iteration's events.jsonl
mkdir -p "${PROJECT_DIR}/06_RUNS"
LATEST_RUN=$(ls -1td "${PROJECT_DIR}/06_RUNS"/*/ 2>/dev/null | head -n1 || true)
if [[ -z "${LATEST_RUN}" || "$(basename "${LATEST_RUN%/}")" == "preflight" ]]; then
  TS=$(date -u +"%Y%m%d-%H%M%S")
  GIT_REV="$(git -C "${TINKER_DIR}" rev-parse HEAD 2>/dev/null || echo unknown)"
  GIT_REV_SHORT="${GIT_REV:0:7}"
  if [[ -z "${GIT_REV_SHORT}" || "${GIT_REV_SHORT}" == "unknown" ]]; then
    GIT_REV_SHORT="0000000"
  fi
  HASH=$(sha256sum "${TINKER_DIR}/train.py" 2>/dev/null | cut -c1-6)
  HASH="${HASH:-aaaaaa}"
  RUN_ID="${TS}-${GIT_REV_SHORT}-${HASH}"
  RUN_DIR="${PROJECT_DIR}/06_RUNS/${RUN_ID}"
  mkdir -p "${RUN_DIR}"
  echo "started" > "${RUN_DIR}/STATUS"
else
  RUN_DIR="${LATEST_RUN%/}"
  RUN_ID="$(basename "${RUN_DIR}")"
fi
EVENTS="${RUN_DIR}/events.jsonl"
mkdir -p "${TINKER_DIR}/history"

# Determine iter number from RESULTS.md
ITER=0
if [[ -f "${TINKER_DIR}/RESULTS.md" ]]; then
  ITER=$(awk '/^\| [0-9]+ +\|/ {n++} END {print n+0}' "${TINKER_DIR}/RESULTS.md")
fi

ts_now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

emit_event_jsonl() {
  # $1 = JSON object string
  echo "$1" >> "${EVENTS}"
}

append_results_row() {
  # $1=iter $2=wall $3=val_bpb $4=best $5=diff $6=status $7=notes
  local file="${TINKER_DIR}/RESULTS.md"
  if [[ ! -f "${file}" ]]; then
    {
      echo "# Tinker Results — ${SLUG}"
      echo
      echo "| iter | wall_time_s | val_bpb | best so far | diff | status | notes |"
      echo "|------|-------------|---------|-------------|------|--------|-------|"
    } > "${file}"
  fi
  echo "| $1 | $2 | $3 | $4 | $5 | $6 | $7 |" >> "${file}"
}

current_best_val_bpb() {
  if [[ -f "${TINKER_DIR}/BEST.json" ]]; then
    jq -r '.val_bpb // "null"' "${TINKER_DIR}/BEST.json"
  else
    echo "null"
  fi
}

# 1. Pre-flight: syntax + forbidden imports
SYNTAX_OK=1
SYNTAX_ERR=""
if ! python3 -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" "${TINKER_DIR}/train.py" 2>/tmp/_tinker_syntax_err; then
  SYNTAX_OK=0
  SYNTAX_ERR=$(tr -d '\n' </tmp/_tinker_syntax_err | head -c 400)
fi

if [[ ${SYNTAX_OK} -eq 0 ]]; then
  TS=$(ts_now)
  EVT=$(jq -nc \
    --arg event "tinker.diverged" --arg level "error" --arg ts "${TS}" \
    --arg run_id "${RUN_ID}" --argjson duration_ms 0 --argjson iter "${ITER}" \
    --arg status "syntax_error" --arg etype "SyntaxError" \
    --arg emsg "${SYNTAX_ERR}" \
    '{event:$event, level:$level, ts:$ts, run_id:$run_id, duration_ms:$duration_ms,
      iter:$iter, status:$status, reason:"SyntaxError in train.py",
      error_type:$etype, error_message:$emsg}')
  emit_event_jsonl "${EVT}"
  append_results_row "${ITER}" "0" "null" "$(current_best_val_bpb)" "n/a" "syntax_error" "${SYNTAX_ERR:0:80}"
  echo "[tinker_run] ✗ syntax_error in train.py (iter ${ITER}). See ${EVENTS}." >&2
  exit 1
fi

# Forbidden imports (very simple grep — enough to block obvious cheating)
if grep -E '^(from|import)\s+(transformers|tokenizers|sentence_transformers)' \
     "${TINKER_DIR}/train.py" >/dev/null 2>&1; then
  TS=$(ts_now)
  REASON="forbidden import: pretrained models are not allowed"
  EVT=$(jq -nc \
    --arg event "tinker.diverged" --arg level "error" --arg ts "${TS}" \
    --arg run_id "${RUN_ID}" --argjson duration_ms 0 --argjson iter "${ITER}" \
    --arg status "forbidden" --arg reason "${REASON}" \
    --arg etype "PolicyViolation" --arg emsg "${REASON}" \
    '{event:$event, level:$level, ts:$ts, run_id:$run_id, duration_ms:$duration_ms,
      iter:$iter, status:$status, reason:$reason,
      error_type:$etype, error_message:$emsg}')
  emit_event_jsonl "${EVT}"
  append_results_row "${ITER}" "0" "null" "$(current_best_val_bpb)" "n/a" "forbidden" "transformers/tokenizers detected"
  echo "[tinker_run] ✗ forbidden import (iter ${ITER}). See ${EVENTS}." >&2
  exit 1
fi

# Snapshot train.py before running (always, for reproducibility / revert)
cp "${TINKER_DIR}/train.py" "${TINKER_DIR}/history/iter_${ITER}_pre.py"

# 2. Run with timeout
START=$(date +%s)
TINKER_BUDGET_SECONDS="${BUDGET}" timeout --kill-after=10 "${BUDGET}s" \
  bash -c "cd '${TINKER_DIR}' && python3 train.py" >"${RUN_DIR}/train_stdout.txt" 2>"${RUN_DIR}/train_stderr.txt"
EXIT=$?
END=$(date +%s)
DUR_MS=$(( (END - START) * 1000 ))

# 3. Parse result.json (or detect failure)
RESULT_PATH="${TINKER_DIR}/result.json"
STATUS="ok"
VAL_BPB="null"
N_ITERS="0"
DIVERGED="false"
WALL="0"
NOTES=""

if [[ ${EXIT} -eq 137 ]]; then
  STATUS="oom"
elif [[ ${EXIT} -eq 124 || ${EXIT} -eq 143 ]]; then
  # timeout (124 from coreutils, 143 from SIGTERM elsewhere)
  STATUS="timeout"
fi

if [[ -f "${RESULT_PATH}" ]]; then
  VAL_BPB=$(jq -r '.val_bpb // "null"' "${RESULT_PATH}")
  N_ITERS=$(jq -r '.n_iters // 0' "${RESULT_PATH}")
  DIVERGED=$(jq -r '.diverged // false' "${RESULT_PATH}")
  WALL=$(jq -r '.wall_time_s // 0' "${RESULT_PATH}")
  if [[ "${DIVERGED}" == "true" ]]; then
    STATUS="diverged"
  fi
elif [[ "${STATUS}" == "ok" ]]; then
  # No result.json and we didn't time out → treat as runtime error
  STATUS="runtime_error"
fi

# 4. Compare with current best
BEST_BEFORE=$(current_best_val_bpb)
NEW_BEST="false"
DIFF="n/a"
if [[ "${VAL_BPB}" != "null" && "${STATUS}" == "ok" ]]; then
  if [[ "${BEST_BEFORE}" == "null" ]] || \
     awk "BEGIN {exit !(${VAL_BPB} < ${BEST_BEFORE})}"; then
    NEW_BEST="true"
    if [[ "${BEST_BEFORE}" != "null" ]]; then
      DIFF=$(awk "BEGIN {printf \"%+0.4f\", ${VAL_BPB} - ${BEST_BEFORE}}")
    else
      DIFF="—"
    fi
    cp "${TINKER_DIR}/train.py" "${TINKER_DIR}/history/iter_${ITER}.py"
    SHA=$(sha256sum "${TINKER_DIR}/history/iter_${ITER}.py" | cut -c1-16)
    jq -n --argjson iter "${ITER}" --argjson val_bpb "${VAL_BPB}" \
          --argjson wall "${WALL}" --argjson niters "${N_ITERS}" \
          --arg path "tinker/history/iter_${ITER}.py" --arg sha "${SHA}" \
          --arg ts "$(ts_now)" \
       '{iter:$iter, val_bpb:$val_bpb, wall_time_s:$wall, n_iters_train:$niters,
         config_snapshot_path:$path, config_sha256:$sha, recorded_at:$ts}' \
       > "${TINKER_DIR}/BEST.json"
  else
    DIFF=$(awk "BEGIN {printf \"%+0.4f\", ${VAL_BPB} - ${BEST_BEFORE}}")
  fi
fi

# 5. Update RESULTS.md
ROW_STATUS="${STATUS}"
[[ "${NEW_BEST}" == "true" ]] && ROW_STATUS="NEW BEST"
append_results_row "${ITER}" "${WALL}" "${VAL_BPB}" \
  "$(current_best_val_bpb)" "${DIFF}" "${ROW_STATUS}" "${NOTES}"

# 6. Append to events.jsonl
LEVEL="info"
EVENT_NAME="tinker.iteration"
case "${STATUS}" in
  diverged|oom|timeout|runtime_error|syntax_error|forbidden)
    LEVEL="warning"
    EVENT_NAME="tinker.diverged"
    ;;
esac
[[ "${LEVEL}" == "warning" && ( "${STATUS}" == "syntax_error" || "${STATUS}" == "forbidden" ) ]] && LEVEL="error"

if [[ "${LEVEL}" == "info" ]]; then
  jq -nc \
    --arg event "${EVENT_NAME}" --arg level "${LEVEL}" --arg ts "$(ts_now)" \
    --arg run_id "${RUN_ID}" --argjson duration_ms "${DUR_MS}" \
    --argjson iter "${ITER}" \
    --argjson val_bpb "${VAL_BPB}" --arg best "$(current_best_val_bpb)" \
    --arg diff "${DIFF}" --arg status "${ROW_STATUS}" \
    --argjson niters "${N_ITERS}" --argjson wall "${WALL}" \
    '{event:$event, level:$level, ts:$ts, run_id:$run_id, duration_ms:$duration_ms,
      iter:$iter, val_bpb:$val_bpb, best_val_bpb:($best | tonumber? // null),
      diff:$diff, status:$status, n_iters_train:$niters, wall_time_s:$wall}' \
    >> "${EVENTS}"
else
  REASON="${STATUS}"
  ERRMSG=$(tail -n 1 "${RUN_DIR}/train_stderr.txt" 2>/dev/null | head -c 400)
  jq -nc \
    --arg event "${EVENT_NAME}" --arg level "${LEVEL}" --arg ts "$(ts_now)" \
    --arg run_id "${RUN_ID}" --argjson duration_ms "${DUR_MS}" \
    --argjson iter "${ITER}" --arg status "${STATUS}" \
    --arg reason "${REASON}" --arg etype "TinkerRunError" \
    --arg emsg "${ERRMSG}" \
    '{event:$event, level:$level, ts:$ts, run_id:$run_id, duration_ms:$duration_ms,
      iter:$iter, status:$status, reason:$reason,
      error_type:$etype, error_message:$emsg}' \
    >> "${EVENTS}"
fi

# 7. Final summary
echo "[tinker_run] iter=${ITER} status=${ROW_STATUS} val_bpb=${VAL_BPB} best=$(current_best_val_bpb) diff=${DIFF} dur=${DUR_MS}ms"
exit 0
