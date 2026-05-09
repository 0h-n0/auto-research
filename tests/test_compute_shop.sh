#!/usr/bin/env bash
# tests/test_compute_shop.sh — gpu_providers.json と compute_shop.py の smoke test
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CATALOG="${ROOT}/skills/research.compute.shop/references/gpu_providers.json"
COMPUTE_SHOP="${ROOT}/skills/research.compute.shop/references/compute_shop.py.txt"

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq required" >&2; exit 2
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 required" >&2; exit 2
fi

PASS=0
FAIL=0

# 1. JSON valid
if jq -e . "${CATALOG}" >/dev/null 2>&1; then
  PASS=$((PASS+1))
else
  echo "✗ catalog JSON invalid" >&2; FAIL=$((FAIL+1))
fi

# 2. >= 12 providers
N=$(jq '.providers | length' "${CATALOG}")
if [[ ${N} -ge 12 ]]; then
  PASS=$((PASS+1))
else
  echo "✗ catalog has only ${N} providers (require >= 12)" >&2
  FAIL=$((FAIL+1))
fi

# 3. Required fields per provider
MISSING=$(jq -r '.providers[] | select(.id == null or .name == null or .pricing_url == null or .gpus == null or (.gpus | type) != "object" or .best_for == null or .caveats == null) | .id // "<no-id>"' "${CATALOG}")
if [[ -z "${MISSING}" ]]; then
  PASS=$((PASS+1))
else
  echo "✗ providers missing required fields: ${MISSING}" >&2
  FAIL=$((FAIL+1))
fi

# 4. updated_at not too old (warn-only here, fail at 365 days)
UPD=$(jq -r '.updated_at' "${CATALOG}")
if [[ "${UPD}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  PASS=$((PASS+1))
  AGE=$(( ( $(date +%s) - $(date -d "${UPD}" +%s) ) / 86400 ))
  if [[ ${AGE} -gt 365 ]]; then
    echo "✗ catalog updated_at is ${AGE} days old (>365)" >&2; FAIL=$((FAIL+1))
  fi
else
  echo "✗ catalog updated_at format invalid: ${UPD}" >&2; FAIL=$((FAIL+1))
fi

# 5. python smoke test (A100 24h)
OUT=$(python3 "${COMPUTE_SHOP}" --gpu-type A100-80GB-SXM --gpu-count 1 --hours 24 \
  --max-usd-per-hour 5.0 --catalog "${CATALOG}" 2>/dev/null)
if echo "${OUT}" | grep -q "Top commercial options"; then
  PASS=$((PASS+1))
else
  echo "✗ compute_shop.py did not produce expected output" >&2; FAIL=$((FAIL+1))
fi

# 6. prefer_spot changes ranking
OUT_NORMAL=$(python3 "${COMPUTE_SHOP}" --gpu-type A100-80GB-SXM --gpu-count 1 --hours 24 --catalog "${CATALOG}" 2>/dev/null | grep '^| 1 |' | head -n1)
OUT_SPOT=$(python3 "${COMPUTE_SHOP}" --gpu-type A100-80GB-SXM --gpu-count 1 --hours 24 --prefer-spot --catalog "${CATALOG}" 2>/dev/null | grep '^| 1 |' | head -n1)
if [[ "${OUT_NORMAL}" != "${OUT_SPOT}" ]]; then
  PASS=$((PASS+1))
else
  echo "✗ prefer-spot did not change top recommendation" >&2; FAIL=$((FAIL+1))
fi

# 7. unknown gpu_type returns fuzzy candidates
UNKNOWN=$(python3 "${COMPUTE_SHOP}" --gpu-type WeirdGPU --gpu-count 1 --hours 1 --catalog "${CATALOG}" 2>/dev/null)
if echo "${UNKNOWN}" | grep -q "unknown gpu_type"; then
  PASS=$((PASS+1))
else
  echo "✗ unknown gpu_type did not produce a fuzzy hint" >&2; FAIL=$((FAIL+1))
fi

# 8. include-academic adds academic section
OUT_ACAD=$(python3 "${COMPUTE_SHOP}" --gpu-type A100-80GB --gpu-count 1 --hours 24 --include-academic --catalog "${CATALOG}" 2>/dev/null)
if echo "${OUT_ACAD}" | grep -q "Academic options"; then
  PASS=$((PASS+1))
else
  echo "✗ include-academic did not produce 'Academic options' section" >&2; FAIL=$((FAIL+1))
fi

echo "compute_shop test: ${PASS} pass / ${FAIL} fail"
[[ ${FAIL} -eq 0 ]] && exit 0 || exit 1
