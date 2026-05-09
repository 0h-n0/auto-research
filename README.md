# auto-research

LLM 研究のフルライフサイクルを Claude Code 上で一気通貫で進めるためのプラグイン。
論文サーベイ → アイディア検証 → 実験設計・実装・実行 → 論文ドラフトまでを **8 phases / 4 user gates** の自動ワークフローでカバーする。

研究フォーカス領域:
- Evaluation & Benchmarking
- Agent / Tool-use 研究
- Fine-tuning / Post-training (SFT, RLHF, DPO, LoRA, ...)
- Prompt / In-context Learning
- **Attention 機構・LLM アーキテクチャ内部 (mechanistic interpretability)**

## 前提

- Python (uv) + PyTorch + HuggingFace Transformers
- 既存設定済みの [`arxiv-mcp-server`](https://github.com/blazickjp/arxiv-mcp-server) (本プラグインは同梱しない)
- (推奨) Semantic Scholar / HuggingFace Hub / GitHub の API トークン

## インストール (ローカル)

このプラグインはまだ marketplace に公開していません。お手元のディレクトリから直接インストールできます。
公式ドキュメント: <https://docs.claude.com/en/docs/claude-code/plugins>

### 方法 A: ローカル marketplace 経由 (Recommended、永続)

`.claude-plugin/marketplace.json` を同梱しています。Claude Code セッション内で:

```text
/plugin marketplace add ~/path/to/auto-research
/plugin install auto-research@auto-research
```

- `/plugin marketplace add <path>` でこのディレクトリを marketplace として登録
- `/plugin install auto-research@auto-research` で実プラグインを有効化
   (`<plugin-name>@<marketplace-name>` 形式。両方 `auto-research` なので二重)

確認:

```text
/plugin list           # 有効なプラグイン一覧
/help                  # /research:start ... が見えれば成功
```

無効化したいときは `/plugin uninstall auto-research@auto-research`、
marketplace ごと外すなら `/plugin marketplace remove auto-research`。

### 方法 B: CLI フラグ (一時的、設定変更なし)

そのセッションだけ有効化したい場合:

```bash
claude --plugin-dir ~/path/to/auto-research
```

Claude Code を起動するたびに指定が必要。検証用途向け。

### 方法 C: シンボリックリンク (手動、最小)

marketplace を使わずユーザースコープに直接展開:

```bash
PLUGIN=~/path/to/auto-research

# skills を ~/.claude/skills/ に
for d in "$PLUGIN"/skills/*/; do
  ln -sf "$d" "$HOME/.claude/skills/$(basename "$d")"
done

# agents を ~/.claude/agents/ に
for f in "$PLUGIN"/agents/*.md; do
  ln -sf "$f" "$HOME/.claude/agents/$(basename "$f")"
done

# commands を ~/.claude/commands/ に
mkdir -p "$HOME/.claude/commands"
for f in "$PLUGIN"/commands/*.md; do
  ln -sf "$f" "$HOME/.claude/commands/$(basename "$f")"
done
```

PostToolUse hook と `.mcp.json` は手動マージが必要 (`~/.claude/settings.json` と `~/.claude.json` を編集)。
シンプルさを取るなら方法 A 推奨。

### 動作確認

```text
/help
```

以下が表示されれば成功:

```
/research:start    新規 LLM 研究プロジェクトを開始 ...
/research:design   Gap 分析・アイディア抽出と実験設計 ...
/research:experiment
/research:write
/research:review
/research:status
```

skill / agent も `/skills` および `Agent` ツールから参照できることを確認:

```text
> 「auto-research skill を使って "test topic" で Phase 1 の dry-run をして」
```

### MCP サーバーの取り扱い

`.mcp.json` で Semantic Scholar / HuggingFace Hub / GitHub の MCP を同梱しています。
**初回起動時に Claude Code が確認ダイアログを表示するので承認**してください。

未使用にしたい場合:

- `~/.claude/settings.json` の `enabledMcpjsonServers` から外す、または
- 関連環境変数 (`SEMANTIC_SCHOLAR_API_KEY`, `HF_TOKEN`, `GITHUB_PERSONAL_ACCESS_TOKEN`) を未設定のままにすると認証なしで起動するもののレート制限が厳しくなります

`arxiv-mcp-server` は **本プラグインに同梱しません**。事前に
[blazickjp/arxiv-mcp-server](https://github.com/blazickjp/arxiv-mcp-server) を
ユーザー側 `~/.claude.json` で設定済みであることを前提とします。

### アンインストール

方法 A:

```text
/plugin uninstall auto-research@auto-research
/plugin marketplace remove auto-research
```

方法 C (symlink) で入れた場合:

```bash
# ~/.claude/skills, agents, commands から auto-research 関連の symlink を削除
find ~/.claude/skills ~/.claude/agents ~/.claude/commands -lname "*my-plugins/auto-research*" -delete
```

## クイックスタート

```text
/research:start "attention sink in long-context Llama"
# Phase 1 (Topic Framing) → G1
# Phase 2 (Literature Survey) → MATRIX.md 生成

/research:design
# Phase 3 (Gap & Ideation) → G2
# Phase 4 (Experiment Design) → G3

/research:experiment
# Phase 5 (Scaffold + Baseline TDD)
# Phase 6 (Run & Analysis)

/research:write
# Phase 7 (Paper Drafting)

/research:review
# Phase 8 (Self-Review) → G4

/research:status
# 現在の Phase / 直近 run / 次のアクション
```

## ワークフロー (8 phases / 4 gates)

| # | Phase | 主担当 | 主成果物 | Gate |
|---|-------|--------|----------|------|
| 1 | Topic Framing | `auto-research` skill | `01_BRIEF.md` | **G1** |
| 2 | Literature Survey | `arxiv-mcp-agent` + `paper-deep-reader` ×N | `02_SURVEY/MATRIX.md` | — |
| 3 | Gap & Ideation | `research-gap-finder` ×3 | `03_IDEAS.md` | **G2** |
| 4 | Experiment Design | `experiment-designer` | `04_EXPERIMENT_PLAN.md` | **G3** |
| 5 | Scaffold + TDD | `research.experiment.scaffold` + `ml-engineer` | `code/` | — |
| 6 | Run & Analysis | `research.experiment.run` + `result-statistician` + `attention-analyst` | `06_RUNS/`, `06_RESULTS.md` | — |
| 7 | Paper Drafting | `research.paper.draft` | `paper/main.{tex,md}` | — |
| 8 | Self-Review | `research-gap-finder` (re-cast) + `gemini` | `08_REVIEW.md` | **G4** |

各プロジェクトは `.research/<slug>/` 配下に成果物を蓄積し、`STATE.json` で再開可能。

## 主要コンポーネント

### Skills

| skill | 役割 |
|-------|------|
| `auto-research` | メインワークフロー (state machine + Phase dispatch) |
| `research.literature.matrix` | 論文比較表生成 (固定スキーマ + mutex) |
| `research.experiment.scaffold` | `uv` プロジェクト雛形生成 |
| `research.experiment.run` | 再現性ある実行 + JSONL ログ |
| `research.paper.draft` | LaTeX/Markdown 論文ドラフト |
| `research.attention.probe` | TransformerLens / nnsight ベース介入プロトコル |

### Subagents

| agent | 専門 |
|-------|------|
| `paper-deep-reader` | 単一論文 derivation-level 読解 |
| `research-gap-finder` | cross-paper 統合・研究ギャップ抽出 |
| `experiment-designer` | RQ → 仮説 → ablation 表 → 統計検定 |
| `attention-analyst` | mechanistic interpretability (logit lens / patching / probing / SAE) |
| `result-statistician` | bootstrap / Wilcoxon / Cohen's d / 可視化 |

既存の `~/.claude/agents/arxiv-mcp-agent` と `ml-engineer` を最大限再利用します (重複させません)。

### Hook

`PostToolUse` で `uv run *` 実行を全て捕捉し、`.research/<slug>/06_RUNS/<run_id>/events.jsonl` に
`{event, level, ts, run_id, duration_ms, exit_code, git_rev, stdout_tail}` を 1 行 JSON で追記します。**研究再現性の最重要装置**。

## 倫理・コンプライアンス

- arXiv は再配布 OK だが商用ジャーナル PDF はキャッシュしません。`notes/` には要約 + メタのみ保存、原文引用は ≤ 2 文。
- 評価データセットの汚染チェック (`eval_protocol.md` 必須項目)
- LLM-author 開示欄を `paper/` テンプレに同梱 (NeurIPS/ICLR/ACL ポリシー準拠)

## ライセンス

MIT
