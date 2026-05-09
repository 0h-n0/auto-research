# Mission (rl-cartpole)

You are an autonomous research agent. Maximize **mean `episode_return`** over a fixed set of evaluation seeds on CartPole-v1 by iteratively editing **only** `tinker/train.py`.

- Wall-clock budget per experiment: 5 minutes (`TINKER_BUDGET_SECONDS=300`).
- Overall wall-clock budget: 8 hours.
- Project slug: `<slug>`.
- Domain: `rl-cartpole`. Metric direction: `max` (higher is better).
- Solved threshold: episode_return ≥ 475 averaged over 10 seeds is "solved" (max is 500).

# Hard rules

1. **You may freely edit `tinker/train.py`** (policy network, algorithm — REINFORCE / PPO-lite / actor-critic / DQN / ..., optimizer, exploration, batch sizes, ...).
2. **You MUST NOT touch** `tinker/prepare.py` or `tinker/data/manifest.json`. The eval seed list is fixed there to keep results comparable.
3. **No prebuilt RL frameworks** that hide the loop (no `stable-baselines3`, no `cleanrl` import). You must write the algorithm yourself with `torch` + `gymnasium`.
4. **You MUST NOT condition on `eval_seeds` during training.** Reading them is fine (they are in `data/manifest.json`), using them as training seeds is data leakage.
5. **Each iteration**: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/tinker_run.sh <slug> --domain rl-cartpole`.
6. **Always write `tinker/result.json`** with `primary_metric` (mean eval episode return), `metric_name="episode_return"`, `direction="max"`, `wall_time_s`, `n_iters` (≈ episodes seen), `diverged`, `domain="rl-cartpole"`.

# Per-iteration workflow

1. Read `tinker/RESULTS.md` for history. Beat current best.
2. Decide on **one** focused change. Examples:
   - Algorithm: REINFORCE → REINFORCE+baseline → actor-critic → PPO-lite (clipped objective + GAE)
   - Network: hidden 64 → 128, depth 1 → 2, activation tanh ↔ relu
   - Optimizer / LR / weight_decay
   - Reward shaping (be careful — gymnasium reward is fixed, but you can normalize)
   - Discount γ, entropy coefficient
   - Batch / episodes_per_update
3. Run: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/tinker_run.sh <slug> --domain rl-cartpole`
4. Read `result.json`. If `diverged` or `primary_metric` is null, revert.
5. Runner updates RESULTS.md / BEST.json / history.

# Strategy hints (refine freely)

- **Variance reduction is the key knob.** REINFORCE with mean-subtracted return is decent; an actor-critic with a value baseline is much steadier.
- **CartPole is tiny.** Don't go past hidden=128 or depth=3 — you'll just overfit to early-episode noise.
- **Episodes per update**: too few → noisy gradients; too many → fewer updates per minute. Start at 5–10.
- **Entropy bonus**: `entropy_coef ∈ [0, 0.05]` can prevent premature determinism.
- **PPO-lite**: clip the policy ratio at ε=0.2, run a few epochs over the rollout. Often beats REINFORCE within budget.
- **Verify big jumps**: a +50 return improvement deserves a 2nd run with `seed+1` to confirm it isn't variance.

# Strategy anti-patterns (don't do this)

- Importing `stable_baselines3` or `cleanrl`.
- Using the eval seed list during training.
- Reward shaping that effectively reads the env state in a privileged way.
- Cherry-picking a lucky seed without verification.
- Editing `prepare.py` to add more eval seeds.

# Logging

The runner appends to:
- `tinker/RESULTS.md`
- `06_RUNS/<run_id>/events.jsonl` (`event=tinker.iteration`)

# Stop conditions

Stop when **any** of:

- 8 hours elapsed.
- 30 consecutive iterations without improvement.
- 10 consecutive iterations with `diverged=true`.
- `primary_metric ≥ 495` (you've effectively solved CartPole; further gains unlikely).

# How to start

1. Read `tinker/train.py` (REINFORCE with baseline).
2. Run a baseline iteration: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/tinker_run.sh <slug> --domain rl-cartpole`
3. Inspect `result.json`. Begin the loop.

Good luck. Keep diffs reviewable.
