# Changelog

All notable changes to the `auto-research` plugin are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project adheres to [Semantic Versioning](https://semver.org/).
Release procedure: see [RELEASING.md](./RELEASING.md).

## [Unreleased]

## [0.17.0] - 2026-05-11 — Visual Notebook (HTML rendering)

実験ログ / lab notebook を **MkDocs material で HTML site にビルド**する新スキル `research.notebook.viz` を追加。MD ファイルは SoT として残し、HTML は `.research/<slug>/viz/` に generated artifact として出力。events.jsonl は Chart.js で time-series chart、LAB_NOTEBOOK の Tags は tag plugin で逆引き、STATE.json は Phase 1-8 progress bar 化。

### Added (Skill)
- **`research.notebook.viz` skill** (`skills/research.notebook.viz/`):
  manual invoke で `.research/<slug>/viz/` に MkDocs material 製 static site を build (`uvx --from mkdocs-material mkdocs build` 経由、固定 install 不要)。
  - **Chart.js time-series**: per-run page に `06_RUNS/<id>/events.jsonl` の loss / metric curves を line chart embed
  - **Phase progress bar**: `STATE.json` の current_phase / last_gate_passed を HTML/CSS で全 page header に inject (done=green / current=blue / pending=gray)
  - **Tag inversion**: LAB_NOTEBOOK の `Tags: #...` を mkdocs frontmatter `tags:` に変換、mkdocs-material tags plugin で逆引き page auto-gen
  - **10 sections**: Brief / Survey / Ideas / Plan / Runs / Lab Notebook / Postmortems / Results / Review / Paper (+ Tags index)
  - **Sortable table**: `06_RESULTS.md` / `02_SURVEY/MATRIX.md` / `06_RUNS/INDEX.md` を `attr_list` で sortable HTML table 化
  - **Dark / light mode switcher** 内蔵 (mkdocs-material native)
  - **Search box** 内蔵 (mkdocs-material search plugin、ja+en)
  - 6 references SoT: `mkdocs_config_template.yml.md` / `viz_pipeline.md` / `chart_embedding.md` / `nav_structure.md` / `phase_progress_template.md` / `metric_table_template.md`

### Added (Command)
- **`commands/notebook-viz.md`**: `/auto-research:notebook-viz <slug> [--serve]` で manual build / preview
  - `--serve` で `mkdocs serve --dev-addr localhost:8000` を background 起動 (live-reload 内蔵)

### Changed
- `auto-research/SKILL.md`: 「視覚化 (v0.17.0+、manual invoke)」節を追加、`notebook-viz` の使い方を案内
- `auto-research/references/data_lineage.md`: 「Generated artifacts (v0.17.0+)」節を追加、`.research/*/viz/` と `viz-src/` の retention rule (git track 不要、`.gitignore` 推奨) を明記
- `marketplace.json`: description に v0.17.0 機能を反映

### Added (Tests)
- **`tests/test_notebook_viz.sh`** (70 sub-tests): SKILL.md + 6 references の存在 + 必須 marker (mkdocs theme/plugins/extras、Chart.js、Phase progress CSS class、10 nav sections、sortable table、command frontmatter、data_lineage retention rule、auto-research SKILL.md の言及)
- 全テスト pass: `bash tests/run_all.sh` で **16 pass / 0 fail** (15 → +test_notebook_viz.sh で 16)

### Backward Compatibility
- 既存 v0.16.0 プロジェクトは **そのまま動作**。viz/ 不在でも auto-research workflow 全 Phase 動作不変
- v0.13.0 以前 (LAB_NOTEBOOK / paper.scaffold なし) の project にも適用可、不在ファイルは nav から auto skip
- Phase auto-dispatch なし (build は重め、user が `/auto-research:notebook-viz` で manual)
- `.gitignore` 推奨は README で明示、強制せず

### Notes
- 外部依存: `uvx` (uv 0.4+、既存) + `mkdocs-material[recommended]>=9.5.0,<10` (uvx auto-install) + Chart.js CDN
- Build 時間: 初回 install ~30 秒、cache 後 ~5-15 秒 (project 規模次第)
- Offline mode (Chart.js vendor copy): v0.18+ で実装予定
- GitHub Pages deploy (`mkdocs gh-deploy` 統合) は Open Notebook Science 公開機構として v0.18+ 候補

## [0.16.0] - 2026-05-11 — Lab Notebook P1 Polish

v0.15.0 で Out of Scope に保留した **P1 3 要素** (Provenance trace / ALCOA+ correction guideline / Daily summary entry) を実装。いずれも v0.14.0 / v0.15.0 lab.notebook の **拡張 (optional features)**、workflow dispatch 不変、後方互換。

### Added (Skill — references)
- **`research.lab.notebook/references/provenance_template.md`**: 思考の出処 (paper cite / discussion / external thread / AI assistant) を各 entry / POSTMORTEM に optional field で残す仕様 (Open Notebook Science 由来、引用倫理 + AI 開示)
- **`research.lab.notebook/references/alcoa_correction_guideline.md`**: 紙 lab notebook の伝統的 ALCOA+ correction ルール ("correct mistakes, never remove them") を markdown `~~strike~~` + `<ins>new</ins>` + git history で実装するガイドライン (NIH IRP "Keeping Lab Notebooks" 由来)
- **`research.lab.notebook/references/daily_summary_template.md`**: 日次 entry の Light touch 4-prompt schema (Today's stuck / Today's insight / Tomorrow's plan / Mood)、Phase event 駆動の補完

### Changed
- `research.lab.notebook/SKILL.md`: 3 新要素 (Provenance / ALCOA+ / Daily) を「設計の核」 (#11-13) + ファイル雛形表 + 関連節 に統合
- `research.lab.notebook/references/lab_notebook_skeleton.md`: 各 Phase entry に **Provenance** optional field + Daily summary entry の例 (Light touch 4-prompt)
- `research.lab.notebook/references/postmortem_template.md`: §1 What was attempted の末尾に Provenance optional field
- `research.lab.notebook/references/phase_notebook_map.md`: Daily entry が Phase 1-8 横断で manual 起動できる旨を追記
- `marketplace.json`: description に v0.16.0 機能 (provenance / ALCOA+ / daily summary) を反映

### Added (Tests)
- `tests/test_lab_notebook.sh` 拡張: 96 → **119 sub-tests** (新 references 3 つの存在 + 必須 marker + Provenance field の各 source + ALCOA+ の markdown rule + Daily 4-prompt schema)
- 全テスト pass: `bash tests/run_all.sh` で **15 pass / 0 fail**

### Backward Compatibility
- 既存 v0.15.0 プロジェクトは **そのまま動作**。Provenance / Daily entry 不在でも phase_notebook_map の dispatch 動作不変
- v0.15.0 以前のプロジェクトには影響なし
- 3 要素ともいずれも **optional** (skip しても workflow 動作)
- ALCOA+ guideline は **lint 強制せず**、教育 + ガイドラインで運用

### Notes
- 外部参考元: NIH IRP "Keeping Lab Notebooks: Basic Principles & Best Practices" (ALCOA+)、Open Notebook Science (Bradley 2006、provenance 公開) 、紙 lab notebook 伝統 (daily entry)
- Provenance の cross-check (refs.bib との整合性 + Acknowledgment auto-gen) は v0.17+ で paper.scaffold 統合候補
- Daily entry の Phase 8 review 集約 (frequent insight / stuck pattern 検出) は v0.17+ feature
- workflow dispatcher / auto-trigger は v0.15.0 のまま不変 (3 要素は passive features)

## [0.15.0] - 2026-05-11 — Lab Notebook Best-Practice Polish

外部の lab notebook best practice (Annie Duke "How to Decide" / Google SRE "Blameless Postmortems" / ELN FAIR guidelines) を v0.14.0 lab.notebook 構造に取り込み、4 つの P0 要素を追加。

### Added (Skill — references)
- **`research.lab.notebook/references/decision_journal_template.md`**: Annie Duke "How to Decide" 由来の Light touch decision journal (Phase 3 / 4 entry に Predicted outcome / Confidence / Key assumptions ≤3 を記録)。Phase 6 で予測 vs 実測の Surprise score (1-5) + What I missed entry を auto 生成し、hindsight bias を防ぐ
- **`research.lab.notebook/references/tag_taxonomy.md`**: Hybrid tag system SoT (controlled vocabulary 28 個 = 4 カテゴリ × 5-8 + 自由 tag)。Failure type / Outcome / Process / Phase marker の 4 カテゴリ + Confidence / Metacognition 補助 (FAIR Findable 由来)
- **`research.lab.notebook/references/lessons_db_schema.md`**: Cross-project Lessons DB (`~/.research-lessons.json`) の SoT。全プロジェクト共通の institutional memory として top 3 lessons を Phase 8 で atomic append
- **`research.lab.notebook/references/blameless_principles.md`**: Google SRE "Blameless Postmortems" 由来の宣言文書。Anti-pattern (人を責める言葉) / Pre-pattern (システム / プロセスを主語) を明示

### Added (Command)
- **`commands/lessons-search.md`**: `/auto-research:lessons-search "<query>" [--tag #foo] [--phase N] [--model SIZE]` で `~/.research-lessons.json` を free text + tag + phase + model filter で検索

### Changed
- `auto-research/SKILL.md`: Phase 3.5 拡張 (Decision journal block + Tags 追加)、Phase 4.5 新規 dispatch (LAB_NOTEBOOK Phase 4 entry)、Phase 6.5 拡張 (Phase 6 metacognition entry + Blameless callout + INDEX re-gen)、Phase 8.1.5 拡張 (Lessons DB append + INDEX re-gen)
- `research.lab.notebook/SKILL.md`: 4 新要素 (Decision / Tags / Lessons DB / Blameless) を「設計の核」と Phase × 動作表に統合
- `research.lab.notebook/references/lab_notebook_skeleton.md`: Phase 3 entry に Decision journal block、**Phase 4 entry を新規追加**、**Phase 6 metacognition entry を新規追加**、各 entry 末尾に `Tags:`、LAB_NOTEBOOK_INDEX.md auto-gen 仕様
- `research.lab.notebook/references/postmortem_template.md`: 冒頭に **Blameless callout** + 末尾に Tags (Failure type controlled tag)
- `research.lab.notebook/references/phase_notebook_map.md`: 動作表に Phase 4 行追加、Phase 6/8 動作に metacognition / Lessons DB / INDEX re-gen を追記
- `marketplace.json`: description に v0.15.0 機能 (decision journal / tags / lessons DB / blameless) を反映

### Added (Tests)
- `tests/test_lab_notebook.sh` 拡張: 51 → **96 sub-tests** (新 references 4 つの存在 + 必須 marker + JSON field + Phase 4 / metacognition / Lessons DB の dispatch 言及 + lessons-search command frontmatter)
- 全テスト pass: `bash tests/run_all.sh` で **15 pass / 0 fail** (test ファイル数は変わらず、test_lab_notebook 内 sub-test が拡張)

### Backward Compatibility
- 既存 v0.14.0 プロジェクト (LAB_NOTEBOOK.md 持ち) は **そのまま動作**。Decision block / Tags が無い entry は agent が後付け追加可能 (idempotent)
- v0.13.0 以前のプロジェクト: lab.notebook 自体が無いので影響なし
- `~/.research-lessons.json` 不在時: lab.notebook が schema v0.15.0 で初期化
- Tag taxonomy は将来拡張可能 (自由 tag → controlled 昇格は v1.0+ 機能)

### Notes
- 外部 best practice の参考元: Annie Duke "How to Decide" (decision journal)、Google SRE book Ch."Postmortem Culture" (blameless)、ELN FAIR guidelines (tags / index)、Open Notebook Science (Bradley 2006、negative results 積極記録は v0.14.0 で既に対応済)、ML experiment tracking (mlflow / W&B、tags / metadata 慣習)
- Light touch 設計: Decision journal は 3 項目だけ、Tag は 28 controlled、Lessons DB は jq filter で高速検索 (semantic search は v0.17+)
- Phase 5 TDD Red の lab.notebook invoke は **任意のまま** (v0.14.0 と同じ)
- ELN guidelines のうち P1 要素 (Provenance trace / ALCOA+ correction / Daily summary) は v0.16+ に保留

## [0.14.0] - 2026-05-11 — Lab Notebook & Reproducible Failures

### Added (Skill)
- **`research.lab.notebook` skill** (`skills/research.lab.notebook/`):
  実験 lab notebook + 失敗 postmortem skill。「成功した結果」だけでなく「**何を試して、なぜダメだったか、次に何を変えるか**」を体系的に残す。
  - **Hybrid 構造**: 単一 living `LAB_NOTEBOOK.md` (時系列航海日誌) + per-failure `06_RUNS/<id>/POSTMORTEM.md` (再現可能な失敗カード)
  - **Hypothesis space auto-draft**: failed run の events.jsonl + error.txt から 3-5 仮説候補を agent draft、各々に Statement / Evidence / Verdict (LIKELY / UNLIKELY / RULED OUT)
  - **Reproducibility 7-tuple**: code rev / config / deps (uv.lock) / seed / data hash / hardware / `reproduce.sh` を必須担保。**失敗 run も bash reproduce.sh で再現可能**
  - **Rejected ideas を捨てない**: `03_REJECTED_IDEAS.md` に full body + rejection reason + future revisit conditions を保存、将来の pivot で再考可能
  - **agent-managed marker**: `<!-- agent-managed:Phase=N -->` で人手編集を保護 (paper.scaffold v0.13.0 と同 pattern)
  - SoT: `phase_notebook_map.md`、`hypothesis_table_rules.md`、`failure_reproducibility_checklist.md` (Phase 4 broad checklist `auto-research/references/reproducibility_checklist.md` とは別物、補完関係)

### Changed
- `auto-research/SKILL.md`: Phase 3 末 (3.5)、Phase 6 末 (6.5)、Phase 8 (8.1.5) で `research.lab.notebook` を auto-dispatch
- `research.experiment.run/SKILL.md`: 各 run 完了時に `reproduce.sh` + `uv.lock` snapshot を `06_RUNS/<id>/` に保存。`STATUS=failed` 検出時に `research.lab.notebook` を auto-trigger
- `auto-research/references/next_steps_template.md`: §3.5 (Phase 6 失敗 run 含む混在) trailer 仕様を追加 (POSTMORTEM への link + reproduce 手順)

### Added (Tests)
- **`tests/test_lab_notebook.sh`** (51 sub-tests): file presence + POSTMORTEM 6 必須節 + LAB_NOTEBOOK Phase 3/5/6/8 entry 例 + reproducibility 7-tuple + Hypothesis 3 verdict + 5 error pattern → H mapping + rejected_ideas 必須節 + dispatch points (auto-research × 3 + experiment.run × 3) + agent-managed marker + Phase 6 trailer
- 全テスト pass: `bash tests/run_all.sh` で 14 → **15 pass / 0 fail**

### Backward Compatibility
- 既存プロジェクト (LAB_NOTEBOOK.md 不在) で Phase 1-8 通常動作
- v0.13.0 以前の `06_RUNS/<id>/` には reproduce.sh / uv.lock が無い → best-effort で reproduce.sh だけ後付け生成 (uv.lock は recover 不能、warning 表示)
- `research.paper.scaffold` (v0.13.0) は Phase 7 で DRAFT.md の Limitations 節に LAB_NOTEBOOK Lessons を素材として使えるが、必須ではない (loose coupling)

### Notes
- 科学研究の本質は「成功した結果」だけでなく「失敗の解釈と再現性」にある。本リリースは熟練研究者の lab notebook 文化をワークフローに統合
- 失敗 run の reproducibility (`bash reproduce.sh`) は v0.14.0 から **成功 run と同等保証** に格上げ
- Phase 5 TDD Red 段階の lab.notebook invoke は **任意** (30 分以上 stuck したら推奨)

## [0.13.0] - 2026-05-10 — Paper-First Methodology

### Added (Skill)
- **`research.paper.scaffold` skill** (`skills/research.paper.scaffold/`):
  Phase 2 から呼べる **早期論文骨子 builder**。単一 living document `paper/DRAFT.md` を Phase
  進行に合わせて上書き拡張、Abstract と Introduction を実験前から書く paper-first methodology を実現。
  - **Hypothesis-driven Abstract** (4 ブロック: Background / Method / Hypothesis / Implication)
  - **Introduction** (Motivation / Related Work / Contributions の 3 sub-section)
  - **Related Work**: MATRIX.md から sub-area グループ化 + inline `\cite{}` + Position of our work
  - **bibtex 命名**: `firstauthor + year + firstword`、衝突時 fallback
  - **agent-managed marker** で人手編集を保護
  - 充足度: Phase 2=55%, Phase 3=70%, Phase 4=85%, Phase 6=95%, Phase 7=100%
  - SoT: `phase_section_map.md`

### Changed
- `auto-research/SKILL.md`: Phase 2/3/4/6 末尾で paper.scaffold を自動 dispatch (任意で skip 可)
- `research.paper.draft/SKILL.md`: DRAFT.md detection 追加。存在すれば入力に使う、なければ既存挙動

### Added (Tests)
- **`tests/test_paper_scaffold.sh`** (39 sub-tests): file presence + section headers +
  template markers + phase_section_map / 全 phase 行 + bibtex 命名規則 +
  responsible_research cross-ref + paper.draft DRAFT.md detection +
  auto-research SKILL の dispatch 言及 + Phase 2 earliest invoke
- 全テスト 13 → **14**

### Notes
- **完全 後方互換**: paper.scaffold は **任意**、既存ワークフローはそのまま動作
- **引用ルール**: `responsible_research.md` 準拠 (≤ 2 文 verbatim、商用 PDF キャッシュ禁止、AI Use Disclosure 必須)
- **agent-managed marker**: 人手編集を保護、削除時は skip + warning
- 多言語対応: 現状英語前提、日本語論文は将来 (v1.0+)

## [0.12.0] - 2026-05-10 — Strategy × Domain Adapters + nlp-classification

### Added (Adapter SoT)
- **`skills/research.autonomous.swarm/references/strategy_adapters.md`**: 5 戦略 × 5 domain
  = 25 セルのマッピング SoT (動かす Config / 触らない領域 / domain 固有 hint)
- swarm の各戦略 program は LLM hparam を例示するが、本ファイルが他 domain への翻訳を提供

### Added (Domain Pack)
- **`nlp-classification`** (`skills/research.autonomous.tinker/references/domains/nlp-classification/`):
  - sklearn `fetch_20newsgroups` 4-class subset (alt.atheism / comp.graphics / sci.med / talk.politics.guns)
  - headers/footers/quotes 除去で metadata leakage 防止
  - TF-IDF (max_features=10000) train fit / val transform
  - 自前 ~150 LoC TextMLP (depth/hidden/dropout/label_smoothing knobs)
  - metric: `val_acc` (max)、~85% baseline、>90% は工夫で達成可能
  - 禁止: `transformers`, `sentence-transformers`, HF model hub

### Changed (Validation)
- `scripts/swarm_init.sh`: `nlp-classification` を許可 domain に追加
- `tests/test_domains_smoke.sh`: 4 domain → **5 domain**、38 → **50 sub-tests**

### Added (Tests)
- **`tests/test_strategy_adapters.sh`** (14 sub-tests):
  file 存在 + 5 strategy section + 5 domain mention + 不変条件節 + forbidden imports + logU ranges
- 全テスト 12 → **13** (strategy_adapters 追加)

### Notes
- **完全 後方互換**: 既存ワークフロー (lm-pretrain / 4 domain / 5 戦略) はそのまま動作
- domain count: 4 → **5** (lm-pretrain / vision-classification / rl-cartpole / tabular-classification / nlp-classification)
- adapter doc は **agent が自分で domain を読み替える** 現実的な落とし所
- karpathy attribution は新 domain で +2 箇所、累計 32+ 箇所

## [0.11.0] - 2026-05-10 — Tinker Domain Packs (vision / RL / tabular)

### Acknowledgement
v0.9.0 / v0.10.0 で実装した tinker / swarm autonomous loop の **domain 拡張**。
karpathy/autoresearch の単一ファイル編集 + 固定 wall-clock budget 概念を、LLM pretraining 以外
の領域 (vision / RL / tabular) でも使えるよう一般化。

### Added (Domain Packs)
- **`vision-classification`**: CIFAR-10 + 自前 ~200 行小型 CNN
  - augmentation knobs (random flip/crop) を Config として agent が触れる
  - metric: `val_acc` (max), prepare.py で torchvision CIFAR-10 → train/val.pt
  - program.md は CNN architecture / augmentation / SGD vs AdamW 等の hint
- **`rl-cartpole`**: gymnasium CartPole-v1 + 自前 ~190 行 REINFORCE baseline
  - 固定 evaluation seeds (10 個) で comparable な episode_return
  - metric: `episode_return` (max、最大 500、solve = 475+)
  - prebuilt RL framework (`stable_baselines3`/`cleanrl`) は禁止
- **`tabular-classification`**: sklearn breast_cancer + 自前 ~150 行 MLP
  - stratified 80/20 split (固定 seed=12345)、train statistics で標準化
  - metric: `val_acc` (max、114 val samples で 1 sample = ~0.9 pp)
  - AutoML / TabPFN は禁止

### Added (Abstraction)
- **`metric_spec.json`** schema per domain (name / direction / scale / min_useful / max_useful / notes)
- **`result.json`** schema 拡張: `primary_metric` / `metric_name` / `direction` / `domain`
  (legacy `val_bpb` field は lm-pretrain で継続出力、後方互換)
- **`skills/research.autonomous.tinker/references/domains/README.md`**: domain 抽象化の SoT

### Changed (Runner / Init)
- `scripts/tinker_run.sh`: `--domain <name>` + `--workspace <path>` フラグ追加、
  direction-aware best 比較 (min/max を両対応)、`primary_metric` 優先 + `val_bpb` fallback
- `scripts/swarm_init.sh`: `--domain <name>` フラグ追加、各 domain の template path を解決、
  MANIFEST.json に `domain` フィールド、不正 domain は明示エラー

### Added (Tests)
- **`tests/test_domains_smoke.sh`** (38 sub-tests):
  - domains/README + 3 domain × 5 ファイル存在 + Python syntax + metric_spec schema +
    TOML 妥当性 + karpathy attribution + swarm_init で各 domain scaffold 成功 + 不正 reject
- 全テスト 11 → **12** (domains_smoke 追加)

### Notes
- **完全 後方互換**: 既存 lm-pretrain workspace と v0.9.0/v0.10.0 プロジェクトはそのまま動作
- 5 戦略 (depth/lr/arch/batch/random-restart) は **どの domain でも適用可** (agent が context で読み替え)
- karpathy attribution は domain 拡張で +18 箇所、累計 30+ 箇所

## [0.10.0] - 2026-05-10 — Research Org Swarm Mode (karpathy multi-agent)

### Acknowledgement
本リリースは [karpathy/autoresearch](https://github.com/karpathy/autoresearch) の README で
**future work** として明記されている "research org code" (複数 agent 並列の自律探索組織) のアイディアを
具体化したもの。v0.9.0 の単一 agent tinker (`research.autonomous.tinker`) を 1 単位として再利用し、
N agents を並列に走らせる **swarm mode** を追加。

### Added (Skill)
- **`research.autonomous.swarm` skill** (`skills/research.autonomous.swarm/`):
  N agents (default 3、最大 5 種類戦略 +duplicate) を並列に走らせる research org モード。
  各 agent に異なる戦略 (`depth-explore` / `lr-explore` / `arch-explore` / `batch-explore` /
  `random-restart`) を割り当てて diversity 確保。
  - SoT: `references/swarm_strategies.md` + `references/swarm_protocol.md`
    (file-based agent 通信、flock + atomic write)
  - 5 戦略別 program.md テンプレ (`program_<strategy>.md`)

### Added (Scripts)
- **`scripts/swarm_init.sh`**: N agents の workspace を一括 scaffold (`--agents N`、
  `--strategies a,b,c`、`--allow-duplicate`、agent_<id>/tinker/ に v0.9.0 構造を展開、
  data/ symlink、`swarm/MANIFEST.json` 生成)
- **`scripts/swarm_orchestrate.sh`**: 全 agent の BEST.json を集約 (cron 1h 推奨)
  flock 排他、atomic write、`swarm/SHARED_BEST.json` + `swarm/SWARM_RESULTS.md` +
  `swarm/best_train.py` を更新、`events.jsonl` に `swarm.consensus` 追記

### Added (Tests)
- **`tests/test_swarm_smoke.sh`** (25 sub-tests):
  ファイル存在 (10) + bash syntax (2) + strategy header (5) + karpathy attribution (2) +
  scaffold smoke (1) + manifest valid (1) + orchestrator no-warning (1) +
  SHARED_BEST valid (1) + invalid strategy reject (1) + duplicate strategy reject (1)
- 全テスト 10 → **11** (swarm_smoke 追加)

### Phase 連携
- v0.9.0 と同じく Phase 5-6 alt mode、`04_EXPERIMENT_PLAN.md` の `mode: tinker-swarm` で分岐
- `research.cost.estimate` で N agents × overnight USD を試算
- `research.compute.shop` で multi-GPU box を推奨可能
- Phase 7 では `swarm/SWARM_RESULTS.md` + winner train.py を `research.paper.draft` に渡して
  "swarm research journal" として論文化

### Changed (Documentation)
- `README.md` / `README.en.md`: "Research Org Swarm Mode (v0.10.0+)" 節 + skills 表 1 行
- `skills/auto-research/SKILL.md`: 関連ドキュメントに swarm + (見落としていた) tinker SKILL.md
  への cross-link 追加
- `skills/auto-research/references/error_handling_spec.md`: swarm failure modes 5 項目追加
  (1 agent diverged 連続 30 / 同時 orchestrator / data symlink 破損 / 不正戦略 / duplicate 戦略)
- `agents/DISPATCH_MATRIX.md`: Phase 5-6 alt mode (swarm) を tinker と並列で記載

### Notes
- **完全 opt-in / 後方互換**: swarm mode は `mode: tinker-swarm` 明示時のみ。既存ワークフロー
  (8-phase / single-agent tinker) はそのまま動作。
- karpathy attribution は SKILL.md / swarm_init.sh / swarm_protocol.md / 5 program 雛形 / README ja+en /
  CHANGELOG / DISPATCH_MATRIX / tinker_loop.md 等の **計 12+ 箇所** で明示。
- Cross-pollination は agent の戦略に sub-ordinate。orchestrator は強制しない。
  `random-restart` agent は global best を読まない (purity 維持)。
- 価格 / 試算は v0.5.0 / v0.8.0 の既存機能を再利用 (catalog 修正不要)。

## [0.9.0] - 2026-05-10 — Autonomous Tinker Mode (karpathy-inspired)

### Acknowledgement
本リリースは [karpathy/autoresearch](https://github.com/karpathy/autoresearch) (Andrej Karpathy, March 2026, MIT License) に強く着想を得ている。
コア概念 (single-file edit autonomy / fixed wall-clock budget / val_bpb 単一メトリック / `program.md` 設計) は karpathy のアイディア。
本プラグインは **そのアイディアを 8-phase ワークフローに統合する形で** 自前再実装 (コードの verbatim コピーはなし)。

### Added (Skill)
- **`research.autonomous.tinker` skill** (`skills/research.autonomous.tinker/`):
  Phase 5-6 の **alt mode** として karpathy 流の autonomous tinker loop を提供。
  agent が `tinker/train.py` 1 ファイルだけを反復編集し、固定 wall-clock budget
  (default 5 分) で nanochat-style な single-GPU LLM 訓練を overnight 自律探索する。
  - SoT: `references/tinker_loop.md` (loop 仕様、不変条件、reset/revert ポリシー、
    small-compute guide for CPU/MPS/RTX-3090/A100/H100)
  - `references/program_md_template.md`: agent 指示書 (mission / hard rules / strategy hints / stop conditions)
  - `references/train_py_template.py.txt`: **自前 ~280 行最小 GPT** (causal SDPA attention,
    AdamW, cosine LR + warmup, val_bpb 計算、karpathy attribution コメント付き)
  - `references/prepare_py_template.py.txt`: ~150 行 data prep (TinyStories or FineWeb-edu,
    自前 byte-level BPE、train/val split 固定、manifest.json で bytes_per_token を保存)
  - `references/results_log_format.md`: RESULTS.md / events.jsonl / BEST.json の format SoT
  - `references/tinker_pyproject_template.toml`: 最小依存 (torch / numpy + datasets optional、
    transformers/tokenizers は **同梱禁止** = pretrained 流入防止)

### Added (Runner)
- **`scripts/tinker_run.sh`**: timeout 付き runner
  - Pre-flight: train.py syntax check + forbidden import detection
    (`transformers` / `tokenizers` / `sentence_transformers` を block)
  - Run: `timeout TINKER_BUDGET_SECONDS train.py` で wall-clock を強制
  - Parse: `tinker/result.json` から val_bpb / wall_time / diverged を抽出
  - Update: `tinker/RESULTS.md` (markdown table) + `tinker/BEST.json` (最良 record)
  - Snapshot: 改善時のみ `tinker/history/iter_<N>.py` に train.py を commit
  - Log: `events.jsonl` に `event=tinker.iteration` (or `tinker.diverged`) を 1 行追加

### Added (Tests)
- **`tests/test_tinker_smoke.sh`** (15 sub-tests):
  template 存在 (8) / Python syntax (2) / bash syntax (1) / TOML 妥当性 (1) /
  karpathy attribution 3 箇所 (SKILL.md / train.py / tinker_run.sh)
- 全テスト 9 → **10** (tinker_smoke 追加)

### Phase 連携
- Phase 4 G3 で `04_EXPERIMENT_PLAN.md` の `mode: tinker` 選択時、Phase 5 が tinker mode に分岐
- Phase 6: `tinker_run.sh` が `events.jsonl` に統合ログ、PostToolUse hook も連動
- Phase 7: `RESULTS.md` + best `train.py` を `research.paper.draft` に渡して "tinker journal" 化
- `research.cost.estimate` で overnight USD 試算を carry-over (12 iter/h × USD/h × hours)
- `research.compute.shop` で single-GPU on-demand 推奨 (RTX-4090 / A100-80GB)

### Changed (Documentation)
- `README.md` / `README.en.md`: "Autonomous Tinker Mode (v0.9.0+)" 節追加 + skills 表 1 行
- `skills/auto-research/SKILL.md`: 関連ドキュメント一覧に tinker SKILL.md を追加
- `skills/auto-research/references/error_handling_spec.md`: Phase 6 表に tinker failure modes を追記
- `agents/DISPATCH_MATRIX.md`: Phase 5-6 alt mode (tinker) を記載
- `tests/fixtures/events_sample.jsonl`: `event=tinker.iteration` の例を追加 (schema validation で OK)

### Notes
- **完全 opt-in / 後方互換**: tinker mode は明示的に `mode: tinker` を選んだプロジェクトのみ。
  既存 `.research/<slug>/` プロジェクトはこれまで通り。
- karpathy attribution は SKILL.md / train.py / tinker_run.sh / README / CHANGELOG の 5 箇所で明示。
- 価格 / 公開価格表 / コスト試算は v0.5.0 / v0.8.0 の既存機能を利用 (catalog 修正不要)。
- データセット licensing 注意: TinyStories (default) は MIT、FineWeb-edu は ODC-BY。
  prepare.py 冒頭に明示、テスト用には小規模 TinyStories で smoke test 可能。

## [0.8.0] - 2026-05-10 — GPU Procurement Helper

### Added (Skill)
- **`research.compute.shop` skill** (`skills/research.compute.shop/`):
  - 指定 workload (gpu_type / gpu_count / duration_h) に最適な GPU 提供元をランク推奨
  - 商用 cloud / marketplace / free tier / 研究助成 を網羅した **18 provider** カタログ
  - ranking: total USD asc + tier tiebreak + region match
  - filters: `max_usd_per_hour`, `prefer_spot`, `region_preference`, `include_free`, `include_academic`
  - fuzzy fallback: 不明 gpu_type に対し catalog 内候補を 3 つ提示
  - free / academic は別 section、商用と対等扱い (アフィリエイトリンクなし、紹介手数料なし)
  - 出力: stdout markdown + `slug` 指定で `.research/<slug>/COMPUTE_PROCUREMENT.md`
  - 参照実装: `references/compute_shop.py.txt` (純 stdlib、依存なし)
  - 推奨ロジック SoT: `references/recommendation_logic.md`

### Added (CLI)
- **`scripts/find_cheap_gpu.sh`**: skill を経由しない軽量 CLI shortcut
  - `bash scripts/find_cheap_gpu.sh <gpu_type> <count> <hours> [--prefer-spot] [--max N] ...`

### Added (Tests)
- **`tests/test_compute_shop.sh`**: 8 サブテスト (catalog JSON valid / >= 12 providers /
  required fields / updated_at format / smoke / prefer-spot ranking / fuzzy fallback / academic section)
- 全テスト 8 → 9 (compute_shop test 追加)

### Catalog (18 providers, 2026 Q2 reference)

- 商用 cloud: AWS p4de/p5, GCP A3/TPU, Azure ND, Lambda Labs, CoreWeave, Paperspace, RunPod Secure, DataCrunch
- Marketplace: RunPod Community, Vast.ai, Salad, TensorDock
- Free tier: Google Colab Pro+, Kaggle, HF Spaces ZeroGPU
- Academic: GCP TRC (TPU), NSF ACCESS, 各国 HPC センター (PRACE/Cyfronet/Riken/Jülich/JADE2/AIST ABCI)

### Changed (Documentation)
- `README.md` / `README.en.md`: "Finding cheap GPU resources (v0.8.0+)" 節 + skills 表に新 skill 行
- `agents/DISPATCH_MATRIX.md`: Phase 4 に compute.shop dispatch を追記
- `skills/auto-research/SKILL.md`: 関連ドキュメント一覧 + Phase 4 ガイドに compute.shop 連携
- `skills/auto-research/references/error_handling_spec.md`: Phase 4 表に procurement 失敗 4 項目追加

### Notes
- 後方互換あり。既存ワークフローは何も変わらず、Phase 4 で compute.shop を呼ばないままでも従来通り動作。
- 価格は 2026-05-10 時点の publicly observable な reference 値。`gpu_providers.json` の `updated_at` を
  半年単位で再確認推奨 (90 日経過で skill が note、180 日で warning)。
- catalog は **アフィリエイト関係なし**、商用 / marketplace / free / academic を等しく扱う。
- ユーザー実契約価格は `.research/<slug>/cost_overrides.json` に記入し `research.cost.estimate` で実費試算。
  この override ファイルは git ignore 推奨 (秘匿契約情報のため)。

## [0.7.0] - 2026-05-09 — Internationalization

### Added (Documentation)
- **`README.en.md`**: full English version of the README, covering all features
  through v0.6.0 (install / quick start / 8-phase workflow / next-step trailer /
  cost & observability / publishing / data & comparison / examples / contributing).
- `README.md` 冒頭に英語版へのリンクバナーを追加 (`🇬🇧 English version`)
- `README.en.md` 冒頭に日本語版へのリンクを追加
- `CONTRIBUTING.md` に **Translation contributions** 節を追加:
  - 既存翻訳一覧
  - 新規言語の追加方針 (`README.<lang>.md` 命名、SoT との同期)
  - 用語の不変条件 (skill / agent / command 名、Phase / Gate 番号、version 記法は翻訳しない)

### Added (Hygiene)
- **`scripts/gzip_old_events.sh`**: events.jsonl の retention 自動化
  - デフォルト dry-run (圧縮候補表示のみ)
  - `--days N` でしきい値 (default 90)
  - `--apply` で実 gzip (元ファイル削除)
  - 圧縮後は `zcat` / `zgrep` で検索可能、schema validation は raw のみ対象

### Changed (Documentation)
- `skills/auto-research/references/data_lineage.md`: events.jsonl retention 節に
  gzip script の使い方を明記

### Notes
- 後方互換あり。日本語 README が SoT であることに変わりなし、英語版は最低限の同期。
- `gzip_old_events.sh` は `cleanup_checkpoints.sh` と同じデザイン: dry-run default、
  `--apply` で実行、スコープは 1 project の events.jsonl のみ
- 翻訳貢献は CHANGELOG `[Unreleased]` `### Documentation` で管理する方針

## [0.6.0] - 2026-05-09 — Publishing & Archival

### Added (Skill)
- **`research.publish` skill** (`skills/research.publish/`):
  - HuggingFace Hub Datasets upload (`create_repo` + `upload_folder`)
  - Zenodo DOI 取得 (REST API、`--draft` で sandbox、`--no-draft` で publish)
  - 認証: `HF_TOKEN` / `ZENODO_ACCESS_TOKEN` 環境変数 (silent skip しない、明確に error)
  - `PUBLICATION.md` 自動生成 (URL, DOI, bibtex 引用情報)
  - `STATE.json.published` フィールドに記録
  - 部分 success にも対応 (HF OK / Zenodo NG 等を分けて記録)
  - 実装バックエンド: `references/publish.py.txt` (huggingface_hub + requests)

### Added (Hygiene)
- **`scripts/cleanup_checkpoints.sh`**: retention enforcement script
  - デフォルト dry-run (誤削除防止)
  - `--days N` で経過日数しきい値 (default 30)
  - `--keep-best` で primary metric 最大の succeeded run を保護
  - `--apply` で実削除、reclaimable disk size を summary 表示

### Changed (Schema)
- `tests/schemas/state.schema.json`: optional `published` block 追加
  (hf_hub, zenodo_doi, zenodo_url, published_at)
- `tests/fixtures/state_phase8_published.json`: 公開済みプロジェクトの fixture を追加

### Changed (Documentation)
- `skills/auto-research/references/data_lineage.md`:
  - "Retention 強制 (v0.6.0+)" セクション (cleanup_checkpoints.sh の使い方、checkpoint 保持判断表)
  - "Publishing & Archival (v0.6.0+)" セクション (HF Hub / Zenodo 公開フロー)
- `skills/auto-research/references/error_handling_spec.md`: Phase 8 表に publish 関連 7 項目追加
- `skills/auto-research/SKILL.md`: 関連ドキュメント一覧を更新

### Notes
- 後方互換あり。既存 `.research/<slug>/` プロジェクトは `published` フィールド無しで継続利用可。
- `research.publish` は **完全 opt-in**。token を設定しない既存ユーザーは何も変わらない。
- Zenodo published version は変更不能なため、本番公開前に必ず `--draft` (sandbox) で動作確認推奨。
- cleanup script は **デフォルト dry-run**。`--apply` を明示しない限り削除しない。

## [0.5.0] - 2026-05-09 — Cost Tracking & Observability

### Added (Skill)
- **`research.cost.estimate` skill** (`skills/research.cost.estimate/`):
  - 各 run の compute cost (USD) を `duration × usd_per_hour × gpu_count` で試算
  - project 累積コスト + budget watch (50% safe / 80% caution / 100% over)
  - GPU 単価表 (`references/gpu_price_table.json`) に A100/H100/H200/L40S/L4/RTX-4090/TPU 等を収録
  - ユーザー側 `cost_overrides.json` で実契約価格を上書き可能
  - 実装バックエンド: `references/cost_estimate.py.txt`
  - 出力: `06_RUNS/<id>/metrics.json` の `cost_estimate` ブロック + `06_COST_REPORT.md`

### Added (Observability — opt-in)
- **W&B / MLflow / TensorBoard 統合** (環境変数で有効化、未設定時は silent no-op):
  - `WANDB_API_KEY`, `WANDB_PROJECT`, `WANDB_MODE`
  - `MLFLOW_TRACKING_URI`, `MLFLOW_EXPERIMENT_NAME`
  - `TB_LOG_DIR`
- `pyproject_template.toml` に `wandb` / `mlflow` / `tensorboard` extras を追加
  (`uv sync --extra wandb` で個別 install)
- `research.experiment.scaffold/references/observability_setup.md` — 統合方針と
  helper 実装 (`observability_init/log_metric/finalize`)
- `research.experiment.scaffold/SKILL.md`: scaffold 時に観測 backend helper を
  `src/<pkg>/observability.py` として展開する手順を追加

### Changed (Schema)
- `tests/schemas/metrics.schema.json`: optional `cost_estimate` block を追加
  (duration_h, gpu_type, gpu_count, usd, usd_per_hour, pricing_source, estimated_at)
- `tests/fixtures/metrics_sample.json`: `cost_estimate` の例を追記

### Changed (Documentation)
- `skills/auto-research/references/error_handling_spec.md`: Phase 6 表に
  「compute budget 超過」「W&B/MLflow init 失敗」「W&B server 到達不能」の 3 項目を追加
- `skills/auto-research/SKILL.md`: 関連ドキュメント一覧を更新

### Notes
- 後方互換あり。`cost_estimate` block は metrics.json で **optional**、既存 run には
  影響しない (新規 run 完了時に skill が dispatch されると追記される)。
- W&B / MLflow / TensorBoard は **完全 opt-in**。環境変数を設定しない既存ユーザーには
  既存 `events.jsonl` ログ動作が維持される。
- 価格表は **publicly observable な reference 値**。実費とのずれは
  `cost_overrides.json` で個別補正してください。

## [0.4.0] - 2026-05-09 — Cross-Project Comparison & Export

### Added (Skills)
- **`research.cross.compare` skill** (`skills/research.cross.compare/`):
  複数プロジェクトの primary metric を集約し、paired bootstrap (B=10000) /
  Welch's t-test、Cohen's d / Cliff's delta、Holm-Bonferroni、ranking 表、
  比較図 (matplotlib / seaborn colorblind palette) を含むレポートを生成。
  `scripts/cross_compare.sh` の上位互換 (シェル script は引き続き軽量集約用に残す)。
- **`research.export` skill** (`skills/research.export/`):
  publication grade な共有 bundle を生成。
  - `MANIFEST.json` (commit SHA, dependency, project state)
  - `INTEGRITY.txt` (各ファイル sha256)
  - **events.jsonl の PII redaction**: `prompt` / `input_text` / `output_text` を
    sha256 hex 16 文字に置換、`/home/<user>/` を `<HOME>/` に正規化
  - schema validation で `STATE.json` が `state.schema.json` 準拠か検証

### Added (Documentation)
- **`examples/llm-eval-mmlu-baseline/`** — Phase 4 / G3 通過状態の実プロジェクト
  サンプル。`STATE.json`, `01_BRIEF.md`, `02_SURVEY/{papers.jsonl, MATRIX.md, notes/}`,
  `03_GAP_ANALYSIS.md`, `03_IDEAS.md`, `04_EXPERIMENT_PLAN.md` を実物で同梱。
  「具体的にどの粒度で書くのか」がすぐ理解できる。
- **`skills/auto-research/references/error_handling_spec.md`** — 8 Phase × 各 skill の
  failure mode カタログ。検出 / 回復手順 / エスカレーションルール (2 回連続→確認、
  3 回連続→強制 rollback) を明文化。

### Changed
- `skills/auto-research/SKILL.md`: 関連ドキュメント一覧に
  `error_handling_spec.md` を追加

### Notes
- 後方互換あり。既存 `.research/<slug>/` プロジェクトはそのまま継続利用可。
- `scripts/cross_compare.sh` / `scripts/export_project.sh` は引き続き軽量 utility として
  残し、新 skill は publication / 統計 grade の上位機能を提供する。

## [0.3.0] - 2026-05-09 — Production Hardening

### Added (Infrastructure)
- **`tests/` ディレクトリ** (8 test scripts + 5 STATE.json fixtures + 3 JSON Schemas):
  `state_schema`, `events_schema`, `metrics_schema`, `hook_smoke`,
  `init_state_idempotent`, `version_triple`, `json_manifests`, `bash_syntax`,
  および driver `run_all.sh`。`bash tests/run_all.sh` 全 pass を release 必須条件化。
- **`.github/workflows/`**:
  - `lint.yml` — push / PR で `tests/run_all.sh` 全項を実行
  - `release.yml` — tag (`vX.Y.Z`) push で manifest 三箇所一致 + CHANGELOG エントリ存在を検証
- **JSON Schemas** (`tests/schemas/`):
  - `state.schema.json` (`STATE.json`)
  - `events.schema.json` (`events.jsonl` 1 行)
  - `metrics.schema.json` (`metrics.json`)

### Added (Governance)
- `LICENSE` (MIT 全文; これまで `plugin.json` の `"license": "MIT"` のみだった)
- `CONTRIBUTING.md` (PR/branch/Conventional Commits/レビュー基準)
- `.github/ISSUE_TEMPLATE/{bug_report,feature_request,installation_issue}.md`
- `.github/PULL_REQUEST_TEMPLATE.md` (RELEASING.md checklist 埋込)
- `agents/DISPATCH_MATRIX.md` — 5 subagents × 8 phases の dispatch SoT

### Added (Data infrastructure)
- `skills/auto-research/references/data_lineage.md` — データ分類表
  (検証 / retention / git track / 公開方針) の SoT
- `templates/research-gitignore.txt` — ユーザー側
  `.gitignore` に追記するテンプレ (checkpoint / cache / dataset を ignore)
- `scripts/cross_compare.sh <slug1> <slug2> ...` — 複数プロジェクトの primary metric を 1 表で集約
- `scripts/export_project.sh <slug>` — 共有/公開向けの tar.gz bundle (checkpoint と cache を除外)
- `skills/research.experiment.run/SKILL.md` に
  `06_RUNS/INDEX.md` 自動更新 step を追加

### Changed
- **`.mcp.json`**: 実機検証で匿名スキャフォールドと判明した
  `huggingface-mcp-server` の同梱を停止。残り 2 (`semantic-scholar`, `github`) は実機起動確認済み。
  README で代替手段を案内。
- **`hooks/hooks.json`**: PostToolUse の `timeout` を `5` → `30` 秒に拡大
- **`hooks/post-experiment-log.sh`**: silent fail を可視化
  (jq 不在時 / append 失敗時に stderr 警告)。`level=error` のとき `error_type` / `error_message` を含めるよう
  `events.schema.json` に準拠化
- `skills/auto-research/SKILL.md`: 関連ドキュメント一覧に `data_lineage.md` と `DISPATCH_MATRIX.md` を追加

### Notes
- 後方互換あり (既存 `.research/<slug>/` プロジェクトは継続利用可)
- 既存ユーザーが HF Hub MCP を使っていた場合のみ、ユーザー側 `~/.claude.json` に独自設定を移す必要あり

## [0.2.1] - 2026-05-09

### Documentation
- README.md: v0.2.0 で追加した next-step trailer の解説節 (例 + 特殊状態の挙動表) を追加。
  v0.2.0 を README 未更新のまま出してしまった (doc drift) ので follow-up patch として補完。
- RELEASING.md: pre-release checklist に「ドキュメントが新バージョンと同期している」
  ブロックを追加。新機能を README に反映せずに release するのを禁止する旨を明記。

### Notes
- code 変更なし。doc-only release。
- 今後は機能追加 (MINOR) を出す前に、その変更点が README にも書かれていることを必ず確認する。

## [0.2.0] - 2026-05-09

### Added
- **Next-step trailer**: 全 6 コマンドの完走時に、Phase 進捗バー (●○) と
  最後通過したゲートマーカー (`G{n} ✓`)、推奨次コマンド + 代替を統一
  フォーマットで必ず出力する。`STATE.json` の `current_phase` /
  `last_gate_passed` / `completed_at` / `rollbacks` を読んで動的に切り替え。
- 表示仕様の単一ソース: `skills/auto-research/references/next_steps_template.md`
  - §1: literal フォーマット (罫線・進捗バー・代替欄)
  - §2: STATE.json → 推奨マッピング表 (10 ケース)
  - §3: 特殊状態 (sanity 失敗 / G4 ロールバック / 複数 active project /
    全 run 失敗 / 完了プロジェクト / STATE.json 不在)
  - §5: 不変条件 (進捗バー桁数、罫線文字、コードブロック禁止 等)

### Changed
- `commands/research-{start,design,experiment,write,review,status}.md`:
  本文末尾に「完了時の出力 (必須)」セクションを追加し、共通テンプレートを参照。
- `skills/auto-research/SKILL.md`: 「Phase 完了時の Next-Step Trailer (必須)」
  節と関連ドキュメント一覧を追加。

### Notes
- 後方互換あり。既存の `.research/<slug>/` プロジェクトはそのまま利用可能。
- 出力体験のみの変更で、ワークフロー (8 phases / 4 gates) や
  各 skill / agent / hook のロジックは不変。

## [0.1.3] - 2026-05-09

### Changed
- Documented invocation form is now plugin-prefixed: `/auto-research:research-start`
  (and the five sibling commands). v0.1.2 had switched the displayed form to
  the bare `/research-start`, but `/help` actually shows the namespaced form
  whenever the plugin is the canonical owner of the command. The bare form may
  still work as an alias when there is no name conflict, but the README,
  CHANGELOG, command files, and `phase_state_machine.md` now uniformly show
  the namespaced form so that pasted snippets match what `/help` displays.

### Notes
- No behavioural change. Both `/auto-research:research-start ...` and (when no
  conflict exists) `/research-start ...` resolve to the same command.

## [0.1.2] - 2026-05-09

### Fixed
- README.md, command files, CHANGELOG, and `phase_state_machine.md` referenced
  the wrong invocation syntax `/research:start` etc. Subdirectory-based command
  namespacing in Claude Code does **not** produce a colon (`/foo:bar`) in the
  invocation — the colon form is purely a `/help` display label. The actual
  command is `/auto-research:research-start`, `/auto-research:research-design`, ..., `/auto-research:research-status`,
  matching the file names under `commands/`.
- Removed non-standard frontmatter fields (`argument-hint`, `effort`,
  `allowed-tools`) from all 6 `SKILL.md` files. The Claude Code skill spec only
  recognises `name`, `description`, and (optional) `version`. The extra fields
  may have caused skills to be silently skipped during plugin install.

### Notes
- No code or workflow change. Existing `.research/<slug>/` projects from a
  v0.1.0 / v0.1.1 install remain compatible.

## [0.1.1] - 2026-05-09

### Fixed
- `.claude-plugin/plugin.json`: removed invalid string-typed fields
  `agents`, `skills`, `commands`, `hooks` that caused
  `Validation errors: agents: Invalid input` during `/plugin install`.
  Components are now resolved by Claude Code's auto-discovery from the
  standard directories (`agents/`, `skills/`, `commands/`, `hooks/`).
  No behavioural change — install path is the only difference.

## [0.1.0] - 2026-05-09

### Added
- Initial plugin scaffold (`plugin.json`, `.mcp.json`).
- 8-phase / 4-gate research workflow (`skills/auto-research/`).
- Phase-specific skills:
  - `research.literature.matrix` — paper comparison table
  - `research.experiment.scaffold` — uv/PyTorch/HF project bootstrap
  - `research.experiment.run` — reproducible execution + JSONL events
  - `research.paper.draft` — LaTeX/Markdown paper drafting
  - `research.attention.probe` — mechanistic interpretability setup
- Five specialist subagents:
  - `paper-deep-reader`, `research-gap-finder`, `experiment-designer`,
    `attention-analyst`, `result-statistician`
- Six entry-point commands: `/auto-research:research-start`, `/auto-research:research-design`,
  `/auto-research:research-experiment`, `/auto-research:research-write`, `/auto-research:research-review`,
  `/auto-research:research-status`.
- `PostToolUse` hook (`post-experiment-log.sh`) that captures every
  `uv run` invocation into `events.jsonl` for reproducibility.
- Bundled MCP servers: Semantic Scholar, HuggingFace Hub, GitHub.
  arxiv-mcp-server is reused from user config (not bundled).
