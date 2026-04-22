---
name: aiw-telemetry-setup
description: "Guided, mostly-automated process for enabling Claude Code session telemetry in any repository and verifying end-to-end that tagged data reaches the local telemetry store before reporting success. Use this skill when the user asks to start recording sessions, enable telemetry in a new repo, set up observability for Claude Code, or investigates why an expected session is missing from Grafana or Loki. The skill exists to prevent the silent non-emission failure mode where a session runs normally but emits nothing because an environment variable did not propagate to the process that actually launched Claude Code, and to prevent the silent mis-identification failure mode where a repo emits data tagged with another repo's identity."
---

# Telemetry Setup

Read this file when the user wants to start recording Claude Code session telemetry in a repository.
The telemetry stack itself lives in the `ai-coding-workflow` repository under `telemetry/`; this skill configures a repository — the current one or any other — to emit into that stack.

This skill is the single user-facing action required to enable telemetry in a target repository. After running it, copied-in upstream files must not carry foreign identity, every signal the shipped Grafana dashboards consume must be emitted, and every enabled signal must have its round-trip verified end to end.

## Principles

- Automate every detection and probe step.
- Ask the user exactly once, with a consolidated summary of every file the skill would create or modify, before writing anything.
- Never enable telemetry as a default side effect. The skill runs only when explicitly invoked.
- Treat existing configuration as suspect until verified, not as authoritative. Inherited or stale configuration is the main failure mode this skill exists to catch.
- On any failure, leave the repository in the state it was in before the skill ran.
- Report SUCCESS or FAIL with the specific phase that failed and the next thing for the user to check.

## Phase 1 — Pre-flight detection (automated, read-only)

Run all of these before asking the user anything. Collect findings and present them together.

- Resolve the target repository root. Report it, along with the directory's basename — this basename is the expected `workflow_repo` tag value.
- Detect collector reachability by probing the local OTLP endpoints on the host running the user's shell. Do not probe remote endpoints. Probe both `4317` (gRPC) and `4318` (HTTP).
- Detect whether the full local telemetry stack is up: Prometheus (`http://localhost:9090/-/ready`), Loki (`http://localhost:3100/ready`), and Grafana. If any is down, record which — the skill must not claim success for a signal whose backend is unreachable.
- Detect whether `direnv` is installed and whether the target repository contains an existing `.envrc`.
- Detect the launch context of the current Claude Code process and of the likely future launches: terminal vs IDE. Check standard IDE indicator variables, the process parent, and the binary path. State confidence.
- Detect whether the target repository already has `.claude/settings.json` and whether it has an `env` block carrying `OTEL_RESOURCE_ATTRIBUTES`. Also read any existing `.envrc` for the same variable and the required exporter variables.
- Check the existing configuration for every known failure mode before treating it as valid:
  - **Poisoned identity.** If `OTEL_RESOURCE_ATTRIBUTES` contains `workflow_repo=<name>` and `<name>` does not match the target directory basename, the configuration was inherited from a copy of another repo (typically `ai-coding-workflow`). Flag as MISCONFIGURED and plan to replace the tag string.
  - **Missing exporters.** If `CLAUDE_CODE_ENABLE_TELEMETRY=1` is set but either `OTEL_METRICS_EXPORTER=otlp` or `OTEL_LOGS_EXPORTER=otlp` is absent, flag as MISCONFIGURED. Both are required because the shipped Grafana dashboards read Prometheus metrics **and** Loki logs.
  - **Missing metric temporality override.** If `OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE=cumulative` is absent, flag as MISCONFIGURED. Claude Code's OTEL SDK defaults to delta temporality, but the shipped collector pipeline forwards to Prometheus via remote-write, which requires cumulative — without this override, logs reach Loki normally while metrics silently fail to appear in Prometheus.
  - **Protocol/endpoint mismatch.** If `OTEL_EXPORTER_OTLP_ENDPOINT` is set without a matching `OTEL_EXPORTER_OTLP_PROTOCOL`, or the protocol does not match the port (`grpc` with 4317, `http/protobuf` with 4318), flag as MISCONFIGURED.
  - **Stale tracked identity.** If `.claude/settings.json` carries an `env.OTEL_RESOURCE_ATTRIBUTES` value at all, this is a tracked file and propagates to anyone who clones the repo. Flag as MISCONFIGURED and plan to move identity to gitignored `.envrc`.
- Only if none of those checks flag anything, treat the repository as "already configured" and offer a re-probe instead of proposing changes.
- Do not launch Claude Code, do not send any network traffic other than the collector-reachability and stack-readiness probes, and do not write files during this phase.

## Phase 2 — Propose a single change set

Based on Phase 1, decide the propagation mechanism:

