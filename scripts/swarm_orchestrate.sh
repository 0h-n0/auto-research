#!/usr/bin/env bash
# scripts/swarm_orchestrate.sh — swarm 全 agent の BEST.json を集約し SHARED_BEST.json を更新
#
# Usage:
#   bash scripts/swarm_orchestrate.sh <slug>
#
# Run periodically (cron 1h, or manually). Uses flock to prevent concurrent runs.
#
# Reads:
#   .research/<slug>/swarm/MANIFEST.json
#   .research/<slug>/swarm/agent_*/tinker/BEST.json
#   .research/<slug>/swarm/agent_*/tinker/RESULTS.md
#
# Writes:
#   .research/<slug>/swarm/SHARED_BEST.json
#   .research/<slug>/swarm/SWARM_RESULTS.md
#   .research/<slug>/swarm/best_train.py  (snapshot of winner's best train.py)
#
# Inspired by the multi-agent research org idea in karpathy/autoresearch
# (https://github.com/karpathy/autoresearch). See SKILL.md for attribution.

set -euo pipefail

SLUG="${1:?Usage: $0 <slug>}"
PROJECT_DIR=".research/${SLUG}"
SWARM_DIR="${PROJECT_DIR}/swarm"

if [[ ! -d "${SWARM_DIR}" ]]; then
  echo "ERROR: ${SWARM_DIR} not found. Run swarm_init.sh first." >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq required" >&2; exit 2
fi

LOCK_FILE="${SWARM_DIR}/orchestrator.lock"
exec 9>"${LOCK_FILE}"
if ! flock -n 9; then
  echo "[swarm_orchestrate] another orchestrator is running, skipping." >&2
  exit 0
fi

MANIFEST="${SWARM_DIR}/MANIFEST.json"
if [[ ! -f "${MANIFEST}" ]]; then
  echo "ERROR: ${MANIFEST} missing" >&2; exit 1
fi

NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
N_AGENTS=$(jq -r '.n_agents' "${MANIFEST}")

# Collect each agent's BEST.json
declare -a AGENT_IDS=()
declare -A AGENT_STRATEGY=()
declare -A AGENT_VAL_BPB=()
declare -A AGENT_ITER=()
declare -A AGENT_PATH=()
declare -A AGENT_ITERS_DONE=()

while IFS= read -r line; do
  AID=$(echo "$line" | jq -r '.id')
  STRAT=$(echo "$line" | jq -r '.strategy')
  WS="${PROJECT_DIR}/$(echo "$line" | jq -r '.workspace')"
  AGENT_IDS+=("${AID}")
  AGENT_STRATEGY["${AID}"]="${STRAT}"

  if [[ -f "${WS}/BEST.json" ]]; then
    BPB=$(jq -r '.val_bpb // "null"' "${WS}/BEST.json")
    ITR=$(jq -r '.iter // -1' "${WS}/BEST.json")
    PTH=$(jq -r '.config_snapshot_path // ""' "${WS}/BEST.json")
    AGENT_VAL_BPB["${AID}"]="${BPB}"
    AGENT_ITER["${AID}"]="${ITR}"
    AGENT_PATH["${AID}"]="${PTH}"
  else
    AGENT_VAL_BPB["${AID}"]="null"
    AGENT_ITER["${AID}"]="-1"
    AGENT_PATH["${AID}"]=""
  fi

  if [[ -f "${WS}/RESULTS.md" ]]; then
    AGENT_ITERS_DONE["${AID}"]=$(awk '/^\| [0-9]+ +\|/ {n++} END {print n+0}' "${WS}/RESULTS.md")
  else
    AGENT_ITERS_DONE["${AID}"]=0
  fi
done < <(jq -c '.agents[]' "${MANIFEST}")

# Find global winner (lowest val_bpb among non-null)
WIN_AID=""
WIN_BPB=""
for aid in "${AGENT_IDS[@]}"; do
  bpb="${AGENT_VAL_BPB[$aid]}"
  [[ "${bpb}" == "null" ]] && continue
  if [[ -z "${WIN_BPB}" ]] || awk "BEGIN {exit !(${bpb} < ${WIN_BPB})}"; then
    WIN_BPB="${bpb}"
    WIN_AID="${aid}"
  fi
done

