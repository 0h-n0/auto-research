# Error Handling Specification

各 skill / agent / phase で起きうる failure mode を **Phase 別に網羅** し、検出と回復手順を定義する。
v0.4.0 から導入。実際に発生した事象は CHANGELOG にも記録し、本書を継続的に更新する。

## 設計原則

1. **失敗を隠さない**: 失敗 run も `STATUS=failed` で残す、silent fail は禁止 (`hooks/post-experiment-log.sh` が stderr に出力)
2. **回復は明示的に**: 自動 retry は使わない。ユーザーゲート (G1-G4) または明示的な rollback edge を経由
3. **再現性を壊さない**: rollback 時も `STATE.json.rollbacks` と `CHANGELOG.md` に記録
4. **エスカレーションのルール**: 同じエラーが 2 回連続したら user 確認、3 回で phase rollback を提案

---

## Phase 1: Topic Framing

| failure | 検出 | 回復 |
|---------|------|------|
| `$ARGUMENTS` が解釈不能 (URL/topic/--resume いずれにも合致せず) | 入力解析時 | ユーザーに種別を尋ねる |
| project_slug 衝突 (`-2`, `-3` でも回避不能) | `init_state.sh` の slug 検証 | 別 slug 提案を 3 つ示す |
| `compute_budget_gpu_h = 0` | G1 確認時 | 警告 + 再入力を促す |
| `.research/` 書き込み権限なし | `init_state.sh` の `mkdir` | 親ディレクトリ確認、別パス提案 |

## Phase 2: Literature Survey

| failure | 検出 | 回復 |
|---------|------|------|
| arxiv-mcp-server 未設定 | search_papers tool 未解決 | README install 手順を示し中断 |
| 関連論文 < 5 本 | papers.jsonl の行数 | キーワード LLM で拡張、隣接領域へ。ユーザー確認後に再検索 |
| paper-deep-reader が PDF パース不可 | read_paper エラー | abstract のみで note 作成、`note.md` の Replicability に `paper text not parseable` |
| paper-deep-reader 並列で同 paper を取得 | papers.jsonl の `claim` 列が同一 ID で重複 | 後発を skip、警告を report |
| MATRIX.md 生成時にスキーマ不一致な note を発見 | `paper_note_schema.md` 準拠 check | 該当 note を再生成 (paper-deep-reader 再 dispatch)、不可なら警告 + 該当行を空欄に |

## Phase 3: Gap & Ideation

| failure | 検出 | 回復 |
|---------|------|------|
| research-gap-finder が 3 並列で全て同じ idea を出す | seed-A/B/C の出力 diff | seed angle を強制再指定、または 4 つ目の seed を追加 dispatch |
| Idea が全て novelty < 3 | 03_IDEAS.md の score 集計 | Phase 2 にロールバック (キーワード直交化) |
| Idea が全て feasibility < 3 (budget 超え) | compute estimate × runs の合計 | smaller model / LoRA / subset eval を提案 |
| G2 でユーザーが None を選択 | 採択番号入力 | Phase 2 へロールバック |

## Phase 4: Experiment Design

| failure | 検出 | 回復 |
|---------|------|------|
| GPU-h 推定が compute_budget の 2x 超 | 04_EXPERIMENT_PLAN.md の compute table | smaller model / LoRA / subset を experiment-designer に再依頼 |
| baseline が MATRIX.md に存在しない | references チェック | arxiv-mcp-agent に追加検索を依頼 |
| primary metric が複数 (1 つに絞れない) | RQ × hypothesis の対応 | experiment-designer に primary 1 + secondary N の構成を強制 |
| 統計検定 method が不明 | data 形状から判定 | paired bootstrap (default) を提案、不適切なら Welch / McNemar に変更 |
| eval 汚染チェックを skip | reproducibility checklist | 強制で n-gram overlap 計算を要求 |

## Phase 5: Scaffold + TDD

| failure | 検出 | 回復 |
|---------|------|------|
| `uv init` が失敗 | exit code | uv version 確認、`uv self update` を案内 |
| 依存パッケージが PyPI に存在しない | `uv sync` エラー | パッケージ名を実機検証 (v0.3.0 の MCP 検証と同様)、代替を提案 |
| baseline metric が sanity range 外 (0 や 1) | metrics.json | 実装バグ疑い、ml-engineer に再 dispatch |
| pytest 全 fail のまま 5 cycle 経過 | tests pass count を CHANGELOG に記録 | 設計レベルの問題を疑い、Phase 4 へ rollback 提案 |
| TDD discipline 違反 (テスト無しで実装) | superpowers:test-driven-development skill が指摘 | Red phase を強制実行 |

## Phase 6: Run & Analysis

