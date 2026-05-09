#!/usr/bin/env bash
# tests/test_json_manifests.sh — 全 JSON manifest が valid か
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAIL=0
for f in \
  "${ROOT}/.claude-plugin/plugin.json" \
  "${ROOT}/.claude-plugin/marketplace.json" \
  "${ROOT}/.mcp.json" \
  "${ROOT}/hooks/hooks.json"; do
  if ! jq -e . "$f" >/dev/null 2>&1; then
    echo "✗ ${f}: invalid JSON" >&2
    FAIL=$((FAIL+1))
  fi
done
[[ ${FAIL} -eq 0 ]] && echo "json manifests test: pass" || exit 1