# Write SHARED_BEST.json (atomic via mv)
TMP_SHARED=$(mktemp "${SWARM_DIR}/.SHARED_BEST.XXXXXX.json")
{
  echo "{"
  echo "  \"schema_version\": 1,"
  echo "  \"consensus_at\": \"${NOW}\","
  if [[ -n "${WIN_AID}" ]]; then
    WIN_STRAT="${AGENT_STRATEGY[$WIN_AID]}"
    WIN_ITER="${AGENT_ITER[$WIN_AID]}"
    WIN_PTH_REL="${AGENT_PATH[$WIN_AID]}"
    # absolute path to winner's snapshot
    WIN_PTH_ABS="${PROJECT_DIR}/swarm/${WIN_AID}/tinker/${WIN_PTH_REL#tinker/}"
    if [[ ! -f "${WIN_PTH_ABS}" ]]; then
      # Older agents may have stored relative to project root rather than tinker
      WIN_PTH_ABS="${PROJECT_DIR}/${WIN_PTH_REL}"
    fi
    SHA="$(sha256sum "${WIN_PTH_ABS}" 2>/dev/null | cut -c1-16 || echo unknown)"
    echo "  \"winner_agent_id\": \"${WIN_AID}\","
    echo "  \"winner_strategy\": \"${WIN_STRAT}\","
    echo "  \"iter_in_agent\": ${WIN_ITER},"
    echo "  \"val_bpb\": ${WIN_BPB},"
    echo "  \"config_snapshot_path\": \"swarm/${WIN_AID}/tinker/${WIN_PTH_REL#tinker/}\","
    echo "  \"config_sha256\": \"${SHA}\","
    echo "  \"best_train_py_path\": \"swarm/best_train.py\","
  else
    echo "  \"winner_agent_id\": null,"
    echo "  \"winner_strategy\": null,"
    echo "  \"iter_in_agent\": -1,"
    echo "  \"val_bpb\": null,"
    echo "  \"config_snapshot_path\": null,"
    echo "  \"config_sha256\": null,"
    echo "  \"best_train_py_path\": null,"
  fi
  echo "  \"agents_summary\": ["
  cnt=0
  for aid in "${AGENT_IDS[@]}"; do
    cnt=$((cnt + 1))
    sep=","; [[ ${cnt} -eq ${#AGENT_IDS[@]} ]] && sep=""
    echo "    {\"id\":\"${aid}\",\"strategy\":\"${AGENT_STRATEGY[$aid]}\",\"best_val_bpb\":${AGENT_VAL_BPB[$aid]},\"iter\":${AGENT_ITER[$aid]},\"iters_completed\":${AGENT_ITERS_DONE[$aid]}}${sep}"
  done
  echo "  ]"
  echo "}"
} > "${TMP_SHARED}"
mv "${TMP_SHARED}" "${SWARM_DIR}/SHARED_BEST.json"

# Snapshot best_train.py
if [[ -n "${WIN_AID}" ]]; then
  WIN_PTH_REL="${AGENT_PATH[$WIN_AID]}"
  WIN_PTH_ABS="${PROJECT_DIR}/swarm/${WIN_AID}/tinker/${WIN_PTH_REL#tinker/}"
  if [[ -f "${WIN_PTH_ABS}" ]]; then
    cp "${WIN_PTH_ABS}" "${SWARM_DIR}/best_train.py"
  fi
fi

# Generate SWARM_RESULTS.md
TMP_MD=$(mktemp "${SWARM_DIR}/.SWARM_RESULTS.XXXXXX.md")
{
  echo "# Swarm Results — ${SLUG}"
  echo ""
  echo "Last consensus: ${NOW}"
  echo ""
  echo "## Global Best"
  if [[ -n "${WIN_AID}" ]]; then
    echo "- Winner: ${WIN_AID} (${AGENT_STRATEGY[$WIN_AID]}) at iter ${AGENT_ITER[$WIN_AID]}, val_bpb=${WIN_BPB}"
    echo "- Snapshot: \`swarm/${WIN_AID}/tinker/${AGENT_PATH[$WIN_AID]#tinker/}\`"
    echo "- Best train.py: \`swarm/best_train.py\`"
  else
    echo "- (no successful iterations yet)"
  fi
  echo ""
  echo "## Per-agent best"
  echo ""
  echo "| agent_id | strategy | best val_bpb | best iter | iters completed |"
  echo "|----------|----------|--------------|-----------|-----------------|"
  for aid in "${AGENT_IDS[@]}"; do
    echo "| ${aid} | ${AGENT_STRATEGY[$aid]} | ${AGENT_VAL_BPB[$aid]} | ${AGENT_ITER[$aid]} | ${AGENT_ITERS_DONE[$aid]} |"
  done
  echo ""
  echo "## How to use the global best"
  echo ""
  echo "- For inspiration only: cat \`swarm/best_train.py\`"
  echo "- Per-agent rules in \`swarm/<agent_id>/tinker/program.md\` decide whether to cross-pollinate."
} > "${TMP_MD}"
mv "${TMP_MD}" "${SWARM_DIR}/SWARM_RESULTS.md"

# Append swarm.consensus event to events.jsonl (best-effort: pick latest run dir)
LATEST_RUN=$(ls -1td "${PROJECT_DIR}/06_RUNS"/*/ 2>/dev/null | head -n1 || true)
if [[ -n "${LATEST_RUN}" ]]; then
  EVENTS="${LATEST_RUN%/}/events.jsonl"
  if [[ -n "${WIN_AID}" ]]; then
    jq -nc --arg ts "${NOW}" \
           --arg run_id "$(basename "${LATEST_RUN%/}")" \
           --arg win "${WIN_AID}" \
           --arg strat "${AGENT_STRATEGY[$WIN_AID]}" \
           --argjson iter "${AGENT_ITER[$WIN_AID]}" \
           --argjson bpb "${WIN_BPB}" \
      '{event:"swarm.consensus", level:"info", ts:$ts, run_id:$run_id,
        duration_ms:0, winner_agent:$win, winner_strategy:$strat,
        winner_iter:$iter, global_best_val_bpb:$bpb}' \
      >> "${EVENTS}" 2>/dev/null || true
  fi
fi

echo "[swarm_orchestrate] consensus updated"
if [[ -n "${WIN_AID}" ]]; then
  echo "  winner: ${WIN_AID} (${AGENT_STRATEGY[$WIN_AID]})  val_bpb=${WIN_BPB}"
else
  echo "  winner: none (no successful iterations yet)"
fi
echo "  results: ${SWARM_DIR}/SWARM_RESULTS.md"
