---
name: auto-research
description: >
  LLM研究のフルライフサイクル (literature → idea → experiment → paper) を
  8 phases / 4 user gates のステートマシンで進行するメインワークフロー。
  Use when: LLMに関する新規研究を「アイディアの種」「論文URL」「研究テーマ文字列」のいずれかから
  始めて論文ドラフトまで一気通貫で進めたい場合。
  フォーカス: Evaluation/Benchmark, Agent/Tool-use, Fine-tuning/Post-training, Prompt/ICL,
  Attention・LLMアーキテクチャ内部研究。
  NOT for: 単発の論文要約 (→ arxiv-mcp-agent)、本番ML推論パイプライン (→ ml-engineer)、
  Rustクレート生成 (→ rlac-create)。
  入力: 自然言語の研究テーマ | arXiv URL | 既存 .research/<slug>/STATE.json への再開
---

# `auto-research` — LLM研究 フル自動ワークフロー

LLM 研究のメインワークフロー。各 Phase で成果物ファイルを残し、4 つのゲートでユーザー承認を取りながら literature → idea → experiment → paper を進める。

## 制約

- **既存資産の再利用必須** — `arxiv-mcp-agent` (breadth) と `ml-engineer` (実装) を再実装せず必ず Agent dispatch する。重複させない。
- **構造化 JSON ログ** — `events.jsonl` の必須フィールド: `event, level, ts, run_id, duration_ms` (CLAUDE.md 規約)。`error.type`, `error.message`, `error.stack` は失敗時のみ。
- **再現性最優先** — `seed`, `dtype`, `git_rev`, `config_hash` を `RunConfig` に固定。`torch.use_deterministic_algorithms(True)`。
- **PII / 著作権** — 商用ジャーナル PDF はキャッシュしない、原文引用 ≤ 2 文。`references/responsible_research.md` 参照。
- **TDD 規律** — Phase 5 では `superpowers:test-driven-development` skill を必ず invoke。Red → Green → Refactor。

## 8 Phase / 4 Gate ワークフロー

各フェーズ開始時に進捗を表示:

```
[Phase N/8] {フェーズ名}
  前フェーズの成果: {要約}
  次にやること: {概要}
```

ユーザー対話は 4 ゲートのみ: G1 (Phase 1 末), G2 (Phase 3 末), G3 (Phase 4 末), G4 (Phase 8)。

State 管理: 全プロジェクトは `.research/<slug>/STATE.json` で進行を記録。`references/phase_state_machine.md` を参照。

---

### Phase 1: Topic Framing

**1.1 入力種別の判定** — `$ARGUMENTS` を解析:
- `--resume <slug>` → `.research/<slug>/STATE.json` を読み、`current_phase` から再開 (Phase 1 をスキップ)
- `arxiv.org` or `.pdf` → 起点論文として記録 (WebFetch でメタ取得)
- それ以外 → 自然言語の研究テーマとして扱う

**1.2 project_slug 生成**: 入力から `^[a-z][a-z0-9-]{2,48}$` の slug を生成。既存 `.research/` 下と衝突する場合は `-2`, `-3` を付与。

**1.3 ディレクトリ初期化**:
```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/init_state.sh" <slug>
```
これで `.research/<slug>/{02_SURVEY,06_RUNS,paper,figures}/` と `STATE.json` が生成される。

**1.4 Brief ドラフト生成** → `.research/<slug>/01_BRIEF.md`:

```markdown
# Research Brief: {topic}

## Motivation
{1-3 文。なぜ今やる価値があるか}

## Scope
- focus_area: {evaluation | agent | post-training | prompt | attention | other}
- 対象モデル規模: {例: ~7B open weights / API only / both}
- 検証する現象 / 改善対象: {一文}

## Out of Scope
- {明示的に除外する論点}

## Success Criteria
- 主要指標: {例: MMLU +1.5pt 統計的有意 (paired bootstrap)}
- 副次指標: {例: throughput regression < 5%}

## Budgets
- time_budget_days: {N}
- compute_budget_gpu_h: {N}
- compute_kind: {例: 1× A100 80GB / 4× H100 / TPU v4-8 / API only}

## Paper Format
- {latex-neurips | latex-acl | markdown}

## Starting Pointers
- {arxiv id / blog / github があれば箇条書き}
```

**1.5 ユーザー確認 — Gate G1 (対話 1 回目)**:

```
🟡 Gate G1: スコープ確認

Brief を `.research/{slug}/01_BRIEF.md` に保存しました。
focus_area = {value} / time_budget = {N} days / compute_budget = {N} GPU-h

このまま Phase 2 (文献サーベイ) に進めますか?
[Y] 進む  [E] 編集  [Q] 中断
```

