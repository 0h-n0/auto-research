# Reproducibility Checklist

Phase 4 (Experiment Design) で **全項目を埋める**。Phase 5 以降で 1 つでも欠けると Phase 7 で reviewer に指摘される。

## Code

- [ ] `pyproject.toml` 完全固定 (`uv.lock` コミット)
- [ ] `git rev` を `RunConfig` に記録
- [ ] `config_hash` を `RunConfig` から計算しメタに含める
- [ ] 全実行スクリプトを 1 コマンドで再現できる (`make reproduce` 等)

## Randomness

- [ ] `random`, `numpy`, `torch`, `torch.cuda`, `accelerate` の seed を全て固定
- [ ] `torch.use_deterministic_algorithms(True)`
- [ ] `torch.backends.cudnn.benchmark = False`
- [ ] `CUBLAS_WORKSPACE_CONFIG=:4096:8` (CUDA 10.2+)
- [ ] DataLoader `worker_init_fn` で worker seed 固定
- [ ] seed 3 以上、報告は mean ± 95% CI

## Data

- [ ] dataset name, version, split, license を `DATA_CARD.md` に明記
- [ ] preprocessing の決定論性 (tokenizer version, BOS/EOS の有無)
- [ ] eval 汚染チェック実施 (`eval_protocol.md` 参照)
- [ ] PII / sensitive content スキャン

## Compute Environment

- [ ] CUDA / cuDNN / driver version (`nvidia-smi` snapshot を `IMPL_NOTES.md` に貼る)
- [ ] CPU / RAM (peak memory)
- [ ] GPU 種別 (例: A100 80GB SXM4) + 枚数
- [ ] dtype (fp32 / bf16 / fp16 / int8 / int4)
- [ ] FlashAttention / SDPA backend バージョン

## Logging

- [ ] `events.jsonl` 必須フィールド: `event, level, ts, run_id, duration_ms`
- [ ] failed run も `STATUS=failed` で残す
- [ ] hyperparameter は config file に記述、CLI override は config に snapshot

## Releases

- [ ] code は paper 公開時に GitHub に release tag 付け
- [ ] checkpoints は HF Hub or Zenodo に DOI 付き公開 (open release の場合)
- [ ] 公開できない場合は理由を `paper/limitations.md` に記載
