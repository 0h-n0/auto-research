---
name: research.publish
description: >
  `research.export` で作成した bundle を HuggingFace Hub Datasets または Zenodo に
  upload し、DOI を取得して `PUBLICATION.md` に記録する skill。Phase 8 G4 通過後の
  公開フェーズで dispatch される。env var (`HF_TOKEN`, `ZENODO_ACCESS_TOKEN`) で認証。
  Use when: paper の公開前 / 後に研究 artifact (bundle) を公開・archive したいとき、
  または reviewer に DOI 付きで bundle を渡したいとき。
---

# `research.publish`

`research.export` の出力を **公開・archive** するための skill。
DOI 取得は Zenodo 経由、modular な dataset 公開は HF Hub。両方並行して使うのが推奨パス。

## 入力 / 出力

入力:
- `<slug>` (`.research/<slug>/` に export 済み tar.gz が必要)
- (任意) `<bundle_path>` (export tar.gz への明示指定。省略時は最新を自動選択)
- (任意) `--target=hf-hub | zenodo | both` (default: `both`)
- (任意) `--draft` (Zenodo draft / HF Hub private)

入力環境変数:
- `HF_TOKEN` — HuggingFace API token (write 権限)
- `ZENODO_ACCESS_TOKEN` — Zenodo personal access token
- `HF_USERNAME` (任意) — repo owner (default: `whoami` ベース)
- `ZENODO_SANDBOX=1` (任意) — Zenodo sandbox を使う (テスト時推奨)

出力:
- `.research/<slug>/PUBLICATION.md` (公開記録、URL + DOI + commit SHA)
- HF Hub: `https://huggingface.co/datasets/<owner>/auto-research-<slug>`
- Zenodo: DOI (例 `10.5281/zenodo.1234567`) + URL

## 制約

- 認証 token が必要。未設定なら明確にエラー (silent skip しない)
- `research.export` で生成した bundle が前提。直接 `.research/<slug>/` 全体を upload しない
  (PII redaction を経由する)
- `--draft` フラグなしで公開すると **取り消し困難** (特に Zenodo の published version)。
  デフォルトで `--draft` 推奨、本番公開は明示的に `--no-draft`
- 価格表 / cost_overrides.json / events.jsonl 生 (redacted 前) は upload しない (`research.export` が事前に除外)

## ワークフロー

### 1. 入力検証

```
- .research/<slug>/STATE.json が存在し schema 準拠
- 最新 export tar.gz を `.research/<slug>/` または明示パスから検索
- HF_TOKEN / ZENODO_ACCESS_TOKEN を target に応じて確認
```

### 2. HF Hub Datasets upload (target=hf-hub or both)

```python
from huggingface_hub import HfApi, create_repo

api = HfApi()
repo_id = f"{HF_USERNAME}/auto-research-{slug}"
create_repo(repo_id, repo_type="dataset", private=draft, exist_ok=True)
api.upload_folder(
    folder_path="<extracted bundle dir>",
    repo_id=repo_id,
    repo_type="dataset",
    commit_message=f"auto-research export {bundle_filename}",
)
```

成果物: `https://huggingface.co/datasets/<HF_USERNAME>/auto-research-<slug>`

### 3. Zenodo upload (target=zenodo or both)

Zenodo REST API:

```python
import requests

base = "https://sandbox.zenodo.org/api" if os.environ.get("ZENODO_SANDBOX") else "https://zenodo.org/api"
headers = {"Authorization": f"Bearer {ZENODO_ACCESS_TOKEN}"}

# 1. Create deposition
r = requests.post(f"{base}/deposit/depositions", json={}, headers=headers)
deposition_id = r.json()["id"]
bucket_url = r.json()["links"]["bucket"]

# 2. Upload bundle file
with open(bundle_path, "rb") as f:
    requests.put(f"{bucket_url}/{bundle_filename}", data=f, headers=headers)

# 3. Set metadata
metadata = {
    "metadata": {
        "title": f"auto-research artifact: {slug}",
        "upload_type": "dataset",
        "description": brief_md,  # 01_BRIEF.md の内容
        "creators": [{"name": "0h-n0", "affiliation": "individual"}],
        "keywords": ["llm", "ml-research", "auto-research", focus_area],
        "related_identifiers": [
            {"identifier": git_remote_url, "relation": "isSupplementTo", "scheme": "url"}
        ],
    }
}
requests.put(f"{base}/deposit/depositions/{deposition_id}", json=metadata, headers=headers)

# 4. Publish (--no-draft 時) or keep as draft
if not draft:
    requests.post(f"{base}/deposit/depositions/{deposition_id}/actions/publish", headers=headers)
```

成果物: DOI (`10.5281/zenodo.<id>`) + URL

### 4. PUBLICATION.md 生成

