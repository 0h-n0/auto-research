#!/usr/bin/env bash
# tests/test_state_schema.sh — STATE.json fixtures が schema を満たすか検証
#
# 使い方: bash tests/test_state_schema.sh
# 終了 code: 0=pass, 非 0=fail
#
# 依存: jq, python3 + jsonschema (uv が使えるなら uv run --with jsonschema python ...)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEMA="${ROOT}/tests/schemas/state.schema.json"
FIXTURES_DIR="${ROOT}/tests/fixtures"

# jsonschema 検証は python の jsonschema ライブラリで実施。
# uv なら一時的に環境を作って実行できる。
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq not installed" >&2
  exit 2
fi

VALIDATOR=""
if command -v uv >/dev/null 2>&1; then
  VALIDATOR='uv run --quiet --with jsonschema python3'
elif python3 -c 'import jsonschema' 2>/dev/null; then
  VALIDATOR='python3'
else
  echo "WARN: jsonschema not available — skipping deep validation, only running jq syntax check" >&2
  VALIDATOR=''
fi

PASS=0
FAIL=0
ERRORS=()

for f in "${FIXTURES_DIR}"/state_*.json; do
  name=$(basename "$f")

  # 1. JSON syntactic validity
  if ! jq -e . "$f" >/dev/null 2>&1; then
    FAIL=$((FAIL+1))
    ERRORS+=("$name: invalid JSON")
    continue
  fi

  # 2. schema check (if jsonschema available)
  if [[ -n "$VALIDATOR" ]]; then
    if ! $VALIDATOR -c "
import json, sys
import jsonschema
schema = json.load(open('${SCHEMA}'))
data = json.load(open('${f}'))
try:
    jsonschema.validate(data, schema)
except jsonschema.ValidationError as e:
    print(f'{e.message} at \$.{\".\".join(str(p) for p in e.path)}', file=sys.stderr)
    sys.exit(1)
" 2>&1; then
      FAIL=$((FAIL+1))
      ERRORS+=("$name: schema validation failed")
      continue
    fi
  fi

  PASS=$((PASS+1))
done

echo "STATE.json schema test: ${PASS} pass / ${FAIL} fail"
if [[ ${FAIL} -gt 0 ]]; then
  printf '  ✗ %s\n' "${ERRORS[@]}" >&2
  exit 1
fi
exit 0
