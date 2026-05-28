---
name: aiw-evaluation
description: "Periodic review entry point for the data-driven workflow evaluation defined in design/decisions/evaluation.md. Use this skill when the user asks to run the periodic review, evaluate workflow versions, produce improvement proposals, or analyse accumulated Claude Code telemetry. The skill exists to enforce the between-review readiness gate so a review never proceeds past structurally-thin data."
---

# Evaluation

Read this file when the user asks to run the periodic workflow review defined in `design/decisions/evaluation.md`.

This skill does not reproduce the review process — that lives in `design/decisions/evaluation.md`. This skill enforces the readiness gate that protects the process, then hands off to it when (and only when) the gate would pass.

## Step 1: Determine readiness

- Run `scripts/eval-preflight.sh` and check its exit code.
- If the script is missing, stop and tell the human the preflight tool is not installed.
- Exit code `0`: gate would pass. Continue at Step 3.
- Exit code `1`: gate would fail. Continue at Step 2.
- Exit code `2`: Loki is unreachable. Tell the human, suggest bringing the telemetry stack up with `./telemetry/up.sh` (or waiting for the launchd agent to restart it), and stop.
- Exit code `3`: misconfiguration. Tell the human the preflight reported a misconfiguration and stop.

The preflight writes `telemetry/eval-readiness.json` (machine-readable) and `telemetry/eval-readiness.md` (human-readable) on every run. Read whichever is appropriate at each later step.

## Step 2: Write the thin-data report (gate failed)

When exit code `1`, write the review document to `observations/workflow-reviews/<YYYY-MM-DD>.md`. The document must:

- State that the gate is not met.
- Reproduce the per-condition pass/fail table from `telemetry/eval-readiness.{json,md}`, including the actual counts (sessions per version, baseline versions on disk, etc.).
- Name the earliest realistic date the gate could pass, given which conditions are failing.
- Record any structural blockers that are not just sample-size issues (for example, baseline harness never run for any version, or ruleset_hash scoping incompatibilities).

Do not produce proposals. Do not list "findings that would be disqualified under `evaluation.md`'s disqualifying conditions but might be useful" — that is exactly the thin-data paper-over the gate exists to prevent.

Stop after writing the report. Do not continue to Step 3.

## Step 3: Run the periodic review (gate passes)

When exit code `0`, follow the process in `design/decisions/evaluation.md` exactly:

- Read the inputs listed there (baseline JSONs, Loki sessions, Prometheus aggregates, sampled transcripts, `observations/observed-ai-failings.md`).
- Run the listed analyses (`scripts/compare-versions.py`, event-level scans, transcript-level LLM-judge spot checks).
- Produce proposals in the required format, with every required field.
- Apply the disqualifying conditions before presenting any proposal to the human.

Archive the review at `observations/workflow-reviews/<YYYY-MM-DD>.md`.

## What this skill does not do

- It does not run the baseline harness. That is the maintainer's separate action via `scripts/run-baseline.sh`.
- It does not modify the gate conditions. Those live in `design/decisions/evaluation.md`.
- It does not trigger itself. The launchd health check (`com.aiw.eval-readiness`) raises macOS notifications on green→red transitions; only the human starts a review.
- It does not propose changes to the emission policy. The scoping of `ruleset_hash` to `ai-coding-workflow` only is intentional (`update-session-tags.sh`, `aiw-telemetry-setup` skill); the gate respects that scoping rather than fighting it.