`.research/<slug>/PUBLICATION.md`:

```markdown
# Publication Record — <slug>

Published: 2026-05-09T15:30:00Z
auto-research version: 0.6.0
git SHA: abc1234

## HuggingFace Hub Dataset

- URL: https://huggingface.co/datasets/0h-n0/auto-research-<slug>
- Visibility: public (or private if --draft)
- Commit on Hub: <hub-commit-sha>

## Zenodo Archive

- DOI: 10.5281/zenodo.1234567
- URL: https://zenodo.org/record/1234567
- Status: published (or draft)
- Bundle filename: <slug>_export_20260509_abc1234.tar.gz

## Bundle metadata (from MANIFEST.json)

- exported_at: 2026-05-09T15:00:00Z
- project_state: Phase 8 / G4 ✓ (completed_at: 2026-05-09T...)
- focus_area: evaluation
- redaction: events.jsonl prompt → sha256 (432 lines)

## Citation

bibtex:
\`\`\`
@misc{<slug>2026,
  author = {0h-n0},
  title = {auto-research artifact: <slug>},
  year = {2026},
  publisher = {Zenodo},
  doi = {10.5281/zenodo.1234567},
  url = {https://doi.org/10.5281/zenodo.1234567}
}
\`\`\`

## Reproduction

\`\`\`bash
# Pull bundle from HF Hub
huggingface-cli download 0h-n0/auto-research-<slug> --repo-type dataset \\
    --local-dir auto-research-<slug>

# Or get DOI-stable archive from Zenodo
curl -L https://zenodo.org/record/1234567/files/<slug>_export_20260509_abc1234.tar.gz -o bundle.tar.gz
tar xzf bundle.tar.gz
\`\`\`
```

### 5. 公開後 STATE.json 更新

```json
{
  ...,
  "published": {
    "hf_hub": "0h-n0/auto-research-<slug>",
    "zenodo_doi": "10.5281/zenodo.1234567",
    "published_at": "2026-05-09T15:30:00Z"
  }
}
```

`STATE.json.completed_at` は `research.export` 時にすでに set されている前提。`published` は追加 metadata。
**STATE.json schema (`tests/schemas/state.schema.json`) も published optional field を許容するよう v0.6.0 で更新。**

## next-step trailer

```
─────────────────────────────────────
[Phase 8/8] ●●●●●●●●  G4 ✓  ✓ PUBLISHED

→ paper 公開準備完了
  HF Hub: https://huggingface.co/datasets/0h-n0/auto-research-<slug>
  Zenodo DOI: 10.5281/zenodo.1234567

  代替:
   ・ /auto-research:research-status   完了プロジェクト一覧
   ・ /auto-research:research-start "<新トピック>"   次のテーマへ
─────────────────────────────────────
```

## 失敗モード

| failure | 検出 | 回復 |
|---------|------|------|
| `HF_TOKEN` 未設定 | env var check | エラー終了、設定方法を案内 (https://huggingface.co/settings/tokens) |
| `ZENODO_ACCESS_TOKEN` 未設定 | env var check | エラー終了、設定方法を案内 (https://zenodo.org/account/settings/applications/) |
| HF Hub repo 名衝突 (publicly used) | create_repo response | repo 名 suffix `-2` 等を自動付与 |
| Zenodo API レート制限 | HTTP 429 | exponential backoff で 3 回 retry |
| bundle が見つからない | filesystem check | `research.export` を先に dispatch する旨を案内 |
| 部分 success (HF OK / Zenodo NG, etc.) | exception 場所 | PUBLICATION.md に成功した分のみ記録、未完了部分を明示 |
| `huggingface_hub` / `requests` 未インストール | `ImportError` | `uv sync --extra publish` を案内 |

## 関連 skill

- `research.export` — 前提となる bundle 作成 (PII redaction 含む)
- `research.cost.estimate` — `06_COST_REPORT.md` を bundle に含めることで公開時に compute disclosure
- `research.cross.compare` — 公開後の paper revision で外部研究者が比較するため、cross-compatible に bundle 設計

## 環境準備 (ユーザー)

```bash
# 必要なパッケージを bundle 元 project にインストール
cd .research/<slug>/code
uv sync --extra publish  # huggingface_hub + requests を取得 (skill が pyproject に追加可)

# 認証
export HF_TOKEN="hf_xxx"           # https://huggingface.co/settings/tokens
export ZENODO_ACCESS_TOKEN="xxx"   # https://zenodo.org/account/settings/applications/

# (テスト時) Zenodo sandbox
export ZENODO_SANDBOX=1
```

## Reference 実装

`references/publish.py.txt` に Python 実装 (HfApi + Zenodo REST) を同梱。
skill 実行時に `code/scripts/publish.py` として展開、`uv run python` で呼び出す想定。
