#!/usr/bin/env bash
# tests/test_metrics_schema.sh — metrics.json fixture が schema を満たすか
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEMA="${ROOT}/tests/schemas/metrics.schema.json"
FIXTURE="${ROOT}/tests/fixtures/metrics_sample.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq not installed" >&2; exit 2
fi
if ! jq -e . "${FIXTURE}" >/dev/null 2>&1; then
  echo "✗ metrics_sample.json: invalid JSON" >&2; exit 1
fi

if command -v uv >/dev/null 2>&1; then
  uv run --quiet --with jsonschema python3 -c "
import json, sys, jsonschema
s = json.load(open('${SCHEMA}'))
d = json.load(open('${FIXTURE}'))
try:
    jsonschema.validate(d, s)
except jsonschema.ValidationError as e:
    print(f'{e.message}', file=sys.stderr); sys.exit(1)
" || { echo "✗ metrics_sample.json: schema validation failed" >&2; exit 1; }
elif python3 -c 'import jsonschema' 2>/dev/null; then
  python3 -c "
import json, sys, jsonschema
s = json.load(open('${SCHEMA}'))
d = json.load(open('${FIXTURE}'))
jsonschema.validate(d, s)
" || { echo "✗ metrics schema validation failed" >&2; exit 1; }
fi
echo "metrics.json schema test: 1 pass / 0 fail"
