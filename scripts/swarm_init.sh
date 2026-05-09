#!/usr/bin/env bash
# scripts/swarm_init.sh — N agents の swarm workspace を一括 scaffold
#
# Usage:
#   bash scripts/swarm_init.sh <slug> [--agents N] [--strategies a,b,c] [--allow-duplicate]
#
# Default:
#   --agents 3 (depth-explore, lr-explore, arch-explore)
#   --agents 5 (上記 + batch-explore + random-restart)
#
# Available strategies: depth-explore, lr-explore, arch-explore, batch-explore, random-restart
#
# What it does:
#   1. Validates strategies
#   2. For each agent:
#        a. Creates .research/<slug>/swarm/agent_<id>/tinker/ via standard tinker scaffold
#        b. Replaces program.md with the strategy-specific template
#        c. Substitutes <agent_id> and <slug> placeholders
#   3. Symlinks agent_2..N's data/ to agent_1/data/ (saves storage)
#   4. Writes a swarm/MANIFEST.json describing the swarm
#
# Inspired by the multi-agent extension implied in karpathy/autoresearch's README
# (https://github.com/karpathy/autoresearch). See SKILL.md for full attribution.

set -euo pipefail

SLUG=""
AGENTS=3
STRATEGIES=""
ALLOW_DUP=0
DOMAIN="lm-pretrain"   # v0.11.0+; default keeps backward compat

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agents) AGENTS="$2"; shift 2 ;;
    --strategies) STRATEGIES="$2"; shift 2 ;;
    --allow-duplicate) ALLOW_DUP=1; shift ;;
    --domain) DOMAIN="$2"; shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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
  echo "Usage: $0 <slug> [--agents N] [--strategies a,b,c] [--allow-duplicate] [--domain D]" >&2
  exit 2
fi

# Validate domain (v0.11.0+)
case "${DOMAIN}" in
  lm-pretrain|vision-classification|rl-cartpole|tabular-classification) ;;
  *)
    echo "ERROR: unknown domain '${DOMAIN}'." >&2
    echo "Available: lm-pretrain (default), vision-classification, rl-cartpole, tabular-classification" >&2
    exit 2
    ;;
esac

PROJECT_DIR=".research/${SLUG}"
if [[ ! -d "${PROJECT_DIR}" ]]; then
  echo "ERROR: ${PROJECT_DIR} not found. Run /auto-research:research-start first." >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TINKER_REFS="${ROOT}/skills/research.autonomous.tinker/references"
SWARM_REFS="${ROOT}/skills/research.autonomous.swarm/references"

# Resolve strategies
ALL_STRATEGIES=("depth-explore" "lr-explore" "arch-explore" "batch-explore" "random-restart")
if [[ -z "${STRATEGIES}" ]]; then
  case "${AGENTS}" in
    1) STRATEGIES="depth-explore" ;;
    2) STRATEGIES="depth-explore,lr-explore" ;;
    3) STRATEGIES="depth-explore,lr-explore,arch-explore" ;;
    4) STRATEGIES="depth-explore,lr-explore,arch-explore,batch-explore" ;;
    5) STRATEGIES="depth-explore,lr-explore,arch-explore,batch-explore,random-restart" ;;
    *)
      if [[ ${AGENTS} -gt 5 ]] && [[ ${ALLOW_DUP} -eq 1 ]]; then
        STRATEGIES=$(printf '%s,' "${ALL_STRATEGIES[@]}")
        # Repeat to fill
        EXTRA=$((AGENTS - 5))
        for ((i=0; i<EXTRA; i++)); do
          STRATEGIES="${STRATEGIES}${ALL_STRATEGIES[$((i % 5))]},"
        done
        STRATEGIES="${STRATEGIES%,}"
      else
        echo "ERROR: --agents > 5 requires --strategies (or --allow-duplicate to repeat)" >&2
        exit 2
      fi
      ;;
  esac
fi

