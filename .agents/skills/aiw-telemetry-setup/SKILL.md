---
name: aiw-telemetry-setup
description: "Guided, mostly-automated process for enabling Claude Code session telemetry in any repository and verifying end-to-end that tagged data reaches the local telemetry store before reporting success. Use this skill when the user asks to start recording sessions, enable telemetry in a new repo, set up observability for Claude Code, or investigates why an expected session is missing from Grafana or Loki. The skill exists to prevent the silent non-emission failure mode where a session runs normally but emits nothing because an environment variable did not propagate to the process that actually launched Claude Code."
---

# Telemetry Setup

Read this file when the user wants to start recording Claude Code session telemetry in a repository.
The telemetry stack itself lives in the `ai-coding-workflow` repository under `telemetry/`; this skill configures a repository — the current one or any other — to emit into that stack.

## Principles

- Automate every detection and probe step.
- Ask the user exactly once, with a consolidated summary of every file the skill would create or modify, before writing anything.
- Never enable telemetry as a default side effect. The skill runs only when explicitly invoked.
- On any failure, leave the repository in the state it was in before the skill ran.
- Report SUCCESS or FAIL with the specific phase that failed and the next thing for the user to check.

## Phase 1 — Pre-flight detection (automated, read-only)

Run all of these before asking the user anything. Collect findings and present them together.

- Resolve the target repository root. Report it.
- Detect collector reachability by probing the local OTLP endpoints on the host running the user's shell. Do not probe remote endpoints.
- Detect whether `direnv` is installed and whether the target repository contains an existing `.envrc`.
- Detect the launch context of the current Claude Code process and of the likely future launches: terminal vs IDE. Check standard IDE indicator variables, the process parent, and the binary path. State confidence.
- Detect whether the target repository already has `.claude/settings.json` and whether it has an `env` block.
- Detect whether telemetry appears to be already configured in the target repository. Do not modify anything if yes; offer re-probe instead.
- Do not launch Claude Code, do not send any network traffic other than the collector reachability probe, and do not write files during this phase.

## Phase 2 — Propose a single change set

Based on Phase 1, decide the propagation mechanism:

- If direnv is available and the launch context is terminal, propose writing or extending `.envrc`.
- If direnv is absent or the launch context is IDE, propose writing the enable and endpoint variables into the `env` block of `.claude/settings.json`. Warn that these values are committed to the repository and require a local-only endpoint.
- Never propose an endpoint that is not `http://localhost:*` without a second explicit confirmation from the user that they understand the endpoint will be committed and visible to anyone who clones the repository.

Pick the tag strategy:

- Default the repository identifier to the repo's directory name.
- If the target repository has its own `ai-workflow.md` with a `Version:` header, read it and offer it as the `workflow_version` tag. Otherwise propose a plain free-form version string or omit the field.
- Do not replicate the `update-session-tags.sh` ruleset-hash machinery into downstream repositories. That mechanism belongs to the `ai-coding-workflow` repository. Downstream repositories use a plain-string `OTEL_RESOURCE_ATTRIBUTES`.

Present the change set as a single summary:

- Every file that will be created, with its full proposed content.
- Every file that will be modified, with a precise diff of the lines being added.
- The tag string the repository will carry.
- The probe the skill will run afterwards.

Ask the user to approve this summary once. Proceed only on explicit approval. On approval, proceed through Phases 3 and 4 without further prompts.

## Phase 3 — Apply changes (after single confirmation)

- Back up any file the skill modifies before writing. Restore the backup if any later step in this phase or Phase 4 fails.
- When writing `.envrc`, read any existing file first and merge rather than overwrite. Never remove user-authored exports that the skill did not add.
- When writing `.claude/settings.json`, preserve existing keys. Only touch the `env` block.
- After writing, if direnv is the chosen mechanism, instruct the user to run `direnv allow` and confirm the environment propagates. This is the only user action the skill requests after the confirmation gate.

## Phase 4 — Probe (automated, reported layer by layer)

Run the probe layers in order. Report each layer's result as it completes. Stop and report FAIL at the first failing layer.

- **Layer 1 — Collector reachability.** Send an HTTP probe to the OTLP endpoint and require a success response.
- **Layer 2 — Shell environment propagation.** Start a child shell under the same context the user will launch Claude Code from, and verify that the enable flag, the OTLP endpoint, and the resource attributes are present with the expected values.
- **Layer 3 — End-to-end round-trip.** From the same propagation context, send a synthetic OTLP log record that carries a freshly generated UUID in its body. After a short wait, query Loki for that UUID and confirm the returned record carries the expected resource attributes.

Layer 3 must use a fresh UUID for each probe so a stale matching record cannot produce a false positive. The probe must not emit any real session data.

## Phase 5 — Report

- On full success, report the repository root, the propagation mechanism chosen, the tag string in effect, and the exact Loki query the user can re-run later to confirm tagged sessions are arriving.
- On any failure, report the phase that failed, the specific check that failed, the observed output, and the next thing for the user to verify manually. Leave no partial state behind.
- Record that the skill has run. A subsequent invocation in the same repository should detect the prior configuration and offer a re-probe instead of re-writing.

## What not to do

- Do not launch a real Claude Code session as part of the probe. The synthetic OTLP probe is sufficient and deterministic.
- Do not capture or log prompt content, tool parameters, or any session transcript during probing.
- Do not write an endpoint other than `http://localhost:*` into `.claude/settings.json` without a second explicit confirmation.
- Do not overwrite an existing `.envrc` or existing `.claude/settings.json` keys the skill did not add.
- Do not claim success if any probe layer fails, even if the earlier layers passed.
- Do not imply that data is being captured if the launch context the user actually uses to start Claude Code is not the one the probe validated.
