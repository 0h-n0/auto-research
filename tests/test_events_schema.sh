#!/usr/bin/env bash
# tests/test_events_schema.sh — events.jsonl の各行が schema を満たすか検証
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEMA="${ROOT}/tests/schemas/events.schema.json"
FIXTURE="${ROOT}/tests/fixtures/events_sample.jsonl"

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq not installed" >&2
  exit 2
fi

VALIDATOR=""
if command -v uv >/dev/null 2>&1; then
  VALIDATOR='uv run --quiet --with jsonschema python3'
elif python3 -c 'import jsonschema' 2>/dev/null; then
  VALIDATOR='python3'
fi

PASS=0
FAIL=0
LINE=0
while IFS= read -r line; do
  LINE=$((LINE+1))
  [[ -z "$line" ]] && continue

  # 1. JSON valid
  if ! echo "$line" | jq -e . >/dev/null 2>&1; then
    FAIL=$((FAIL+1))
    echo "  ✗ line ${LINE}: invalid JSON" >&2
    continue
  fi

  # 2. schema check
  if [[ -n "$VALIDATOR" ]]; then
    if ! echo "$line" | $VALIDATOR -c "
import json, sys
import jsonschema
schema = json.load(open('${SCHEMA}'))
data = json.loads(sys.stdin.read())
try:
    jsonschema.validate(data, schema)
except jsonschema.ValidationError as e:
    print(f'line ${LINE}: {e.message}', file=sys.stderr)
    sys.exit(1)
" 2>&1; then
      FAIL=$((FAIL+1))
      continue
    fi
  fi

  PASS=$((PASS+1))
done < "${FIXTURE}"

echo "events.jsonl schema test: ${PASS} pass / ${FAIL} fail"
[[ ${FAIL} -eq 0 ]] || exit 1