IFS=',' read -r -a STRAT_ARR <<< "${STRATEGIES}"
if [[ ${#STRAT_ARR[@]} -ne ${AGENTS} ]]; then
  echo "ERROR: --agents=${AGENTS} but --strategies has ${#STRAT_ARR[@]} entries" >&2
  exit 2
fi

# Validate strategies
for s in "${STRAT_ARR[@]}"; do
  ok=0
  for a in "${ALL_STRATEGIES[@]}"; do
    [[ "$s" == "$a" ]] && ok=1
  done
  if [[ ${ok} -eq 0 ]]; then
    echo "ERROR: unknown strategy '${s}'. Available: ${ALL_STRATEGIES[*]}" >&2
    exit 2
  fi
done

# Check duplicates
if [[ ${ALLOW_DUP} -eq 0 ]]; then
  uniq_count=$(printf '%s\n' "${STRAT_ARR[@]}" | sort -u | wc -l)
  if [[ ${uniq_count} -ne ${AGENTS} ]]; then
    echo "ERROR: duplicate strategies (use --allow-duplicate if intended)" >&2
    exit 2
  fi
fi

SWARM_DIR="${PROJECT_DIR}/swarm"
mkdir -p "${SWARM_DIR}"

# Substitute placeholders helper
subst() {
  # $1=src $2=dst $3=agent_id
  sed -e "s|<agent_id>|$3|g" -e "s|<slug>|${SLUG}|g" "$1" > "$2"
}

echo "=== auto-research swarm init ==="
echo "Slug:       ${SLUG}"
echo "Domain:     ${DOMAIN}"
echo "Agents:     ${AGENTS}"
echo "Strategies: ${STRATEGIES}"
echo ""

# Scaffold each agent
for ((i=1; i<=AGENTS; i++)); do
  STRAT="${STRAT_ARR[$((i-1))]}"
  AGENT_ID="agent_${i}"
  AGENT_DIR="${SWARM_DIR}/${AGENT_ID}/tinker"
  mkdir -p "${AGENT_DIR}/history"

  # Copy tinker templates (rename .py.txt -> .py for executable files).
  # v0.11.0+: domain selects template source. lm-pretrain stays at top-level for
  # backward compat; other domains live under references/domains/<name>/.
  if [[ "${DOMAIN}" == "lm-pretrain" ]]; then
    cp "${TINKER_REFS}/train_py_template.py.txt" "${AGENT_DIR}/train.py"
    cp "${TINKER_REFS}/prepare_py_template.py.txt" "${AGENT_DIR}/prepare.py"
    cp "${TINKER_REFS}/tinker_pyproject_template.toml" "${AGENT_DIR}/pyproject.toml"
  else
    DOMAIN_DIR="${TINKER_REFS}/domains/${DOMAIN}"
    cp "${DOMAIN_DIR}/train.py.txt" "${AGENT_DIR}/train.py"
    cp "${DOMAIN_DIR}/prepare.py.txt" "${AGENT_DIR}/prepare.py"
    cp "${DOMAIN_DIR}/pyproject.toml" "${AGENT_DIR}/pyproject.toml"
  fi

  # Strategy-specific program.md (substitute placeholders)
  STRAT_KEY="${STRAT//-/_}"  # depth-explore -> depth_explore
  PROGRAM_SRC="${SWARM_REFS}/program_${STRAT_KEY}.md"
  if [[ ! -f "${PROGRAM_SRC}" ]]; then
    echo "ERROR: program template missing: ${PROGRAM_SRC}" >&2
    exit 1
  fi
  subst "${PROGRAM_SRC}" "${AGENT_DIR}/program.md" "${AGENT_ID}"

  # data/ symlink (agent_1 will create the actual data/ via prepare.py)
  if [[ ${i} -gt 1 ]]; then
    ln -sfn "../../agent_1/tinker/data" "${AGENT_DIR}/data"
  fi

  echo "  ✓ ${AGENT_ID}  strategy=${STRAT}  workspace=${AGENT_DIR}"
done

# Write MANIFEST.json
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
{
  echo "{"
  echo "  \"schema_version\": 1,"
  echo "  \"slug\": \"${SLUG}\","
  echo "  \"created_at\": \"${NOW}\","
  echo "  \"domain\": \"${DOMAIN}\","
  echo "  \"n_agents\": ${AGENTS},"
  echo "  \"agents\": ["
  for ((i=1; i<=AGENTS; i++)); do
    STRAT="${STRAT_ARR[$((i-1))]}"
    sep=","; [[ ${i} -eq ${AGENTS} ]] && sep=""
    echo "    {\"id\": \"agent_${i}\", \"strategy\": \"${STRAT}\", \"workspace\": \"swarm/agent_${i}/tinker\"}${sep}"
  done
  echo "  ]"
  echo "}"
} > "${SWARM_DIR}/MANIFEST.json"

echo ""
echo "── Manifest ──"
cat "${SWARM_DIR}/MANIFEST.json"
echo ""
echo "── Next steps ──"
echo "  1. Prepare data once (in agent_1):"
echo "     cd ${PROJECT_DIR}/swarm/agent_1/tinker && uv sync && uv run python prepare.py"
echo "  2. Launch each agent (separate Claude Code sessions or parallel Tasks):"
for ((i=1; i<=AGENTS; i++)); do
  if [[ "${DOMAIN}" == "lm-pretrain" ]]; then
    echo "     bash scripts/tinker_run.sh ${SLUG} --workspace swarm/agent_${i}/tinker"
  else
    echo "     bash scripts/tinker_run.sh ${SLUG} --workspace swarm/agent_${i}/tinker --domain ${DOMAIN}"
  fi
done
echo "  3. Periodically aggregate (cron 1h or manual):"
echo "     bash scripts/swarm_orchestrate.sh ${SLUG}"
