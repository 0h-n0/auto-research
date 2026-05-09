#!/usr/bin/env bash
# tests/test_bash_syntax.sh — 全 .sh ファイルの構文チェック
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAIL=0
while IFS= read -r f; do
  if ! bash -n "$f" 2>&1; then
    echo "✗ ${f}: syntax error" >&2
    FAIL=$((FAIL+1))
  fi
done < <(find "${ROOT}" -type f -name '*.sh' -not -path '*/.git/*' -not -path '*/node_modules/*')

[[ ${FAIL} -eq 0 ]] && echo "bash syntax test: pass" || exit 1
