# Release Procedure

このプラグインのバージョン管理ポリシーとリリース手順。**毎リリース、この通りに従う**。

## Versioning Policy

[Semantic Versioning 2.0.0](https://semver.org/) に厳格に準拠する。

| 変更内容 | bump |
|----------|------|
| 既存 skill / agent / command の **break change** (signature, frontmatter, output schema) | **MAJOR** (`X.0.0`) |
| 新機能 (skill/agent/command 追加、後方互換あり) | **MINOR** (`0.X.0`) |
| バグ修正、ドキュメント、内部 refactor (後方互換あり) | **PATCH** (`0.0.X`) |
| `0.x.y` 期間中の break change | MINOR で OK (但し CHANGELOG で明示) |

### 例

- `auto-research` skill の Phase 数を 8 → 10 に変える → MAJOR
- 新 skill `research.benchmark.compare` を追加 → MINOR
- `paper-deep-reader` の説明文を改善 → PATCH
- `events.jsonl` の必須フィールドを変更 → MAJOR (consumer が壊れる)

## Pre-release Checklist

```text
[ ] CHANGELOG.md に新バージョンの ## [X.Y.Z] - YYYY-MM-DD エントリを追加
    - Added / Changed / Deprecated / Removed / Fixed / Security の見出しで分類
[ ] バージョンを 3 箇所で更新:
    [ ] .claude-plugin/plugin.json の "version"
    [ ] .claude-plugin/marketplace.json の metadata.version
    [ ] .claude-plugin/marketplace.json の plugins[0].version
[ ] `jq -r '.version' .claude-plugin/plugin.json` 等で 3 箇所一致を確認
[ ] PII / 秘密情報スキャン (kbu94981, /home/<user>/, secrets, tokens など)
[ ] hooks/post-experiment-log.sh の bash -n 構文チェック
[ ] scripts/init_state.sh のべき等性確認 (2 回実行)
[ ] JSON manifests の jq -e . 検証
[ ] README.md の「インストール」「クイックスタート」手順が有効か手動確認
[ ] 主要 skill / agent / command が壊れていないか smoke test
```

## Release Steps

```bash
# 1. main ブランチで pre-release checklist 完了済みであること
git status                       # working tree clean
git log --oneline -5

# 2. 通常コミット (CHANGELOG + version bump)
git add CHANGELOG.md .claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "chore(release): vX.Y.Z"
git push origin main

# 3. annotated tag を作成 (release notes 兼用)
git tag -a vX.Y.Z -m "auto-research vX.Y.Z

<bullet summary of major user-facing changes>
"
git push origin vX.Y.Z

# 4. GitHub Release を作成 (tag に紐付ける)
gh release create vX.Y.Z \
  --title "vX.Y.Z — <short tagline>" \
  --notes-file <(awk '/^## \[X.Y.Z\]/,/^## \[/' CHANGELOG.md | sed '$d') \
  --verify-tag

# (major release のみ) latest を pin
gh release edit vX.Y.Z --latest
```

## Post-release

```text
[ ] gh release view vX.Y.Z で notes の表示崩れがないか確認
[ ] /plugin marketplace update auto-research を行ったクリーン環境で
    /plugin install auto-research@auto-research が成功するか確認
[ ] CHANGELOG.md 冒頭に [Unreleased] セクションを追加 (次回 bump 用)
```

## Hotfix (PATCH)

main で破壊的でないバグ修正のみの場合:

1. `git checkout main && git pull`
2. fix → CHANGELOG `## [X.Y.Z+1]` エントリ → version bump (3 箇所)
3. 通常通り tag + release
4. ブランチ切らずに main 直で OK (但し PR レビューを推奨する場合は適宜 worktree 利用)

## Breaking Change (MAJOR)

1. CHANGELOG `### Removed` / `### Changed` で **migration note** を必ず添える
2. README に migration セクションを追加
3. リリースノート冒頭に `⚠️ Breaking changes` 見出し
4. (任意) 旧 MAJOR 系列の最新 PATCH を `vX.Y.Z` で並行リリース可能に

## Tag 命名規則

- 通常: `vMAJOR.MINOR.PATCH` (例: `v0.1.0`, `v1.2.3`)
- pre-release: `vMAJOR.MINOR.PATCH-rc.N` (例: `v1.0.0-rc.1`)
- pre-release は GitHub Release の "Set as a pre-release" を ON にする

## Yanking a release (緊急時)

不正なリリースを公開してしまった場合:

```bash
# tag は残すが Release を draft 化
gh release edit vX.Y.Z --draft

# または GitHub Release を削除 (tag は保持して reference を残す)
gh release delete vX.Y.Z
```

破棄ではなく **次の PATCH で fix forward** を第一選択。
