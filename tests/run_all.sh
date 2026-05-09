#!/usr/bin/env bash
# tests/run_all.sh — 全 test スクリプトを順番に実行
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

PASS=0
FAIL=0
FAILED=()
for t in tests/test_*.sh; do
  name=$(basename "$t")
  echo "── running: ${name}"
  if bash "$t"; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    FAILED+=("${name}")
  fi
  echo
done

echo "═══════════════════════════════"
echo "TOTAL: ${PASS} pass / ${FAIL} fail"
if [[ ${FAIL} -gt 0 ]]; then
  printf '  ✗ %s\n' "${FAILED[@]}" >&2
  exit 1
fi
exit 0
