# Changelog

All notable changes to the `auto-research` plugin are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project adheres to [Semantic Versioning](https://semver.org/).
Release procedure: see [RELEASING.md](./RELEASING.md).

## [Unreleased]

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
