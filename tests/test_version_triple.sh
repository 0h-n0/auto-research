#!/usr/bin/env bash
# tests/test_version_triple.sh — plugin.json / marketplace.json 三箇所一致 + CHANGELOG エントリ存在
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

V1=$(jq -r '.version' "${ROOT}/.claude-plugin/plugin.json")
V2=$(jq -r '.metadata.version' "${ROOT}/.claude-plugin/marketplace.json")
V3=$(jq -r '.plugins[0].version' "${ROOT}/.claude-plugin/marketplace.json")

if [[ "${V1}" != "${V2}" || "${V2}" != "${V3}" ]]; then
  echo "✗ version triple mismatch:" >&2
  echo "  plugin.json: ${V1}" >&2
  echo "  marketplace.json metadata: ${V2}" >&2
  echo "  marketplace.json plugins[0]: ${V3}" >&2
  exit 1
fi

# CHANGELOG.md にエントリがあるか
if ! grep -qE "^## \[${V1}\]" "${ROOT}/CHANGELOG.md"; then
  echo "✗ CHANGELOG.md has no [${V1}] entry" >&2
  exit 1
fi

# semver 形式
if ! [[ "${V1}" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-z0-9.]+)?$ ]]; then
  echo "✗ version '${V1}' is not semver" >&2
  exit 1
fi

echo "version triple test: pass (v${V1})"
