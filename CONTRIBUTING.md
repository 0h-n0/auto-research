# Contributing to `auto-research`

このプラグインへの貢献ガイド。issue / PR を出す前に一読してください。

## TL;DR

- **bug**: `.github/ISSUE_TEMPLATE/bug_report.md` を使う
- **feature**: `.github/ISSUE_TEMPLATE/feature_request.md` を使う
- **install エラー**: `.github/ISSUE_TEMPLATE/installation_issue.md` を使う
- **PR**: `bash tests/run_all.sh` が green な状態で開く。テンプレに従う
- **release**: `RELEASING.md` の手順を厳守 (tests / docs sync は必須)

## 開発ワークフロー

1. issue を立てる (bug / feature / question 何でも先に対話するのが安全)
2. fork → feature ブランチ (`fix/issue-123-foo` or `feat/cross-compare`)
3. ローカルで実装
4. `bash tests/run_all.sh` が **全 pass** することを確認
5. README / CHANGELOG / 関連 docs を更新 (RELEASING.md ルール準拠)
6. commit (Conventional Commits、後述)
7. push → PR を main に対して開く

## Commit メッセージ規約 (Conventional Commits)

```
<type>(<scope>): <subject>

<body>

<footer>
```

| type | 用途 |
|------|------|
| `feat` | 新機能 (MINOR bump 候補) |
| `fix` | バグ修正 (PATCH bump 候補) |
| `docs` | ドキュメントのみ |
| `chore` | リリース、依存更新、その他雑務 |
| `refactor` | 動作変更なしの構造改善 |
| `test` | テスト追加・修正 |
| `ci` | CI/CD 関連 |
| `revert` | revert コミット |

scope は省略可。`feat(commands): ...`, `fix(hooks): ...`, `docs(readme): ...` など。

例:
- `feat(commands): next-step trailer after every command (v0.2.0)`
- `fix(hooks): stop silently failing on jq parse errors`
- `docs(release): clarify SemVer policy for plugin/skill changes`

破壊的変更は `<type>!: ...` または body に `BREAKING CHANGE:` を含める。

## ブランチ運用

- `main` は常に release 可能な状態に保つ (CI green、tests pass)
- 直接 `main` に push しない (作者の hotfix を除き、PR 経由)
- master / main への force push は厳禁

## PR レビュー基準

レビュアーは以下を確認:

1. `bash tests/run_all.sh` が green か (CI lint.yml で自動)
2. README / CHANGELOG が変更内容と同期しているか
3. Conventional Commits 準拠か
4. SoT (Single Source of Truth) の重複が増えていないか
   - `phase_state_machine.md` (state machine)
   - `next_steps_template.md` (trailer 表示)
   - `data_lineage.md` (data retention)
   - `RELEASING.md` (release 手順)
5. 新規 skill / agent / command は frontmatter 仕様に準拠しているか
   - skill: `name`, `description` のみ (`allowed-tools` 等の非標準 field 不可)
   - agent: `name`, `description`, `tools`, `model`, `color` (frontmatter)
   - command: `description`, `argument-hint`, `allowed-tools`

## リリース

`main` へのマージ後、release は **メンテナのみ** が `RELEASING.md` の手順で実施する。
コントリビューターは `[Unreleased]` セクションにエントリを追加するだけで OK。
リリース毎に CHANGELOG / README / 3 箇所の version が必ず同期される。

## 倫理規定

研究データ (論文、データセット、モデル checkpoint) を扱うため:

- **PII を含むデータをコミットしない** (events.jsonl の prompt 全文等)
- 商用ジャーナル PDF をリポジトリに置かない
- LLM-author 開示節を変更する PR は理由を必ず説明
- 詳細: `skills/auto-research/references/responsible_research.md`

## 質問・相談

GitHub Discussions (作成予定) または issue で気軽にどうぞ。