承認時 `STATE.json.last_gate_passed = "G1"` に更新。

---

### Phase 2: Literature Survey

**2.1 検索計画** — `01_BRIEF.md` の `focus_area` と `Starting Pointers` から 3-6 個の検索クエリを組み立てる。`research.literature.matrix` skill を invoke。

**2.2 breadth-first 検索** — `Agent(subagent_type="arxiv-mcp-agent")` を 1 回 dispatch:

```
arxiv-mcp-agent への依頼:
  目的: {01_BRIEF.md の motivation}
  検索クエリ: {計画した 3-6 個}
  期間: 直近 24 ヶ月 (基礎論文が必要なら適宜広げる)
  カテゴリ: cs.CL / cs.LG / cs.AI など focus_area に応じて
  出力: papers.jsonl (id, title, year, abstract_summary, our_relevance) の最低 10 件
```

返ってきた候補を `.research/<slug>/02_SURVEY/papers.jsonl` に書き込む。

**2.3 depth-first 並列読解** — 上位 3-5 本を `Agent(subagent_type="paper-deep-reader")` で **並列** dispatch (1 メッセージ複数 tool calls):

各 paper-deep-reader への依頼:
- 対象 arXiv ID
- 抽出スキーマ: `{problem, method, equations_summary, dataset, metric, claim, limitation, replicability_checklist, our_relevance}` (固定、`research.literature.matrix/references/paper_note_schema.md` 準拠)
- 出力先: `.research/<slug>/02_SURVEY/notes/<paper_id>.md`

**並列重複防止**: `papers.jsonl` を mutex として claim 済み id をスキップ。

**2.4 比較表生成** — `research.literature.matrix` skill が `notes/*.md` を集約し `02_SURVEY/MATRIX.md` を生成 (method × dataset × metric の 1 論文 1 行)。

**2.5 進捗表示** (ゲートなし、自動継続):
```
[Phase 2/8 完了] 文献サーベイ
  読解した論文: N 本
  比較表: .research/{slug}/02_SURVEY/MATRIX.md
  次: Phase 3 (Gap 分析・アイディア抽出)
```

`STATE.json.current_phase = 3` に更新。

---

### Phase 3: Gap & Ideation

**3.1 並列 gap 分析** — `Agent(subagent_type="research-gap-finder")` を **3 並列** で dispatch (seed違いで多様性確保):

各 research-gap-finder への依頼:
- 入力: `02_SURVEY/MATRIX.md`, `papers.jsonl`, `notes/*.md`
- 観点: {seed-A: 未検証セル抽出 / seed-B: 矛盾・反例 / seed-C: 隣接領域との接続}
- 出力: `03_GAP_ANALYSIS_{a,b,c}.md`

**3.2 統合とアイディア提案** — 3 つの gap analysis を統合し `03_GAP_ANALYSIS.md` (統合版) と `03_IDEAS.md` を生成。

`03_IDEAS.md` フォーマット:
```markdown
# Ideas

## Idea 1: {tagline}
- novelty: {1-5}
- feasibility: {1-5} (compute_budget 内で実行可能か)
- impact: {1-5}
- 仮説: {一文 falsifiable}
- 必要リソース: GPU-h ~{N}, データ {name/license}, モデル {id}
- 主要 risk: {一文}

## Idea 2 ...
```

**3.3 ユーザー確認 — Gate G2 (対話 2 回目)**:

```
🟡 Gate G2: アイディア採択

3 つの gap finder が以下のアイディアを提案しています:

1. {Idea 1 tagline} (N/F/I = 4/3/4)
2. {Idea 2 tagline} (N/F/I = 5/2/5)
3. {Idea 3 tagline} (N/F/I = 3/4/3)

[1-N] 1つ採択  [M] 複数採択 (要相談)  [R] サーベイに戻る (Phase 2)  [Q] 中断
```

`STATE.json.last_gate_passed = "G2"`、採択された idea 番号を `STATE.json.adopted_idea_id` に記録。

---

### Phase 4: Experiment Design

**4.1 設計委任** — `Agent(subagent_type="experiment-designer")` を 1 回 dispatch:

```
experiment-designer への依頼:
  入力: 03_IDEAS.md の採択 idea, 01_BRIEF.md の budget
  出力: 04_EXPERIMENT_PLAN.md (RQ, H1..Hn, 独立/従属変数, ablation 軸,
        primary/sanity metric, baselines, 統計検定 (paired bootstrap 等),
        seed plan, GPU-h 見積)
  制約: compute_budget_gpu_h を超えない設計。超える場合は smaller model / LoRA / subset eval を提案
```

