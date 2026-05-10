# auto-research

🇯🇵 [日本語版](README.md)

[![lint](https://github.com/0h-n0/auto-research/actions/workflows/lint.yml/badge.svg)](https://github.com/0h-n0/auto-research/actions/workflows/lint.yml)
[![release](https://img.shields.io/github/v/release/0h-n0/auto-research)](https://github.com/0h-n0/auto-research/releases)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A Claude Code plugin that drives the **full LLM-research lifecycle** end to end:
literature survey → idea validation → experiment design / implementation / execution → paper drafting → publication.
Everything is structured as **8 phases / 4 user gates** so a human stays in the loop at the moments that actually matter.

Research focus areas:

- Evaluation & Benchmarking
- Agent / Tool-use research
- Fine-tuning / Post-training (SFT, RLHF, DPO, LoRA, …)
- Prompt / In-context Learning
- **Attention / LLM internals (mechanistic interpretability)**

## Prerequisites

- Python (uv) + PyTorch + HuggingFace Transformers
- An already-configured [`arxiv-mcp-server`](https://github.com/blazickjp/arxiv-mcp-server) (this plugin does not bundle it)
- (Recommended) API tokens for Semantic Scholar / HuggingFace Hub / GitHub / Zenodo

## Local installation

This plugin is not yet on a public marketplace. Install it directly from your local checkout.
Official Claude Code plugin docs: <https://docs.claude.com/en/docs/claude-code/plugins>

### Method A: local marketplace (Recommended, persistent)

`.claude-plugin/marketplace.json` is bundled. Inside a Claude Code session run:

```text
/plugin marketplace add ~/path/to/auto-research
/plugin install auto-research@auto-research
```

- `/plugin marketplace add <path>` registers this directory as a marketplace
- `/plugin install auto-research@auto-research` enables the actual plugin
   (the `<plugin-name>@<marketplace-name>` form happens to be doubled because both share the name `auto-research`)

Verify:

```text
/plugin list   # active plugins
/help          # if you can see /auto-research:research-start, you're good
```

To remove: `/plugin uninstall auto-research@auto-research` and (optionally) `/plugin marketplace remove auto-research`.

### Method B: CLI flag (one-shot, no config change)

For a single session:

```bash
claude --plugin-dir ~/path/to/auto-research
```

Useful for evaluation; you have to pass the flag every time.

### Method C: Symlinks (manual, minimal)

Skip the marketplace and link the components into your user scope:

```bash
PLUGIN=~/path/to/auto-research

# skills into ~/.claude/skills/
for d in "$PLUGIN"/skills/*/; do
  ln -sf "$d" "$HOME/.claude/skills/$(basename "$d")"
done

# agents into ~/.claude/agents/
for f in "$PLUGIN"/agents/*.md; do
  ln -sf "$f" "$HOME/.claude/agents/$(basename "$f")"
done

# commands into ~/.claude/commands/
mkdir -p "$HOME/.claude/commands"
for f in "$PLUGIN"/commands/*.md; do
  ln -sf "$f" "$HOME/.claude/commands/$(basename "$f")"
done
```

PostToolUse hook and `.mcp.json` need to be merged manually into `~/.claude/settings.json` and `~/.claude.json`.
For simplicity we recommend Method A.

### Verifying the install

```text
/help
```

You should see:

```
/auto-research:research-start    Start a new LLM research project ...
/auto-research:research-design   Gap analysis + idea selection + experiment design ...
/auto-research:research-experiment
/auto-research:research-write
/auto-research:research-review
/auto-research:research-status
```

Skills and agents are also available through `/skills` and the `Agent` tool:

```text
> "Use the auto-research skill to dry-run Phase 1 with 'test topic'"
```

### Tests (v0.3.0+)

Run the local smoke / schema / regression tests with:

```bash
bash tests/run_all.sh
# 8 tests pass / 0 fail expected
```

Dependencies: `bash`, `jq`, `python3` + `jsonschema` (or `uv`). See `tests/README.md` for details.

### MCP servers

`.mcp.json` ships **two verified servers**. Claude Code will ask for confirmation on the first launch. Approve them.

#### Bundled (verified to start)

| MCP server | Package | Purpose | Auth |
|------------|---------|---------|------|
| `semantic-scholar` | `uvx semanticscholar-mcp-server` | Phase 2 / 8 — paper metadata + citation graph + DOI completion in `refs.bib` | `SEMANTIC_SCHOLAR_API_KEY` (optional; works without but with stricter rate limit) |
| `github` | `npx -y @modelcontextprotocol/server-github` | Phase 5 / 8 — fetch official paper code + issue tracking | `GITHUB_PERSONAL_ACCESS_TOKEN` (optional for public repos) |

#### Not bundled (external prerequisite)

- **`arxiv-mcp-server`** ([blazickjp/arxiv-mcp-server](https://github.com/blazickjp/arxiv-mcp-server)) — the workhorse for paper search/fetch/read. **Configure it yourself in `~/.claude.json`**.
- **HuggingFace Hub MCP** — the PyPI package `huggingface-mcp-server` turned out to be an anonymous scaffold with no docs and Python ≥ 3.13 only, so we removed it in v0.3.0. Use the `huggingface_hub` Python library directly inside experiments, or wire your own trusted HF MCP.

#### Disabling bundled MCPs

- Remove from `enabledMcpjsonServers` in `~/.claude/settings.json`, or
- Leave the env vars unset (the servers fall back to unauthenticated mode with stricter limits)

### Uninstall

Method A:

```text
/plugin uninstall auto-research@auto-research
/plugin marketplace remove auto-research
```

Method C (symlinks):

```bash
find ~/.claude/skills ~/.claude/agents ~/.claude/commands \
  -lname "*my-plugins/auto-research*" -delete
```

## Quick start

```text
/auto-research:research-start "attention sink in long-context Llama"
# Phase 1 (Topic Framing) → G1
# Phase 2 (Literature Survey) → MATRIX.md

/auto-research:research-design
# Phase 3 (Gap & Ideation) → G2
# Phase 4 (Experiment Design) → G3

/auto-research:research-experiment
# Phase 5 (Scaffold + Baseline TDD)
# Phase 6 (Run & Analysis)

/auto-research:research-write
# Phase 7 (Paper Drafting)

/auto-research:research-review
# Phase 8 (Self-Review) → G4

/auto-research:research-status
# Current phase / latest runs / suggested next action
```

## Workflow (8 phases / 4 gates)

| # | Phase | Drivers | Outputs | Gate |
|---|-------|---------|---------|------|
| 1 | Topic Framing | `auto-research` skill | `01_BRIEF.md` | **G1** |
| 2 | Literature Survey | `arxiv-mcp-agent` + `paper-deep-reader` ×N | `02_SURVEY/MATRIX.md` | — |
| 3 | Gap & Ideation | `research-gap-finder` ×3 | `03_IDEAS.md` | **G2** |
| 4 | Experiment Design | `experiment-designer` | `04_EXPERIMENT_PLAN.md` | **G3** |
| 5 | Scaffold + TDD | `research.experiment.scaffold` + `ml-engineer` | `code/` | — |
| 6 | Run & Analysis | `research.experiment.run` + `result-statistician` + `attention-analyst` | `06_RUNS/`, `06_RESULTS.md` | — |
| 7 | Paper Drafting | `research.paper.draft` | `paper/main.{tex,md}` | — |
| 8 | Self-Review | `research-gap-finder` (reviewer mode) + `gemini` | `08_REVIEW.md` | **G4** |

Every project lives under `.research/<slug>/` and tracks itself via `STATE.json`, so you can resume any time.

### Next-Step Trailer (v0.2.0+)

Each command ends with a **trailer** built dynamically from `STATE.json`:

```
─────────────────────────────────────
[Phase 4/8] ●●●●○○○○  G3 ✓

→ Recommended: /auto-research:research-experiment <slug>
  (Scaffold + Baseline TDD)

  Alternatives:
   ・ /auto-research:research-status <slug>   check progress
   ・ /auto-research:research-design <slug>   redo G3
─────────────────────────────────────
```

Special states it handles:

| Situation | Trailer behaviour |
|-----------|-------------------|
| Normal progression | Recommend the next phase + status / previous-phase redo |
| Sanity failure (Phase 6 → 5 rollback) | Recommend re-running `research-experiment` + show failed-run details via `status` |
| G4 critical-issue review | Recommend re-entry to the rollback target phase |
| Multiple active projects | Ask for a slug, recommend `research-status` |
| Project completed (G4 ✓ + `completed_at`) | Recommend starting a new topic with `research-start` |
| `STATE.json` missing (new user) | Recommend `research-start "<topic>"` |

Single source of truth: `skills/auto-research/references/next_steps_template.md`.

## Finding cheap GPU resources (v0.8.0+)

Once the workload (GPU type / count / hours) is settled in Phase 4, `research.compute.shop` ranks the cheapest places to actually run it. The bundled catalog covers **18 providers** across four categories — commercial cloud (AWS / GCP / Azure / Lambda / CoreWeave / Paperspace / RunPod Secure / DataCrunch), marketplace (RunPod Community / Vast.ai / Salad / TensorDock), free tier (Colab Pro+ / Kaggle / HF ZeroGPU), and academic grants (GCP TRC / NSF ACCESS / national HPC centres).

```text
> "Use research.compute.shop to find the cheapest place to run A100-80GB ×1 for 24h"
```

A CLI shortcut is also available:

```bash
# Top commercial picks (under $5/h)
bash scripts/find_cheap_gpu.sh A100-80GB-SXM 1 24 --max 5.0

# Prefer spot, include academic grants
bash scripts/find_cheap_gpu.sh H100-80GB-SXM 4 168 --prefer-spot --include-academic

# Save results to the project
bash scripts/find_cheap_gpu.sh A100-80GB-SXM 1 24 --slug attention-sink
```

### Catalog transparency

- Prices are **publicly observable** reference values, with a `pricing_url` for every provider — confirm current quotes there.
- **No affiliate links, no referral fees.** Commercial, marketplace, free, and academic options are ranked on equal footing.
- Your real contract pricing (kept private) goes in `.research/<slug>/cost_overrides.json` (git-ignore is recommended).
- Catalog SoT: `skills/research.compute.shop/references/gpu_providers.json`. The skill notes when `updated_at` is 90+ days old and warns past 180 days.

## Autonomous Tinker Mode (v0.9.0+)

Inspired by [karpathy/autoresearch](https://github.com/karpathy/autoresearch) (Andrej Karpathy, 2026, MIT). When you flip Phase 4's `mode: tinker` switch, Phase 5-6 turns into an overnight autonomous loop: an agent iteratively edits a single `tinker/train.py` under a fixed wall-clock budget, racing to minimize `val_bpb`.

### Core design

1. The agent edits **only `tinker/train.py`** — model, optimizer, hparams, batch, schedule, init are all fair game.
2. **Fixed wall-clock budget per iteration** (`TINKER_BUDGET_SECONDS`, default 300 s). Comparable across whatever the agent changes. Roughly 12 iters/h, ~100 iters per overnight session.
3. **Single comparable metric** is `val_bpb` (validation bits per byte, vocab-size-independent).
4. **`program.md` is the human-iterable mission spec.** The agent reads it but never edits it.
5. Loop: train → measure → keep / discard → repeat, with each iteration appending to `tinker/RESULTS.md` and `events.jsonl`.

### Quick start

```bash
# 1. Scaffold tinker mode (Phase 5 dispatches the skill automatically)
> "Use research.autonomous.tinker to scaffold tinker mode for <slug>"

# 2. One-time data prep
cd .research/<slug>/tinker && uv sync && uv run python prepare.py

# 3. Sanity-check baseline iteration
bash scripts/tinker_run.sh <slug>

# 4. Hand the agent the loop
> "Follow program.md and run the overnight loop"
```

Each iteration:

- Appends a row to `tinker/RESULTS.md` (human-readable)
- Appends a JSON line to `06_RUNS/<run_id>/events.jsonl` (`event=tinker.iteration`)
- On improvement, snapshots `train.py` to `tinker/history/iter_<N>.py` and updates `tinker/BEST.json`

### Safety

`scripts/tinker_run.sh` does a pre-flight before every run:

- Python syntax check on `train.py`
- Forbidden-import detection (`transformers` / `tokenizers` / `sentence_transformers` → blocked to prevent pretrained-model leakage)
- Strict `timeout` (SIGTERM at budget, SIGKILL +10 s)
- OOM / divergence / runtime errors land in `events.jsonl` as `tinker.diverged`

### Small-compute guide

| Environment | DEPTH | MAX_SEQ_LEN | TOTAL_BATCH_SIZE | dataset | budget |
|-------------|-------|-------------|------------------|---------|--------|
| CPU / MPS smoke | 2 | 128 | 2^10 | TinyStories subset | 60 s |
| RTX-3090 (24GB) | 4 | 512 | 2^14 | TinyStories full | 300 s |
| A100-80GB / H100 | 8 | 1024 | 2^16 | FineWeb-edu | 300 s |

See `skills/research.autonomous.tinker/SKILL.md` and `references/tinker_loop.md` for the full loop spec.

### Acknowledgement

The core ideas (single-file edit autonomy, fixed wall-clock budget, `val_bpb`, `program.md`) are Karpathy's. This plugin re-implements them in our own minimal GPT (~280 lines) so they fit our 8-phase workflow — there is no verbatim code copy. See `skills/research.autonomous.tinker/SKILL.md` for the full attribution block.

### Domain Packs (v0.11.0+)

The autonomous tinker loop, originally specialized for LLM pretraining (v0.9.0 / v0.10.0), now ships with **three additional domains**:

| domain | dataset | starting model | metric (direction) |
|--------|---------|----------------|--------------------|
| `lm-pretrain` (default, v0.9.0+) | TinyStories / FineWeb-edu | minimal GPT (~280 LoC) | `val_bpb` (min) |
| `vision-classification` (v0.11.0+) | CIFAR-10 (torchvision) | minimal CNN (~200 LoC) | `val_acc` (max) |
| `rl-cartpole` (v0.11.0+) | CartPole-v1 (gymnasium) | REINFORCE policy (~190 LoC) | `episode_return` (max) |
| `tabular-classification` (v0.11.0+) | sklearn breast_cancer | minimal MLP (~150 LoC) | `val_acc` (max) |
| `nlp-classification` (v0.12.0+) | sklearn 20newsgroups (4-class) | TF-IDF + MLP (~150 LoC) | `val_acc` (max) |

```bash
# Single-agent tinker on a non-LLM domain
bash scripts/tinker_run.sh <slug> --domain vision-classification

# Swarm (multi-agent) on a non-LLM domain
bash scripts/swarm_init.sh <slug> --agents 3 --domain rl-cartpole
```

Each domain is a self-contained pack (`train.py.txt` / `prepare.py.txt` / `program.md` / `pyproject.toml` / `metric_spec.json`). The `metric_spec.json` declares the direction (`min` or `max`); `tinker_run.sh` compares the best direction-aware. **Fully backward-compatible**: existing `lm-pretrain` projects keep working as-is (default domain, legacy `val_bpb` field still emitted).

The five swarm strategies (depth / lr / arch / batch / random-restart) apply across all domains. The example knobs in each `program_<strategy>.md` use LLM hparams, but the underlying themes (scale / optimization / structure / batch / random) translate naturally — the agent reads them in domain context.

**Added in v0.12.0** — `skills/research.autonomous.swarm/references/strategy_adapters.md` is a single source of truth that spells out each (strategy, domain) cell: which `Config` knobs to vary, which to leave alone, and a domain-specific hint. When you run swarm mode on a non-LLM domain, the agent should read both `program_<strategy>.md` and the adapter doc before deciding on a change.

Spec: `skills/research.autonomous.tinker/references/domains/README.md`

## Research Org Swarm Mode (v0.10.0+)

Materializes the **"research org code"** future-work hint from karpathy/autoresearch's README: run **N agents in parallel** (default 3), each with a different exploration strategy, and let an orchestrator merge their bests.

### Five strategies

| strategy | what it tunes |
|----------|---------------|
| `depth-explore` | depth / n_heads / d_model / mlp_ratio (architecture scale) |
| `lr-explore` | lr / weight_decay / warmup / schedule / optimizer choice |
| `arch-explore` | attention variant / posenc / norm / activation (qualitative architecture) |
| `batch-explore` | batch / grad_accum / seq_len (throughput vs gradient noise) |
| `random-restart` | uniform random sampling (escape local optima) |

### Quick start

```bash
# 1. Scaffold N agents with one command
bash scripts/swarm_init.sh <slug> --agents 3
# → swarm/agent_1/tinker/  (depth-explore)
# → swarm/agent_2/tinker/  (lr-explore)
# → swarm/agent_3/tinker/  (arch-explore)
# → swarm/MANIFEST.json

# 2. Prepare data once (agent_1 only — others symlink the data/ dir)
cd .research/<slug>/swarm/agent_1/tinker && uv sync && uv run python prepare.py

# 3. Run each agent's loop (separate Claude Code sessions or parallel Tasks)
bash scripts/tinker_run.sh <slug> --workspace swarm/agent_1/tinker
bash scripts/tinker_run.sh <slug> --workspace swarm/agent_2/tinker
bash scripts/tinker_run.sh <slug> --workspace swarm/agent_3/tinker

# 4. Aggregate periodically (cron every hour, or manual)
bash scripts/swarm_orchestrate.sh <slug>
# → swarm/SHARED_BEST.json (global winner)
# → swarm/SWARM_RESULTS.md (aggregated table)
# → swarm/best_train.py (winner snapshot)
```

### Cross-pollination

Each agent **may read** `swarm/best_train.py` for inspiration, but **only within its own strategy** (e.g. `arch-explore` borrows architectural ideas, not lr settings). `random-restart` is the exception: it deliberately ignores the global best to preserve sampling purity. Per-strategy rules are spelled out in each `program_<strategy>.md`.

### File-based protocol

- Agents write only under `agent_<id>/`
- Orchestrator writes only under `swarm/` with `flock` exclusion + atomic rename
- Agents see `swarm/` as read-only
- Concurrent orchestrator launches no-op via `flock` — safe to run from cron

Spec: `skills/research.autonomous.swarm/SKILL.md` and `references/swarm_protocol.md`

### Acknowledgement

The "research org" multi-agent design is the future-work hint from karpathy/autoresearch's README, materialized here on top of v0.9.0's single-agent tinker. The single-agent runner (`tinker_run.sh`) is reused unchanged — only the orchestrator, file-based protocol, and five strategy templates are new. See `skills/research.autonomous.swarm/SKILL.md` for the full attribution.

## Cost & Observability (v0.5.0+)

### Cost tracking

The `research.cost.estimate` skill writes a per-run USD cost into `metrics.json` and rolls up project-level cost into `06_COST_REPORT.md`. It warns at 80 % and fails over budget at 100 % of `compute_budget_gpu_h`.

```text
> "Use research.cost.estimate to update cost for <slug>"
```

The price table SoT is `skills/research.cost.estimate/references/gpu_price_table.json` (A100 / H100 / H200 / L40S / RTX-4090 / TPU-v4 / Apple M-series and more).
If your contract pricing differs, override it per project with `.research/<slug>/cost_overrides.json`:

```json
{
  "gpu_pricing": {"A100-80GB-SXM": 1.20},
  "note": "RunPod spot, 2026 Q2 contract"
}
```

### W&B / MLflow / TensorBoard (opt-in)

Set the env var, install the extra, and the scaffolded training template uses it automatically. Unset → silent no-op:

| Backend | Env | Extras |
|---------|-----|--------|
| W&B | `WANDB_API_KEY`, `WANDB_PROJECT`, `WANDB_MODE` | `uv sync --extra wandb` |
| MLflow | `MLFLOW_TRACKING_URI`, `MLFLOW_EXPERIMENT_NAME` | `uv sync --extra mlflow` |
| TensorBoard | `TB_LOG_DIR` | `uv sync --extra tensorboard` |

`events.jsonl` (the auto-research core log) is always written. The above backends are **additive**; when not configured the project behaves exactly like before.

Spec: `skills/research.experiment.scaffold/references/observability_setup.md`

## Publishing & Archival (v0.6.0+)

Once Phase 8 G4 is cleared, `research.publish` ships your bundle to a public registry and gives you a DOI:

```text
# 1. Build the redacted bundle (Phase 8 prerequisite)
> "Use research.export to make the publishable bundle for <slug>"

# 2. Upload to HF Hub + Zenodo as a draft (private/sandbox)
> "Use research.publish for <slug> in --draft mode"

# 3. Promote to a real DOI when ready
> "Use research.publish for <slug> with --no-draft"
```

### Targets

| Target | Use case | Auth env | Reversible |
|--------|----------|----------|-----------|
| HF Hub Datasets | modular publication / collaboration | `HF_TOKEN` | yes (private / delete) |
| Zenodo | DOI-stable archive / paper citation | `ZENODO_ACCESS_TOKEN` (`ZENODO_SANDBOX=1` for testing) | **published versions are immutable** (drafts are mutable) |

### Outputs

- `.research/<slug>/PUBLICATION.md` — URLs + DOI + bibtex citation
- `.research/<slug>/STATE.json` `published` field is updated

### Checkpoint cleanup

```bash
# Dry-run (default — only prints candidates)
bash scripts/cleanup_checkpoints.sh <slug>

# Apply, keeping the checkpoint of the best succeeded run
bash scripts/cleanup_checkpoints.sh <slug> --apply --keep-best
```

`--keep-best` protects the checkpoint of the run with the highest primary metric.
Spec: `skills/auto-research/references/data_lineage.md` ("Retention 強制" / "Publishing & Archival").

## Paper-First Methodology (v0.13.0+)

Encodes the seasoned-researcher heuristic of **starting to write the paper (especially Abstract and Introduction) before running experiments**. The new `research.paper.scaffold` skill is invocable from **Phase 2 (after the literature survey)** onwards and grows a single living document `paper/DRAFT.md` as the project progresses.

### Phase × DRAFT.md fill rate

| Phase done | What gets written | Fill rate |
|-----------|-------------------|-----------|
| Phase 2 (Survey) | Abstract `[Background]` / `[Implication]` placeholders + Intro Motivation + **Related Work (with citations)** + refs.bib | **55%** |
| Phase 3 (Idea) | + Abstract `[Method]` `[Hypothesis]` + Intro Contributions (3-4 bullets) | **70%** |
| Phase 4 (Plan) | + Method + Setup + Baselines | **85%** |
| Phase 6 (Run) | + Results table + Abstract `[Hypothesis]→[Result]` rewrite | **95%** |
| Phase 7 (paper.draft) | Discussion + Limitations + terminology unification + LaTeX build + DOI completion | **100%** |

### Hypothesis-driven Abstract

```markdown
[Background] Domain context + existing methods' limitation (2-3 sentences)
[Method] Core of our proposed approach (3-5 sentences)
[Hypothesis (to be verified at Phase 6)] Falsifiable prediction + statistical threshold (1-2 sentences)
[Implication (if verified)] Implication for the research community + open questions (2-3 sentences)
```

After Phase 6, the `[Hypothesis]` block is replaced with measured `[Result]`.

### Related Work paragraph

Auto-generated from `02_SURVEY/MATRIX.md` by sub-area grouping. Each paper is summarized in 1-2 sentences with inline `\cite{}`. The paragraph ends with a **"Position of our work"** synthesis that pins down the contribution explicitly. Quote rules follow `responsible_research.md` (≤ 2-sentence verbatim, no commercial-journal PDF caching).

### Quick start

`research.paper.scaffold` is **automatically dispatched** at the end of Phase 2 / 3 / 4 / 6 by the auto-research workflow, but you can also call it manually:

```text
> "Use research.paper.scaffold to refresh the paper draft for <slug>"
```

It is idempotent — re-running won't damage prior content.
The **agent-managed marker** (`<!-- agent-managed:Phase=N -->`) protects sections under human revision; deleting the marker tells the skill to leave that section alone.

### Backward compatibility

- Projects that don't invoke `paper.scaffold` keep using `research.paper.draft` (Phase 7) as before
- `paper.draft` (Phase 7) **uses `paper/DRAFT.md` if present, otherwise falls back to `paper_skeleton.{md,tex}`**
- Existing v0.1.0+ projects can adopt `paper.scaffold` retroactively (idempotent)

Spec: `skills/research.paper.scaffold/SKILL.md` and `references/phase_section_map.md`

## Lab Notebook & Reproducible Failures (v0.14.0+)

The essence of scientific research isn't just "successful results" — it's the accumulation of "**what did we try, why did it fail, and what should we change next**". The new `research.lab.notebook` skill encodes the seasoned-researcher's lab notebook culture into the workflow and makes **failure itself reproducible**.

### Hybrid structure

| File | Role |
|------|------|
| `LAB_NOTEBOOK.md` (under slug root) | Single living document — chronological "thought voyage log". Entries accrue at Phase 3 / 5 / 6 / 8 |
| `06_RUNS/<id>/POSTMORTEM.md` | Per-failure card (only for failed runs, auto-drafted). Reproduce command + Hypothesis space + Decision + Lessons |
| `03_REJECTED_IDEAS.md` | Phase 3 rejected ideas with full body + reason + future revisit conditions (revisitable for future pivots) |

LAB_NOTEBOOK and POSTMORTEM cross-link bidirectionally — navigate between overall thinking and individual failure deep-dives.

### Phase × notebook actions

| Phase | Trigger | Action |
|-------|---------|--------|
| 3 (after G2) | auto | Save rejected ideas + LAB_NOTEBOOK Phase 3 entry |
| 5 (TDD Red) | manual (optional) | Short note in LAB_NOTEBOOK (recommended after 30+ min stuck) |
| 6 (run done) | **auto** | If failed run exists: POSTMORTEM draft + reproduce.sh + uv.lock snapshot + LAB_NOTEBOOK entry. Success runs also get a 1-line entry |
| 8 (Review) | auto | Integrate LAB_NOTEBOOK Lessons into `08_REVIEW.md` |

### Hypothesis-driven failure post-mortem

POSTMORTEM §3 Hypothesis space is **auto-drafted from events.jsonl + error.txt with 3-5 hypotheses**:

```markdown
| H | Statement | Evidence | Verdict |
|---|-----------|----------|---------|
| H1 | batch_size=16 exceeds 40GB activation memory | events.jsonl:step=1240 gpu_mem=38.45GB | LIKELY |
| H2 | gradient checkpointing disabled, retains all activations | config.yaml:gradient_checkpointing=false | LIKELY |
| H3 | data leak (prior step tensor not GC'd) | code review (train.py:L120 zero_grad present) | RULED OUT |
```

Verdicts are agent-drafted (LIKELY / UNLIKELY / RULED OUT) but **user confirms**. **§4 Decision and §5 Lessons require user polish** (the scientific core).

### Reproducibility 7-tuple for failed runs

Each run (success / failed) auto-saves:

1. **Code rev** (events.jsonl `git_rev`, existing)
2. **Config** (`06_RUNS/<id>/config.yaml`, existing)
3. **Dependencies** (`06_RUNS/<id>/uv.lock` snapshot, **new in v0.14.0**)
4. **Random seed** (events.jsonl, existing)
5. **Data version** (`data_lineage.md` hash, existing)
6. **Hardware** (events.jsonl env, existing)
7. **Reproduce command** (`06_RUNS/<id>/reproduce.sh`, **new in v0.14.0**)

Now `cd 06_RUNS/<id> && bash reproduce.sh` reproduces any run (success **or failed**) with one command.

### Quick start

`research.lab.notebook` is **automatically dispatched** at Phase 3 / 6 / 8 by the auto-research workflow, but you can also call it manually:

```text
> "Use research.lab.notebook to record this failure for <slug>"
```

Idempotent — re-running won't damage user-polished POSTMORTEM sections (protected by `<!-- agent-managed:Phase=N -->` marker).

### Backward compatibility

- Projects without `LAB_NOTEBOOK.md` work normally through Phase 1-8
- Pre-v0.14.0 `06_RUNS/<id>/` directories: best-effort retroactive `reproduce.sh` only (uv.lock unrecoverable, warning)
- `research.paper.scaffold` (v0.13.0) can use LAB_NOTEBOOK Lessons as material for the Limitations section in Phase 7 (loose coupling, optional)

Spec: `skills/research.lab.notebook/SKILL.md` and `references/phase_notebook_map.md`

## Lab Notebook Best Practices (v0.15.0+)

v0.15.0 polishes the v0.14.0 lab notebook structure with **4 P0 elements** drawn from external research-notebook best practices: Decision journal (Annie Duke "How to Decide"), Tag system (ELN FAIR guidelines), Cross-project Lessons DB, and Blameless culture (Google SRE "Blameless Postmortems"). Additional inspiration from mlflow / W&B metadata conventions and Open Notebook Science (Bradley 2006).

### Decision journal (Light touch)

At Phase 3 idea adoption and Phase 4 experiment design, record **"prediction / belief / assumptions"**. At Phase 6, an agent-drafted Predicted-vs-Actual table with Surprise score (1-5) and "What I missed" prevents hindsight bias:

```markdown
**Decision journal (Light touch)**:
- **Predicted outcome**: primary metric +3-5pp on MMLU baseline
- **Confidence**: medium (prior work avg improvement +2.5pp across 5 papers)
- **Key assumptions**:
  1. 4-factor variance composes super-additively
  2. format dominates (>30% contribution)
  3. 3-8B model size shows the same pattern
```

Phase 6 metacognition entry is auto-drafted (verdicts user-confirmed, blameless wording):

```markdown
| Metric / claim | Predicted | Actual | Surprise |
|----------------|-----------|--------|----------|
| primary acc improvement | +3-5pp | +1.2pp | 4 |
| dominant factor | format | decoding (3B) | 4 |
```

### Tag system (Hybrid)

Each entry ends with `Tags: #...`. 28 controlled vocabulary tags + free tags. `LAB_NOTEBOOK_INDEX.md` auto-generated (tag reverse lookup):

| Category | tags |
|----------|------|
| Failure type | `#oom` `#nan` `#shape-mismatch` `#timeout` `#import-error` `#data-bug` `#convergence-issue` |
| Outcome | `#hypothesis-confirmed` `#hypothesis-rejected` `#ruled-out` `#inconclusive` `#assumption-reversed` |
| Process | `#pivot` `#stuck` `#insight` `#peer-discussion` `#decision-adopted` `#decision-rejected` |
| Phase marker | `#phase-3` `#phase-4` `#phase-5` `#phase-6` `#phase-8` (auto) |

Free tags (e.g., `#attention-sink`, `#llama-3b`) appear in a separate INDEX section.

### Cross-project Lessons DB (`~/.research-lessons.json`)

At Phase 8, top 3 lessons are atomic-appended to a **per-user, all-projects shared DB**. New projects can search prior failures at Phase 3 / 6 (institutional memory):

```text
> /auto-research:lessons-search "memory"               # free text
> /auto-research:lessons-search --tag #oom              # tag filter
> /auto-research:lessons-search "format" --phase 6      # phase filter
> /auto-research:lessons-search --model 3B              # context filter
```

### Blameless culture

POSTMORTEM templates carry a mandatory **Blameless callout** at the top. SKILL.md spells out Anti-patterns (blame language) and Pre-patterns (system / process as subject). Failures are attributed to systems / processes; individual decisions are evaluated as "reasonable given the information available at the time" — a Google SRE practice.

Spec: `skills/research.lab.notebook/references/decision_journal_template.md`, `tag_taxonomy.md`, `lessons_db_schema.md`, `blameless_principles.md`

## Lab Notebook P1 Polish (v0.16.0+)

v0.16.0 ships the **3 P1 elements** that v0.15.0 deferred. All optional, workflow dispatcher unchanged. Sources: NIH IRP "Keeping Lab Notebooks" (ALCOA+), Open Notebook Science (provenance), traditional paper lab notebook practice (daily entries).

### Provenance trace (optional)

Each LAB_NOTEBOOK entry / POSTMORTEM gets an optional field for the **origin of the thought**:

```markdown
**Provenance** (optional):
- **Inspired by**: ~\cite{hong2024chat} (MATRIX.md row #1)
- **Discussion**: AB @ 2026-05-11
- **External thread**: https://news.ycombinator.com/item?id=12345
- **AI assistant**: Claude Sonnet 4.6 @ 2026-05-11
```

- AI-assistant use **must be disclosed** (NeurIPS / ICLR / ACL LLM-author policy + Open Notebook Science principle)
- Agent does not infer; user writes
- Phase 7 paper.draft can later use it for Acknowledgment auto-generation (future v0.17+)

### ALCOA+ correction guideline (traditional lab notebook practice)

> "Correct mistakes, but never remove them." — NIH IRP

In markdown: `~~strike~~` + `<ins>new</ins>` + annotation (reason + initials + date):

```markdown
The result was ~~3.14~~ <ins>2.71</ins>. (corrected 2026-05-15 by AB, reason: math error)
```

Git history provides tamper-evidence; the markdown markup is a human-readable navigation aid. **Not lint-enforced** — adopted via education + guidelines.

### Daily summary entry (optional, Light touch 4-prompt)

A daily entry that supplements Phase-event-driven entries. Not fully freeform — a Light touch schema for ease of writing:

```markdown
### 2026-05-13 [Daily summary]

- **Today's stuck**: lm-eval-harness version drift, 3h with no progress
- **Today's insight**: harness version pinning is missing from Phase 4 design checklist
- **Tomorrow's plan**: check GitHub Issues, then try an alternative version
- **Mood / energy**: 2/5

Tags: `#daily-summary` `#stuck` `#phase-5`
```

- **Not mandatory daily** — only when you want to
- Keeps notebook continuity even during Phase 1 / 2 / 7 (where lab.notebook has no event-driven entry)
- Phase 8 review can later aggregate "Today's insight" / "Today's stuck" for generalizable lessons (future v0.17+)

Spec: `skills/research.lab.notebook/references/provenance_template.md`, `alcoa_correction_guideline.md`, `daily_summary_template.md`

## Data & Comparison (v0.3.0+)

Data handling is centralised in `skills/auto-research/references/data_lineage.md`.

### Data classification (summary)

| Category | git track | Public release |
|----------|-----------|---------------|
| brief / spec / survey notes / metrics / paper | yes | yes (paper appendix) |
| events.jsonl | yes (gzip recommended) | redacted only |
| **checkpoints (model weights)** | **no** | HF Hub or Zenodo |
| **activation cache / raw datasets** | **no** | no |

### User-side `.gitignore`

Add the contents of `templates/research-gitignore.txt` to your project root's `.gitignore` so checkpoints / caches / datasets cannot be committed by accident.

### Cross-project comparison & export

Lightweight (shell):

```bash
bash scripts/cross_compare.sh <slug1> <slug2> ...
bash scripts/export_project.sh <slug>
```

Statistical / publication-grade (skills, v0.4.0+):

| Skill | Capability |
|-------|------------|
| `research.cross.compare` | paired bootstrap / Welch's t / Cohen's d / Cliff's delta / Holm-Bonferroni / comparison plots |
| `research.export` | PII redaction (prompt → sha256) + `MANIFEST.json` (commit SHA, deps, state) + `INTEGRITY.txt` (sha256 list) |

Invoke them through Claude Code, e.g. "Use research.cross.compare to compare `<slug1>` and `<slug2>`".

## Main components

### Skills

| Skill | Role |
|-------|------|
| `auto-research` | Main workflow (state machine + phase dispatcher) |
| `research.literature.matrix` | Comparison matrix (fixed schema + mutex on parallel reads) |
| `research.experiment.scaffold` | uv project scaffold |
| `research.experiment.run` | Reproducible execution + JSONL logs |
| `research.paper.draft` | LaTeX / Markdown paper drafting |
| `research.attention.probe` | TransformerLens / nnsight intervention recipes |
| `research.cross.compare` | Cross-project comparison with statistical tests (v0.4.0+) |
| `research.export` | Publication-grade bundle (PII redaction + MANIFEST + INTEGRITY) (v0.4.0+) |
| `research.cost.estimate` | Per-run USD estimate + project rollup + budget watch (v0.5.0+) |
| `research.publish` | HF Hub + Zenodo upload + DOI + `PUBLICATION.md` (v0.6.0+) |
| `research.compute.shop` | Ranked GPU provider recommendations from an 18-provider catalog (commercial / marketplace / free / academic) (v0.8.0+) |
| `research.autonomous.tinker` | karpathy-inspired autonomous tinker mode — Phase 5-6 alt where the agent iteratively edits a single `tinker/train.py` under fixed wall-clock budget to minimize `val_bpb` (v0.9.0+) |
| `research.paper.scaffold` | Paper-first early scaffold (v0.13.0+) — invocable from Phase 2 onward, builds `paper/DRAFT.md` as a living document with hypothesis-driven Abstract and citation-backed Introduction |
| `research.lab.notebook` | Lab notebook + failure postmortem skill (v0.14.0+) — Hybrid LAB_NOTEBOOK (timeline) + per-failure POSTMORTEM with auto-drafted Hypothesis space. Saves reproduce.sh + uv.lock snapshot so failed runs are also reproducible. Rejected ideas preserved with revisit conditions |

### Subagents

| Agent | Speciality |
|-------|------------|
| `paper-deep-reader` | Single-paper derivation-level reading |
| `research-gap-finder` | Cross-paper synthesis / gap discovery |
| `experiment-designer` | RQ → hypothesis → ablation table → statistical test |
| `attention-analyst` | Mechanistic interpretability (logit lens / patching / probing / SAE) |
| `result-statistician` | Bootstrap / Wilcoxon / Cohen's d / plotting |

We deliberately reuse `~/.claude/agents/arxiv-mcp-agent` and `ml-engineer` rather than redefining them. See `agents/DISPATCH_MATRIX.md`.

### Hook

The `PostToolUse` hook captures every `uv run *` invocation and appends a JSON line to `.research/<slug>/06_RUNS/<run_id>/events.jsonl` with `{event, level, ts, run_id, duration_ms, exit_code, git_rev, stdout_tail}`. **The single most important reproducibility device in the plugin.**

## Examples (v0.4.0+)

`examples/` contains walked-through real project layouts:

- [`examples/llm-eval-mmlu-baseline/`](examples/llm-eval-mmlu-baseline/) — an MMLU fair-comparison study at Phase 4 / G3-passed (Brief, Survey, Gap, Ideas, Plan present as real artefacts)

You can copy an example, rename the slug, and resume it with `--resume`. See `examples/README.md` for details.

## Ethics & Compliance

- arXiv (CC-BY) is redistributable; commercial-journal PDFs are **not cached**. `notes/` keeps summaries + metadata only with verbatim quotes ≤ 2 sentences.
- eval-set contamination check is mandatory in `eval_protocol.md`
- AI-author disclosure is bundled in the paper templates (NeurIPS / ICLR / ACL compliant)

## Contributing

PRs welcome. Read `CONTRIBUTING.md` and `RELEASING.md` first.

- New feature: MINOR bump candidate — confirm boundaries against `agents/DISPATCH_MATRIX.md`
- Bug fix: PATCH bump — add a regression test under `tests/` (TDD)
- Docs: add an entry under `[Unreleased]` `### Documentation`

Issue templates live in `.github/ISSUE_TEMPLATE/` (bug / feature / install).

## License

MIT — see [LICENSE](LICENSE).
