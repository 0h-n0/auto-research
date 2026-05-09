#!/usr/bin/env bash
# tests/test_strategy_adapters.sh — strategy × domain adapter doc structure (v0.12.0+)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ADAPTER="${ROOT}/skills/research.autonomous.swarm/references/strategy_adapters.md"

PASS=0
FAIL=0

if [[ -f "${ADAPTER}" ]]; then
  PASS=$((PASS+1))
else
  echo "✗ ${ADAPTER} missing" >&2
  FAIL=$((FAIL+1))
  exit 1
fi

for strat in depth-explore lr-explore arch-explore batch-explore random-restart; do
  if grep -qE "^## .*\`${strat}\`" "${ADAPTER}"; then
    PASS=$((PASS+1))
  else
    echo "✗ adapter doc missing strategy section for ${strat}" >&2
    FAIL=$((FAIL+1))
  fi
done

for domain in lm-pretrain vision-classification rl-cartpole tabular-classification nlp-classification; do
  count=$(grep -c "${domain}" "${ADAPTER}" || true)
  if [[ ${count} -ge 5 ]]; then
    PASS=$((PASS+1))
  else
    echo "✗ ${domain} mentioned only ${count} times (expected ≥5)" >&2
    FAIL=$((FAIL+1))
  fi
done

if grep -q "共通の不変条件" "${ADAPTER}"; then
  PASS=$((PASS+1))
else
  echo "✗ adapter doc missing 共通の不変条件 section" >&2
  FAIL=$((FAIL+1))
fi

if grep -q "forbidden imports" "${ADAPTER}"; then
  PASS=$((PASS+1))
else
  echo "✗ adapter doc missing forbidden imports invariant" >&2
  FAIL=$((FAIL+1))
fi

# random-restart section should have hparam ranges for multiple domains.
# Use a simpler heuristic: count "logU(" occurrences (used for log-uniform sampling ranges).
LOGU_COUNT=$(grep -c "logU(" "${ADAPTER}" || true)
if [[ ${LOGU_COUNT} -ge 4 ]]; then
  # Expect at least 4 of the 5 domains to define a logU range (lm/vision/rl/tabular/nlp).
  PASS=$((PASS+1))
else
  echo "✗ random-restart section seems incomplete: only ${LOGU_COUNT} logU ranges (expected ≥4)" >&2
  FAIL=$((FAIL+1))
fi

echo "strategy_adapters test: ${PASS} pass / ${FAIL} fail"
[[ ${FAIL} -eq 0 ]] && exit 0 || exit 1