| failure | 検出 | 回復 |
|---------|------|------|
| GPU OOM | events.jsonl error_type=OutOfMemoryError | batch_size 縮小、attn_impl=sdpa 強制、smaller model |
| sanity 失敗 (5 cell 連続) | metrics.json の primary metric range | Phase 5 へ rollback (`STATE.json.rollbacks` + `CHANGELOG.md`) |
| 実行 5 時間以上止まる | hooks/post-experiment-log.sh の duration_ms | timeout 設定見直し、failed run として `STATUS=failed_timeout` |
| 全 ablation で有意差なし | result-statistician 報告 | null result paper として Phase 7 へ進む (重要: 削除しない) |
| events.jsonl が events.schema.json 違反 | tests/test_events_schema.sh | hook 実装バグの可能性、PostToolUse hook を見直し |
| 並列 run の checkpoint write 衝突 | filesystem error | 1 process / 1 GPU 原則を強制、並列度を下げる |
| **compute budget 超過** (v0.5.0+) | `research.cost.estimate` の budget watch (80%/100%) | 残り cells を P0 のみに絞る、smaller model に switch、最悪 Phase 4 へ rollback |
| W&B / MLflow init 失敗 (env var あり、package なし) | `ImportError` を except 捕捉 | 警告 + 続行 (events.jsonl は常時書かれる)、`uv sync --extra wandb` を案内 |
| W&B server 到達不能 | `wandb.init()` exception | `WANDB_MODE=offline` に fallback、後で `wandb sync` |

## Phase 7: Paper Drafting

| failure | 検出 | 回復 |
|---------|------|------|
| pdflatex 未インストール | `which pdflatex` | LaTeX ビルドを skip、`.tex` のみ出力 |
| pdflatex がエラーで止まる | exit code != 0 | `paper/build_errors.log` に保存、ユーザーに修正を促す |
| Semantic Scholar API レート制限 | HTTP 429 | 取得済みのみで refs.bib 作成、不足分は arXiv ID から手動 |
| 章ごと並列ドラフトで用語衝突 | terminology check (post-pass) | 統合パスで規約 (notation.tex) を強制 |
| AI 利用開示節欠落 | grep `AI Use Disclosure` | テンプレ強制 include |

## Phase 8: Self-Review

| failure | 検出 | 回復 |
|---------|------|------|
| research-gap-finder (reviewer) が 致命的問題 5 件以上 | 08_REVIEW.md の Major Concerns | Phase 4 or 6 への rollback を強く推奨 |
| gemini skill 応答なし | timeout | 最新差分確認を skip、08_REVIEW.md に記録 |
| reviewer が再実験を要求 | Major Concern 内容 | Phase 6 rollback、追加 ablation 実行 |
| G4 で stuck (Y/I/E/Q いずれも選べない) | ユーザー入力 | プロジェクトを `STATE.json.completed_at = null` のまま凍結 (再開可) |
| `HF_TOKEN` 未設定で research.publish 起動 (v0.6.0+) | env var check | エラー終了、token 取得方法を案内 (`https://huggingface.co/settings/tokens`) |
| `ZENODO_ACCESS_TOKEN` 未設定 (v0.6.0+) | env var check | エラー終了、案内 (`https://zenodo.org/account/settings/applications/`) |
| HF Hub repo 名衝突 (v0.6.0+) | create_repo response | `-2` 等の suffix を自動付与 |
| Zenodo API レート制限 / HTTP 429 (v0.6.0+) | response status | exponential backoff で 3 回 retry、再失敗時は再試行を案内 |
| publish 部分 success (HF OK / Zenodo NG, etc.) (v0.6.0+) | exception location | PUBLICATION.md に成功分のみ記録、未完了部分を明示 |
| `huggingface_hub` / `requests` 未インストール (v0.6.0+) | `ImportError` | 警告 + `uv sync --extra publish` を案内 |
| Zenodo published version を変更したい (v0.6.0+) | metadata 更新 API | 新 deposition (new version) として upload、旧 DOI とは別 |

---

## クロスフェーズ failure

| failure | 検出 | 回復 |
|---------|------|------|
| `STATE.json` が schema 不一致 (manual 編集等) | tests/test_state_schema.sh | バックアップから復元、または rollback 操作で修正 |
| 同 slug の `.research/` が 2 つ存在 (.research vs .research-staging 等) | research-status / Glob | `--resume <slug>` で曖昧性解消、または slug 改名 |
| version mismatch (plugin / CLI) | plugin.json の `version` vs install 時 | `/plugin marketplace update` を案内 |
| MCP server 起動失敗 | tool 呼び出し時 | README の MCP セクション参照、代替手段を案内 |
| events.jsonl サイズが GB 級 | du / find 実機検証 | gzip 圧縮を提案、retention 期限経過分は削除 |
| Disk 不足 | `df` (cron 推奨) | checkpoint 削除、cache クリーン |

---

## エスカレーションのルール

1. **同じエラーが 2 回連続**: ユーザーに「再試行 / skip / rollback」の 3 択を提示
2. **同じエラーが 3 回連続**: 強制 rollback (該当 phase の前段 phase へ)
3. **rollback も失敗**: `STATE.json.completed_at` を null のまま凍結し、`CHANGELOG.md` に詳細記録、ユーザーに手動介入を依頼

---

## 失敗を学びに変える

新しい failure mode に遭遇したら:

1. その場で本ファイルに追記 (Phase 別の表へ)
2. CHANGELOG.md `[Unreleased]` にも記録
3. 可能なら `tests/` に再現テスト (Red phase) を追加
4. 修正は次の release に含める

これにより、同じ問題で 2 度詰まらないようにする。
