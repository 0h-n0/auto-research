#!/usr/bin/env bash
# tests/test_domains_smoke.sh — v0.11.0 domain packs の静的チェック + scaffold smoke
#
# 1. 各 domain の必須ファイル (train.py.txt / prepare.py.txt / program.md /
#    pyproject.toml / metric_spec.json) 存在
# 2. train.py / prepare.py の Python syntax
# 3. metric_spec.json schema (name, direction in {min,max})
# 4. pyproject.toml が tomllib で読める
# 5. karpathy attribution が train/prepare に含まれる
# 6. swarm_init.sh が --domain で各 domain を scaffold できる
# 7. 不正な domain 名は reject される
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOMAINS_DIR="${ROOT}/skills/research.autonomous.tinker/references/domains"
DOMAINS=("vision-classification" "rl-cartpole" "tabular-classification")

PASS=0
FAIL=0

# 1. README exists
if [[ -f "${DOMAINS_DIR}/README.md" ]]; then
  PASS=$((PASS+1))
else
  echo "✗ domains/README.md missing" >&2; FAIL=$((FAIL+1))
fi

# 2-5. Per-domain checks
for d in "${DOMAINS[@]}"; do
  DD="${DOMAINS_DIR}/${d}"

  for f in train.py.txt prepare.py.txt program.md pyproject.toml metric_spec.json; do
    if [[ -f "${DD}/${f}" ]]; then
      PASS=$((PASS+1))
    else
      echo "✗ ${d}/${f} missing" >&2; FAIL=$((FAIL+1))
    fi
  done

  # Python syntax
  TMP=$(mktemp -d); trap 'rm -rf "${TMP}"' RETURN
  if cp "${DD}/train.py.txt" "${TMP}/_train.py" && python3 -m py_compile "${TMP}/_train.py" 2>/dev/null; then
    PASS=$((PASS+1))
  else
    echo "✗ ${d}/train.py.txt syntax invalid" >&2; FAIL=$((FAIL+1))
  fi
  if cp "${DD}/prepare.py.txt" "${TMP}/_prep.py" && python3 -m py_compile "${TMP}/_prep.py" 2>/dev/null; then
    PASS=$((PASS+1))
  else
    echo "✗ ${d}/prepare.py.txt syntax invalid" >&2; FAIL=$((FAIL+1))
  fi
  rm -rf "${TMP}"; trap - RETURN

  # metric_spec.json schema
  if [[ -f "${DD}/metric_spec.json" ]]; then
    NAME=$(jq -r '.name // ""' "${DD}/metric_spec.json")
    DIR=$(jq -r '.direction // ""' "${DD}/metric_spec.json")
    DOM=$(jq -r '.domain // ""' "${DD}/metric_spec.json")
    if [[ -n "${NAME}" && ( "${DIR}" == "min" || "${DIR}" == "max" ) && "${DOM}" == "${d}" ]]; then
      PASS=$((PASS+1))
    else
      echo "✗ ${d}/metric_spec.json missing or invalid (name=${NAME}, direction=${DIR}, domain=${DOM})" >&2
      FAIL=$((FAIL+1))
    fi
  fi

  # pyproject TOML
  if python3 -c 'import tomllib,sys; tomllib.load(open(sys.argv[1],"rb"))' \
       "${DD}/pyproject.toml" 2>/dev/null; then
    PASS=$((PASS+1))
  else
    echo "✗ ${d}/pyproject.toml invalid" >&2; FAIL=$((FAIL+1))
  fi

  # karpathy attribution in train.py / prepare.py
  if grep -q "karpathy/autoresearch" "${DD}/train.py.txt"; then
    PASS=$((PASS+1))
  else
    echo "✗ ${d}/train.py.txt missing karpathy attribution" >&2; FAIL=$((FAIL+1))
  fi
  if grep -q "karpathy/autoresearch" "${DD}/prepare.py.txt"; then
    PASS=$((PASS+1))
  else
    echo "✗ ${d}/prepare.py.txt missing karpathy attribution" >&2; FAIL=$((FAIL+1))
  fi
done

# 6. swarm_init.sh per-domain smoke (each domain scaffolds 2 agents OK)
TMP=$(mktemp -d); trap 'rm -rf "${TMP}"' EXIT
cd "${TMP}"
for d in "${DOMAINS[@]}"; do
  bash "${ROOT}/scripts/init_state.sh" "smoke-${d}" >/dev/null
  if bash "${ROOT}/scripts/swarm_init.sh" "smoke-${d}" --agents 2 --domain "${d}" >/dev/null 2>&1; then
    DOM=$(jq -r '.domain' ".research/smoke-${d}/swarm/MANIFEST.json")
    if [[ "${DOM}" == "${d}" ]]; then
      PASS=$((PASS+1))
    else
      echo "✗ ${d}: MANIFEST.domain=${DOM} mismatched" >&2
      FAIL=$((FAIL+1))
    fi
  else
    echo "✗ ${d}: swarm_init.sh failed" >&2
    FAIL=$((FAIL+1))
  fi
done

# 7. Invalid domain rejected
bash "${ROOT}/scripts/init_state.sh" smoke-bad >/dev/null
if bash "${ROOT}/scripts/swarm_init.sh" smoke-bad --agents 1 --domain not-a-domain 2>/dev/null; then
  echo "✗ swarm_init.sh accepted unknown domain" >&2; FAIL=$((FAIL+1))
else
  PASS=$((PASS+1))
fi

echo "domains_smoke test: ${PASS} pass / ${FAIL} fail"
[[ ${FAIL} -eq 0 ]] && exit 0 || exit 1