**4.2 計画妥当性チェック**:
- `eval_protocol.md` 準拠 (汚染チェック、ベースライン妥当性)
- `references/reproducibility_checklist.md` 全項目埋め

**4.3 ユーザー確認 — Gate G3 (対話 3 回目)**:

```
🟡 Gate G3: 実験予算 + 設計合意

`04_EXPERIMENT_PLAN.md` を生成しました:
  RQ: {一文}
  ベースライン: {N 個}
  Ablation 軸: {M 個}
  推定 GPU-h: {N} (予算 {budget} の {%})
  primary metric: {name}, 統計検定: {method}

このまま Phase 5 (実装) に進めますか?
[Y] 進む  [E] 編集  [R] アイディア再選 (Phase 3)  [Q] 中断
```

`STATE.json.last_gate_passed = "G3"`。

---

### Phase 5: Scaffold + Baseline TDD

**5.1 プロジェクト雛形** — `research.experiment.scaffold` skill を invoke:

`.research/<slug>/code/` に `uv` プロジェクトを生成 (pyproject.toml, src/, tests/, configs/, notebooks/, results/)。`RunConfig` dataclass を必ず生成。

**5.2 TDD 規律** — `superpowers:test-driven-development` skill を invoke:
- Red: data loader 形状テスト, forward pass テスト, metric sanity テスト, eval 汚染チェック (n-gram overlap)
- Green: ml-engineer agent に実装委任 (`Agent(subagent_type="ml-engineer")`)
- Refactor: 型整理、logging 整備

**5.3 ベースライン実行** — 1 seed・1 config でベースラインを通す。`uv run pytest -q` 全パス & ベースライン metrics が `04_EXPERIMENT_PLAN.md` の sanity 範囲内か確認。

**5.4 進捗表示** (ゲートなし):
```
[Phase 5/8 完了] Scaffold + Baseline
  ベースライン {metric}: {value} (期待 {expected_range})
  テスト: passed
  次: Phase 6 (本番実験 + 分析)
```

---

### Phase 6: Run & Analysis

**6.1 本番実行** — `research.experiment.run` skill を invoke:
- ablation 全 cell × seed 3+ で実行
- `run_id = {YYYYMMDD-HHMMSS}-{git-sha[:7]}-{config-hash[:6]}`
- 各 run は `06_RUNS/<run_id>/{config.yaml, metrics.json, events.jsonl, STATUS}` に書き出す
- 失敗 run は破棄せず `STATUS=failed` で残す
- PostToolUse hook (`hooks/post-experiment-log.sh`) が `events.jsonl` に追記する

**6.2 並列分析** — 全実行完了後、以下を **並列** dispatch:

```
- Agent(subagent_type="result-statistician")
    入力: 06_RUNS/*/metrics.json
    出力: 06_RESULTS.md, figures/*.pdf, 統計検定結果

- (focus_area が attention の場合のみ)
  Agent(subagent_type="attention-analyst")
    入力: 最良/最悪 run のチェックポイント
    出力: analysis/<slug>.py + results/<slug>.json (logit lens / patching 結果)
```

**6.3 sanity check 失敗時のロールバック**:
- primary metric が予測と大きく乖離 → Phase 5 に戻る (`CHANGELOG.md` に記録)
- 全 ablation で有意差なし → null result も成果物として Phase 7 へ進む (negative result paper)

**6.4 進捗表示**:
```
[Phase 6/8 完了] Run & Analysis
  完了 run: N (failed: M)
  primary metric 結果: {summary}
  次: Phase 7 (論文ドラフト)
```

---

### Phase 7: Paper Drafting

**7.1 論文骨格** — `research.paper.draft` skill を invoke:
- `01_BRIEF.md` の `paper_format` で latex-neurips / latex-acl / markdown を分岐
- `references/paper_skeleton.{tex,md}` を雛形として `.research/<slug>/paper/` に展開

**7.2 章ごと並列ドラフト** — 以下を **並列** dispatch (1 メッセージ複数 Task):
- Abstract / Intro / Related Work / Method / Experiments / Results / Discussion / Limitations
- 各章担当 (main thread or sub-task) に対して `04_EXPERIMENT_PLAN.md`, `06_RESULTS.md`, `02_SURVEY/MATRIX.md` を渡す

**7.3 統合パス** — 用語・記号を統一、`refs.bib` を Semantic Scholar MCP で DOI 補完、図表番号を整理。

**7.4 関連研究最終確認** — `Agent(subagent_type="arxiv-mcp-agent")` で「直近 3 ヶ月の関連最新論文」を再検索し Related Work セクションに追補。

