---
name: Installation issue
about: /plugin install または /plugin marketplace add で失敗 / コマンドが見えない
title: "[INSTALL] "
labels: install
assignees: 0h-n0
---

## どの方法で install したか

- [ ] 方法 A: `/plugin marketplace add <path>` + `/plugin install ...`
- [ ] 方法 B: `claude --plugin-dir <path>`
- [ ] 方法 C: symlink

## 環境

- auto-research version: (取得元のタグ or commit SHA)
- Claude Code version:
- OS:

## 実際のエラーメッセージ

```
<install ダイアログ・コンソール出力をここに貼る>
```

## /help 出力 (install 後)

```
<貼る>
```

## /plugin list 出力

```
<貼る>
```

## 試した workaround

- [ ] `/plugin marketplace update auto-research`
- [ ] `/plugin uninstall ...` → 再 install
- [ ] Claude Code 再起動
- [ ] その他 (記述)

## 補足

設定ファイル (`~/.claude/settings.json` の関連部分、PII を伏せて) など。
