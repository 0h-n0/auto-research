# Pull Request

## 概要

何を変えるか / 解決する issue (`Fixes #123` など)。

## 種類

- [ ] feat (新機能 — MINOR bump 候補)
- [ ] fix (バグ修正 — PATCH bump 候補)
- [ ] docs (ドキュメントのみ)
- [ ] chore / refactor / test / ci

## 変更内容

- ...
- ...

## チェックリスト

`RELEASING.md` の pre-release checklist を準拠:

- [ ] `bash tests/run_all.sh` 全 pass
- [ ] CHANGELOG.md `[Unreleased]` セクションにエントリを追加
- [ ] 関連ドキュメントを更新 (README / SKILL.md / RELEASING.md / 該当 references)
- [ ] **新機能を伴う場合: README にもその機能の記載を追加**
- [ ] PII / シークレット混入なし (`grep` でスキャン)
- [ ] Conventional Commits 形式の commit メッセージ
- [ ] frontmatter 仕様に準拠 (skill = name+description のみ、command = 標準 fields)

## SemVer 影響

- 後方互換: yes / no
- bump 候補: MAJOR / MINOR / PATCH
- 既存 `.research/<slug>/` プロジェクトへの影響: あり / なし

(影響あり の場合、migration の必要性を本文または別 issue で明示)

## 動作確認

実際に動かして確認した手順:

```
<例: 新規プロジェクト作成 → /auto-research:research-start "test" → trailer 出る>
```

## 補足
