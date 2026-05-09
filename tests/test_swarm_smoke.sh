#!/usr/bin/env bash
# tests/test_swarm_smoke.sh — research.autonomous.swarm の静的チェック + scaffold smoke
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_DIR="${ROOT}/skills/research.autonomous.swarm"
REFS="${SKILL_DIR}/references"

PASS=0
FAIL=0

# 1. Required files exist
for f in \
  "${SKILL_DIR}/SKILL.md" \
  "${REFS}/swarm_strategies.md" \
  "${REFS}/swarm_protocol.md" \
  "${REFS}/program_depth_explore.md" \
  "${REFS}/program_lr_explore.md" \
  "${REFS}/program_arch_explore.md" \
  "${REFS}/program_batch_explore.md" \
  "${REFS}/program_random_restart.md" \
  "${ROOT}/scripts/swarm_init.sh" \
  "${ROOT}/scripts/swarm_orchestrate.sh"
do
  if [[ -f "$f" ]]; then
    PASS=$((PASS+1))
  else
    echo "✗ missing: $f" >&2; FAIL=$((FAIL+1))
  fi
done

# 2. Bash syntax
for s in scripts/swarm_init.sh scripts/swarm_orchestrate.sh; do
  if bash -n "${ROOT}/${s}" 2>/dev/null; then
    PASS=$((PASS+1))
  else
    echo "✗ ${s} bash syntax invalid" >&2; FAIL=$((FAIL+1))
  fi
done

# 3. Each program_*.md has the strategy name in the title
for strat in depth-explore lr-explore arch-explore batch-explore random-restart; do
  key="${strat//-/_}"
  file="${REFS}/program_${key}.md"
  if grep -qi "${strat} agent" "${file}" 2>/dev/null; then
    PASS=$((PASS+1))
  else
    echo "✗ ${file} missing strategy header for '${strat}'" >&2
    FAIL=$((FAIL+1))
  fi
done

# 4. karpathy attribution in SKILL.md and at least one of the protocol docs
if grep -q "karpathy/autoresearch" "${SKILL_DIR}/SKILL.md"; then
  PASS=$((PASS+1))
else
  echo "✗ SKILL.md missing karpathy attribution" >&2; FAIL=$((FAIL+1))
fi
if grep -q "karpathy/autoresearch" "${ROOT}/scripts/swarm_init.sh"; then
  PASS=$((PASS+1))
else
  echo "✗ swarm_init.sh missing karpathy attribution" >&2; FAIL=$((FAIL+1))
fi

# 5. End-to-end scaffold smoke (in a temp dir)
TMP=$(mktemp -d); trap 'rm -rf "${TMP}"' EXIT
cd "${TMP}"
bash "${ROOT}/scripts/init_state.sh" swarm-smoke >/dev/null
if bash "${ROOT}/scripts/swarm_init.sh" swarm-smoke --agents 3 >/dev/null 2>&1; then
  PASS=$((PASS+1))
else
  echo "✗ swarm_init.sh end-to-end smoke failed" >&2
  FAIL=$((FAIL+1))
fi

# 6. Manifest is valid JSON
if jq -e . .research/swarm-smoke/swarm/MANIFEST.json >/dev/null 2>&1; then
  PASS=$((PASS+1))
else
  echo "✗ MANIFEST.json invalid" >&2; FAIL=$((FAIL+1))
fi

# 7. Orchestrate runs without warning
ORCH=$(bash "${ROOT}/scripts/swarm_orchestrate.sh" swarm-smoke 2>&1)
if echo "${ORCH}" | grep -q "bad array subscript"; then
  echo "✗ orchestrator emits bash warnings" >&2; FAIL=$((FAIL+1))
else
  PASS=$((PASS+1))
fi

# 8. SHARED_BEST.json valid JSON
if jq -e . .research/swarm-smoke/swarm/SHARED_BEST.json >/dev/null 2>&1; then
  PASS=$((PASS+1))
else
  echo "✗ SHARED_BEST.json invalid" >&2; FAIL=$((FAIL+1))
fi

# 9. Invalid strategy is rejected
cd "${TMP}"
if bash "${ROOT}/scripts/swarm_init.sh" swarm-smoke --agents 1 --strategies nope 2>/dev/null; then
  echo "✗ swarm_init.sh accepted unknown strategy" >&2; FAIL=$((FAIL+1))
else
  PASS=$((PASS+1))
fi

# 10. Duplicate strategies rejected without --allow-duplicate
if bash "${ROOT}/scripts/swarm_init.sh" swarm-smoke --agents 2 --strategies depth-explore,depth-explore 2>/dev/null; then
  echo "✗ swarm_init.sh accepted duplicate strategies without --allow-duplicate" >&2
  FAIL=$((FAIL+1))
else
  PASS=$((PASS+1))
fi

echo "swarm_smoke test: ${PASS} pass / ${FAIL} fail"
[[ ${FAIL} -eq 0 ]] && exit 0 || exit 1