- If direnv is available and the launch context is terminal, propose writing or extending `.envrc`. This is the preferred mechanism because the file is gitignored and cannot carry identity to other repositories via `git clone`.
- If direnv is absent or the launch context is IDE, propose writing the enable and endpoint variables into the `env` block of `.claude/settings.local.json` (Claude Code's local, gitignored settings override), not `.claude/settings.json`. Never write identity or endpoint values into the tracked `.claude/settings.json`.
- Never propose an endpoint that is not `http://localhost:*` without a second explicit confirmation from the user that they understand the endpoint will be visible in any file this skill writes.

Define the full change set:

- `CLAUDE_CODE_ENABLE_TELEMETRY=1`
- `OTEL_LOGS_EXPORTER=otlp` **and** `OTEL_METRICS_EXPORTER=otlp` — both always, regardless of which signal the user is focused on.
- `OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE=cumulative` — always. The shipped Prometheus pipeline drops Claude Code's default delta-temporality counters silently.
- `OTEL_EXPORTER_OTLP_ENDPOINT` paired with an explicit `OTEL_EXPORTER_OTLP_PROTOCOL`. Default to `grpc` with `http://localhost:4317` when Phase 1 detected 4317 open. Fall back to `http/protobuf` with `http://localhost:4318` when only 4318 is open.
- `OTEL_RESOURCE_ATTRIBUTES` with, at minimum, `workflow_repo=<target-directory-basename>`. If the target repo has its own `ai-workflow.md` with a `Version:` header, also include `workflow_version=<that version>`. Do not include `ruleset_hash` — that machinery belongs to the `ai-coding-workflow` repository itself.

Never propose a value that contains `workflow_repo=ai-coding-workflow` unless the target repository's directory basename is literally `ai-coding-workflow`.

Present the change set as a single summary:

- Every file that will be created, with its full proposed content.
- Every file that will be modified, with a precise diff of the lines being added or replaced.
- The tag string the repository will carry.
- The probe the skill will run afterwards, listing which backends each probe layer talks to.
- If Phase 1 found the local stack partially down, list which dashboards will be empty as a result and ask the user to confirm they want to proceed anyway, or to start the stack and re-invoke.

Ask the user to approve this summary once. Proceed only on explicit approval. On approval, proceed through Phases 3 and 4 without further prompts.

## Phase 3 — Apply changes (after single confirmation)

- Back up any file the skill modifies before writing. Restore the backup if any later step in this phase or Phase 4 fails.
- When writing `.envrc`, read any existing file first and merge rather than overwrite. Never remove user-authored exports that the skill did not add. Delimit the skill-managed variables with a sentinel block (`# >>> aiw telemetry (managed, do not edit) >>>` and matching closing sentinel) so re-invocation can replace the block in place.
- When writing `.claude/settings.local.json`, preserve existing keys. Only touch the `env` block.
- Never modify `.claude/settings.json` to add telemetry identity or exporter values. If a prior version of this skill wrote such values there, remove them as part of the change set and record the removal in the summary.
- After writing, if direnv is the chosen mechanism, instruct the user to run `direnv allow` and confirm the environment propagates. This is the only user action the skill requests after the confirmation gate.

## Phase 4 — Probe (automated, reported layer by layer)

Run the probe layers in order. Report each layer's result as it completes. Stop and report FAIL at the first failing layer.

- **Layer 1 — Collector reachability.** Send an HTTP probe to the OTLP endpoint the configuration selected and require a success response.
- **Layer 2 — Shell environment propagation.** Start a child shell under the same context the user will launch Claude Code from, and verify that every configured variable is present with the expected value: `CLAUDE_CODE_ENABLE_TELEMETRY`, `OTEL_LOGS_EXPORTER`, `OTEL_METRICS_EXPORTER`, `OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE`, `OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_EXPORTER_OTLP_PROTOCOL`, and `OTEL_RESOURCE_ATTRIBUTES`. Missing or mismatched values fail the layer.
- **Layer 3 — Logs round-trip via Loki.** From the same propagation context, send a synthetic OTLP log record that carries a freshly generated UUID in its body. After a short wait, query Loki for that UUID and confirm the returned record carries the expected resource attributes, including the target directory's `workflow_repo` value.
- **Layer 4 — Metrics round-trip via Prometheus.** From the same propagation context, emit a synthetic OTLP counter (`aiw_telemetry_probe_total`) labelled with a freshly generated UUID and the target directory's `workflow_repo`. After a short wait (account for the collector's scrape and the Prometheus scrape interval), query Prometheus `/api/v1/query` for the counter filtered by the UUID label and confirm the returned series carries the expected `workflow_repo` label.

Each probe layer must use a fresh UUID so a stale matching record cannot produce a false positive. The probes must not emit any real session data.

If Phase 1 found a backend unreachable (Prometheus or Loki), the corresponding layer must FAIL with a message naming the missing backend. The skill may not claim success by skipping a layer whose backend is down.

## Phase 5 — Report

- On full success, report the repository root, the propagation mechanism chosen, the tag string in effect, and the exact Loki query **and** Prometheus query the user can re-run later to confirm tagged sessions are arriving.
- On any failure, report the phase that failed, the specific check that failed, the observed output, and the next thing for the user to verify manually. Leave no partial state behind: if Phase 3 wrote files, restore from the pre-change backup before reporting.
- Record that the skill has run. A subsequent invocation in the same repository must re-run Phase 1 end-to-end, including every poisoned-identity and exporter-completeness check. Only when all checks pass may it offer a re-probe instead of proposing changes.

## What not to do

- Do not launch a real Claude Code session as part of the probe. The synthetic OTLP probes are sufficient and deterministic.
- Do not capture or log prompt content, tool parameters, or any session transcript during probing.
- Do not write an endpoint other than `http://localhost:*` into any file without a second explicit confirmation.
- Do not overwrite an existing `.envrc` or existing `.claude/settings.local.json` keys the skill did not add.
- Do not claim success if any probe layer fails, even if the earlier layers passed.
- Do not imply that data is being captured if the launch context the user actually uses to start Claude Code is not the one the probe validated.
- Do not treat an existing configuration as valid without running every Phase 1 check. "A tag string exists" is not evidence the tag is correct.
- Do not probe only the signal the user asked about. If the configuration enables metrics and logs, probe both.
