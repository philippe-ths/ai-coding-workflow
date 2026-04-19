# Baseline Harness Session Schema

This document defines the per-session JSON structure the baseline task harness (Sub-issue D, #112) produces for each baseline run. The structure is the contract between Sub-issue C (this stack) and Sub-issue D (the harness) — the harness writes files matching this shape, the telemetry stack consumes them for cross-version comparison.

Status: **draft v0.1**. Will be refined by Sub-issue D during implementation. Changes here require a matching CHANGELOG entry.

## Filename

```
telemetry/data/baseline/<workflow_version>/<ruleset_hash>/<task_id>/<run_id>.json
```

- `workflow_version` — matches `Version:` in `ai-workflow.md` at run time.
- `ruleset_hash` — matches the 8-hex `ruleset_hash` written to `.claude/settings.json` by `.ai-policy/scripts/update-session-tags.sh`.
- `task_id` — stable identifier of the frozen baseline task (e.g. `t-001-add-logging`).
- `run_id` — 8-hex random, generated per run.

This path structure is written to Loki's `filename` label when the harness tails the file back to the Collector.

## JSON shape

```json
{
  "schema_version": "0.1",
  "run_id": "a1b2c3d4",
  "task_id": "t-001-add-logging",
  "workflow_version": "2.8.0",
  "ruleset_hash": "128c05dd",
  "started_at": "2026-04-19T14:30:00Z",
  "ended_at": "2026-04-19T14:42:18Z",
  "duration_seconds": 738,

  "outcome": "completed",

  "session_id": "abcdef-1234-...",
  "model": "claude-opus-4-7",

  "cost_usd": 0.87,
  "tokens": {
    "input": 12450,
    "output": 3120,
    "cache_read": 8900,
    "cache_creation": 1100
  },

  "tool_calls": {
    "total": 27,
    "accepted": 24,
    "rejected": 3,
    "by_tool": {
      "Edit": { "accepted": 9, "rejected": 0 },
      "Bash": { "accepted": 11, "rejected": 2 }
    }
  },

  "fix_cycles": 2,
  "checkpoint_reached": true,
  "plan_accepted_first_pass": false,

  "tests": {
    "pre_baseline_passed": true,
    "post_change_passed": true
  },

  "git": {
    "commits": 3,
    "lines_added": 42,
    "lines_removed": 11,
    "pr_created": false
  },

  "transcript_path": null,
  "notes": []
}
```

## Fields

| Field | Type | Source | Notes |
|---|---|---|---|
| `schema_version` | string | harness | Bump on any breaking change. |
| `run_id` | string | harness | 8-hex random. |
| `task_id` | string | harness | Stable baseline task ID. |
| `workflow_version` | string | `ai-workflow.md` header | Captured at run start. |
| `ruleset_hash` | string | `.claude/settings.json` | Captured at run start. |
| `started_at`, `ended_at` | RFC3339 | harness | UTC. |
| `duration_seconds` | number | derived | `ended_at - started_at`. |
| `outcome` | enum | harness | `completed` / `failed` / `timed_out` / `aborted`. |
| `session_id` | string | Claude Code OTEL | Enables joining with OTLP data. |
| `model` | string | Claude Code OTEL | |
| `cost_usd` | number | sum of `api_request.cost_usd` | |
| `tokens.*` | number | sum of `api_request.*_tokens` | |
| `tool_calls.total` | number | count of `tool_decision` events | |
| `tool_calls.accepted`, `.rejected` | number | filter by `decision` | |
| `tool_calls.by_tool` | map | group by `tool_name` | |
| `fix_cycles` | number | harness (domain signal) | Count of times the workflow re-entered Step 5 after a failed Step 6 or 8. Derived from prompt clustering or harness bookkeeping — exact method resolved in Sub-issue D. |
| `checkpoint_reached` | bool | harness | Whether the session hit the plan checkpoint (Step 4). |
| `plan_accepted_first_pass` | bool | harness | Whether the plan needed revisions. |
| `tests.pre_baseline_passed` | bool | harness | Validation state before implementation. |
| `tests.post_change_passed` | bool | harness | Validation state after Step 6. |
| `git.commits` | number | `claude_code.commit.count` or git log | |
| `git.lines_added`, `.lines_removed` | number | `claude_code.lines_of_code.count` | |
| `git.pr_created` | bool | `claude_code.pull_request.count > 0` | |
| `transcript_path` | string \| null | harness | Relative path to sampled transcript if retained. |
| `notes` | array of strings | harness | Free-form human-authored annotations after the run. |

## Writing the file back to the Collector

Sub-issue D will run a small tailer (e.g. OTEL `filelog` receiver config) that reads these JSONs as structured log records. Until then, the telemetry stack only sees live OTLP traffic from Claude Code. The harness does not send OTLP itself — it writes the file, and the tailer lifts it into the pipeline.

## Changes

- **0.1 (2026-04-19)** — initial draft. Locked-in fields: `workflow_version`, `ruleset_hash`, `session_id`, `cost_usd`, `tokens.*`, `tool_calls.*`. Fields liable to change in Sub-issue D: `fix_cycles` (derivation method), `plan_accepted_first_pass` (instrumentation method), `transcript_path` (retention policy).
