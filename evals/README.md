# Baseline Task Harness

Frozen coding tasks that can be re-run under any workflow version to produce
comparable reliability numbers. See parent issue #101 and sub-issue #112.

This v0.2 harness is a thin prototype: it runs one task at a time through a
plain Python runner (not Inspect). The on-disk contract (`docs/telemetry-schema.md`)
is the stable surface. Migrating the runner to Inspect's `Task` + `@solver` is
a follow-up and does not change the results tree.

## Layout

- `harness/` — shared Inspect solver and helpers (writing per-session JSON
  matching `docs/telemetry-schema.md`, reading workflow version and ruleset
  hash, running agents, grading).
- `tasks/<task_id>/` — one directory per frozen task:
  - `spec.md` — prompt the agent sees and the acceptance criteria.
  - `task.py` — Inspect `@task` wiring.
  - `starter/` — frozen repo state copied into the sandbox (or tempdir in
    mock mode) before the agent runs.
  - `grader/` — hidden files (pytest tests) applied after the agent is done;
    the agent never sees them.
  - `solution/` — reference solution used only by the mock agent to prove
    the pipeline end-to-end without burning API tokens.
- `spikes/` — pre-harness spikes (D0, etc.).

## Running

From the repo root:

```
./scripts/run-baseline.sh --agent mock --tasks t-001-add-sum-function --repeats 1
./scripts/run-baseline.sh --agent claude-code --repeats 3
./scripts/compare-versions.py 2.8.0 2.9.0
```

`--agent mock` runs everything on the host, requires no API key, and uses the
reference `solution/` to prove plumbing. `--agent claude-code` launches the
Claude Code CLI inside a Docker sandbox per task (requires Docker and
`ANTHROPIC_API_KEY`).

Results land under `telemetry/data/baseline/<version>/<ruleset_hash>/<task>/<run_id>.json`
and are gitignored.

## Why pass^k

Each task runs N times per version. The reliability number reported is
pass^k with k = N — the probability that the agent solves it every single
time, not "can it eventually." This is the number that matters when the
workflow is supposed to make behaviour predictable.