**7.5 進捗表示**:
```
[Phase 7/8 完了] Paper Drafting
  paper/main.{tex|md}: 全 N 章ドラフト完了
  refs.bib: M エントリ
  次: Phase 8 (セルフレビュー)
```

---

### Phase 8: Self-Review & Iterate

**8.1 セルフレビュー** — `Agent(subagent_type="research-gap-finder")` を reviewer モードで dispatch:

```
依頼:
  入力: paper/main.{tex,md}, 06_RESULTS.md
  観点 (ICLR reviewer 視点):
    - Soundness: 主張と証拠の対応、統計検定の妥当性
    - Presentation: 構成、図表、用語一貫性
    - Contribution: 新規性、impact、再現性
    - Reproducibility: seed / config / 環境再現の十分性
  出力: 08_REVIEW.md (弱点 + reviewer-likely-questions)
```

並列で `gemini` skill を invoke し「直近 1 週間の関連最新論文」を確認、出てきたら Related Work に追加。

**8.2 ユーザー確認 — Gate G4 (対話 4 回目)**:

```
🟢 Gate G4: 公開判断

セルフレビュー完了:
  Soundness: {pass/concern}
  致命的問題: {N 件}
  reviewer-likely-questions: {M 件}

[Y] 公開する (CHANGELOG.md に記録、終了)
[I] 致命的問題を修正 (Phase 4 or 6 に戻る)
[E] レビューコメントだけ反映してもう 1 周
[Q] 中断 (現状凍結)
```

公開時 `CHANGELOG.md` に `[unreleased] -> [v0.1.0]` のように追記、`STATE.json.completed_at` をセット。

---

## STATE.json スキーマ

`references/phase_state_machine.md` 参照。最低限:

```json
{
  "project_slug": "attention-sink-llama-long-ctx",
  "created_at": "2026-05-09T10:00:00Z",
  "current_phase": 4,
  "last_gate_passed": "G3",
  "adopted_idea_id": 2,
  "active_run_ids": [],
  "paper_format": "latex-neurips",
  "focus_area": "attention",
  "compute_budget_gpu_h": 200
}
```

## 失敗モードと回復

| 失敗 | 検出 | 回復 |
|------|------|------|
| 関連論文 < 5 本 | Phase 2 | キーワード LLM で拡張、隣接領域へ |
| novelty 不足 | Phase 3 G2 | Phase 2 に戻り検索軸を直交化 |
| GPU 不足 | Phase 4 G3 | smaller model / LoRA / subset eval |
| sanity 失敗 | Phase 6 | Phase 5 へ戻る |
| 致命的レビュー指摘 | Phase 8 G4 | Phase 4 or 6 へ戻る |

各 rollback は `.research/<slug>/CHANGELOG.md` に 1 行で記録 (`yyyy-mm-dd: rolled back from Phase 6 → 5 (sanity failure on metric X)`)。

## Phase 完了時の Next-Step Trailer (必須)

各 Phase 完了時、および呼び出された `/auto-research:research-*` コマンドの最終出力末尾に、
**next-step trailer** を **必ず** 出力する。仕様は `references/next_steps_template.md` に集約。

最小手順:
1. `.research/<slug>/STATE.json` を Read (なければ「STATE.json 不在」分岐)
2. `next_steps_template.md` §2 マッピング表 + §3 特殊状態に従って 推奨 / 代替 を決定
3. §1 の literal フォーマットで出力 (`─` 罫線、`●○` 進捗バー、空行 1 個)

skip 不可。STATE.json が読めない場合も §1「STATE.json 不在」テンプレを出す。

## 関連ドキュメント

- `references/phase_state_machine.md` — STATE.json schema + rollback edges
- `references/next_steps_template.md` — Next-step trailer の表示仕様 + 状態マッピング
- `references/data_lineage.md` — データの所在・retention・公開方針 (v0.3.0+)
- `references/error_handling_spec.md` — Phase 別 failure mode と回復手順 (v0.4.0+)
- `skills/research.cost.estimate/references/gpu_price_table.json` — GPU 単価 SoT (v0.5.0+)
- `skills/research.experiment.scaffold/references/observability_setup.md` — W&B/MLflow opt-in (v0.5.0+)
- `skills/research.publish/SKILL.md` — HF Hub / Zenodo upload + DOI (v0.6.0+)
- `references/eval_protocol.md` — ベンチマーク選定・汚染チェック
- `references/reproducibility_checklist.md` — Phase 4 で必須項目
- `references/data_card_template.md` — Phase 5 で生成
- `references/responsible_research.md` — PII / 著作権 / LLM-author 開示
- `agents/DISPATCH_MATRIX.md` (プラグイン root) — 5 subagents × 8 phases の dispatch ルール
