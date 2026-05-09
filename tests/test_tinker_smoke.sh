#!/usr/bin/env bash
# tests/test_tinker_smoke.sh — autonomous tinker mode の静的チェック
#
# 1. 必要な template ファイルが存在
# 2. train.py / prepare.py の Python syntax が valid
# 3. tinker_run.sh の bash syntax が valid
# 4. tinker_pyproject_template.toml が TOML として読める
# 5. SKILL.md と train.py に karpathy attribution が含まれる
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_DIR="${ROOT}/skills/research.autonomous.tinker"
REFS="${SKILL_DIR}/references"

PASS=0
FAIL=0

for f in \
  "${SKILL_DIR}/SKILL.md" \
  "${REFS}/tinker_loop.md" \
  "${REFS}/program_md_template.md" \
  "${REFS}/train_py_template.py.txt" \
  "${REFS}/prepare_py_template.py.txt" \
  "${REFS}/results_log_format.md" \
  "${REFS}/tinker_pyproject_template.toml" \
  "${ROOT}/scripts/tinker_run.sh"
do
  if [[ -f "$f" ]]; then
    PASS=$((PASS+1))
  else
    echo "✗ missing: $f" >&2
    FAIL=$((FAIL+1))
  fi
done

TMP=$(mktemp -d); trap 'rm -rf "${TMP}"' EXIT
if cp "${REFS}/train_py_template.py.txt" "${TMP}/train.py" \
   && python3 -m py_compile "${TMP}/train.py" 2>/dev/null; then
  PASS=$((PASS+1))
else
  echo "✗ train.py template syntax invalid" >&2; FAIL=$((FAIL+1))
fi
if cp "${REFS}/prepare_py_template.py.txt" "${TMP}/prepare.py" \
   && python3 -m py_compile "${TMP}/prepare.py" 2>/dev/null; then
  PASS=$((PASS+1))
else
  echo "✗ prepare.py template syntax invalid" >&2; FAIL=$((FAIL+1))
fi

if bash -n "${ROOT}/scripts/tinker_run.sh" 2>/dev/null; then
  PASS=$((PASS+1))
else
  echo "✗ tinker_run.sh bash syntax invalid" >&2; FAIL=$((FAIL+1))
fi

if python3 -c 'import tomllib,sys; tomllib.load(open(sys.argv[1],"rb"))' \
     "${REFS}/tinker_pyproject_template.toml" 2>/dev/null; then
  PASS=$((PASS+1))
else
  echo "✗ tinker_pyproject_template.toml invalid TOML" >&2; FAIL=$((FAIL+1))
fi

if grep -q "karpathy/autoresearch" "${SKILL_DIR}/SKILL.md"; then
  PASS=$((PASS+1))
else
  echo "✗ SKILL.md missing karpathy attribution" >&2; FAIL=$((FAIL+1))
fi
if grep -q "karpathy/autoresearch" "${REFS}/train_py_template.py.txt"; then
  PASS=$((PASS+1))
else
  echo "✗ train_py_template.py.txt missing karpathy attribution" >&2; FAIL=$((FAIL+1))
fi
if grep -q "karpathy/autoresearch" "${ROOT}/scripts/tinker_run.sh"; then
  PASS=$((PASS+1))
else
  echo "✗ tinker_run.sh missing karpathy attribution" >&2; FAIL=$((FAIL+1))
fi

echo "tinker_smoke test: ${PASS} pass / ${FAIL} fail"
[[ ${FAIL} -eq 0 ]] && exit 0 || exit 1
