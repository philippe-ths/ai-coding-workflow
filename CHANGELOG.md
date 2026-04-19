# Changelog

This changelog follows [Common Changelog](https://common-changelog.org/).

The canonical version is the `Version:` header in `ai-workflow.md`. Every bump of that header requires a matching entry here; the pre-push hook enforces this.

## 2.10.0 - 2026-04-19

### Added

- `workflow-review.md` at repo root — calendar-driven periodic review process executed outside the per-task workflow. Defines a minimum-data gate (≥ 2 versions of baseline data, ≥ 20 real Claude Code sessions per version, paired task coverage, consistent ruleset hash within each version), the inputs read (baseline JSONs, Loki session logs, Prometheus aggregates, sampled transcripts, `observed-ai-failings.md`), the analyses run (`scripts/compare-versions.py` for pass^k / McNemar / metric deltas, event-cluster scans on `tool_decision` and `fix_cycles`, LLM-as-judge on transcripts with required snippet citations), the proposal output format with five classifications (`hook`, `skill`, `rule`, `step`, `multi`), the disqualifying conditions (single-session evidence, sub-gate quantitative data, no specific surface, uncited LLM-judge claims, vague proposed change, missing rollback plan), and the approval workflow that funnels accepted proposals into `aiw-issue-creation` ([#113]).
- `docs/workflow-review-example-2026-04-19.md` — first worked example produced under the periodic review process; demonstrates the gate refusing on quantitative thinness (only `2.9.0` mock-agent baseline data on disk, zero captured Claude Code sessions) and includes one illustrative qualitative-only proposal that would itself be rejected under the disqualifying conditions ([#113]).

### Changed

- `project-context.md` Scope and Project Structure sections updated to list the new periodic review process and worked example; `Version:` header bumped to `1.3.0` ([#113]).
- `README.md` Maintenance documents section updated with a one-line pointer to `workflow-review.md` and the first worked example ([#113]).

## 2.9.0 - 2026-04-19

### Added

- `evals/` directory — baseline task harness (Sub-issue D) that runs frozen coding tasks and writes per-session JSONs matching `docs/telemetry-schema.md` ([#112]).
- `evals/harness/` — runner, JSON writer, workflow-version / ruleset-hash reader, pytest-based grader, and two agents: a host-side `mock` (copies a reference `solution/` into the workspace to prove the pipeline end-to-end) and `claude-code` (launches `claude -p` headlessly and parses `stream-json` for tokens, cost, tool calls, and session id; parser verified against a real t-001 run producing `input=8 output=301 cache_read=53401 cache_creation=27029 cost=$0.20 tool_use=[Read, Edit]`) ([#112]).
- `evals/harness/Dockerfile` and `evals/harness/compose.yaml` — sandbox image with the Claude Code CLI and pytest; reuses the D0 `host.docker.internal:host-gateway` bridge so OTEL traffic from inside the sandbox reaches the host collector ([#112]).
- `evals/tasks/` — three initial tasks drawn from `observed-ai-failings.md` patterns: `t-001-add-sum-function`, `t-002-fix-off-by-one`, `t-003-rename-function`, each with `spec.md`, `starter/`, `solution/`, and a hidden pytest `grader/` ([#112]).
- `scripts/run-baseline.sh` — creates `evals/.venv`, installs requirements, and runs one or more tasks × repeats; writes results to `telemetry/data/baseline/<version>/<ruleset_hash>/<task>/<run>.json` ([#112]).
- `scripts/compare-versions.py` — loads two versions' results, reports per-task and aggregate pass^k, runs McNemar's test on paired pass/fail outcomes (via `scipy.stats.binomtest` with an exact-binomial fallback), and prints mean/median deltas on duration, cost, tokens, and fix cycles ([#112]).
- `project-validation.sh` now `bash -n`s `scripts/run-baseline.sh` and `py_compile`s everything under `evals/harness/`, `evals/tasks/`, `evals/spikes/`, and `scripts/` ([#112]).
- Root `.gitignore` blocks `evals/.venv/` and Python caches ([#112]).

### Changed

- `docs/telemetry-schema.md` promoted from draft v0.1 to v0.2; `fix_cycles`, `checkpoint_reached`, `plan_accepted_first_pass`, and `tests.pre_baseline_passed` are now explicitly optional (nullable) in the v0.2 harness; shape is otherwise unchanged ([#112]).
- `project-context.md` Architecture Summary and Project Structure updated: this repo now ships runtime Python code under `evals/` and `scripts/` alongside the documentation and telemetry layers ([#112]).

## 2.8.0 - 2026-04-19

### Added

- `telemetry/` directory with a local OpenTelemetry Collector + Prometheus + Loki + Grafana stack (`docker-compose.yml`, per-service configs, provisioning, and four dashboards: session overview, tool usage, fix cycles, version comparison) for visualising Claude Code session telemetry emitted under the tags added in 2.7.0 ([#110]).
- `telemetry/otel-collector-config.yaml` redaction pipeline: strips `user.email`/`user.account_uuid`/`user.account_id`, hashes `user.id`/`organization.id`, scrubs emails/home paths/API-key patterns from log bodies, and truncates log attributes to 4096 chars ([#110]).
- `telemetry/up.sh`, `telemetry/down.sh` convenience wrappers and `telemetry/.gitignore` blocking captured data from the repo ([#110]).
- `docs/telemetry-setup.md` maintainer-facing setup, redaction, and troubleshooting guide ([#110]).
- `docs/telemetry-schema.md` draft v0.1 of the baseline-harness per-session JSON contract consumed by Sub-issue D (#112) ([#110]).
- `project-validation.sh` now syntax-checks `telemetry/*.sh`, telemetry YAML configs (when `python3` + `pyyaml` are present), Grafana dashboard JSON, and runs `docker compose config -q` when Docker is installed ([#110]).

### Changed

- README Session Telemetry section now links to `docs/telemetry-setup.md` and documents `./telemetry/up.sh` / `./telemetry/down.sh` ([#110]).
- `project-context.md` Architecture Summary updated to reflect the optional telemetry runtime layer; Key Dependencies document `docker` + `python3` + `pyyaml` as optional ([#110]).

## 2.7.1 - 2026-04-19

### Fixed

- Pre-push hook and agent PreToolUse hooks no longer block tag pushes from protected branches; `git push <tag>`, `git push --tags`, and MCP `create_ref` for `refs/tags/*` now succeed from `main` while branch pushes remain blocked ([#104]).

### Added

- `.ai-policy/scripts/test-pre-push-hook.sh` covering tag-vs-branch discrimination in the git-level pre-push hook, wired into `project-validation.sh` ([#104]).

## 2.7.0 - 2026-04-19

### Added

- `.ai-policy/scripts/update-session-tags.sh` computing `workflow_version` and an 8-hex `ruleset_hash` across rule-defining files and writing them into `.claude/settings.json`'s `env.OTEL_RESOURCE_ATTRIBUTES` ([#109]).
- `.ai-policy/hooks/check-session-tags.sh` pre-commit check that blocks commits when the tag fragment drifts from the current ruleset ([#109]).
- `.ai-policy/scripts/test-session-tags-hook.sh` enforcement test, wired into `project-validation.sh` ([#109]).
- README section describing the three maintainer-side telemetry shell variables and the OTEL temporality gotcha ([#109]).

### Changed

- `.claude/settings.json` carries a committed `env.OTEL_RESOURCE_ATTRIBUTES` value so Claude Code sessions emit tagged telemetry when the maintainer enables it.

## 2.6.0 - 2026-04-19

### Added

- `CHANGELOG.md` at repo root with backfilled entries for 2.0.0 through 2.5.1.
- `.ai-policy/hooks/check-changelog.sh` pre-push hook rejecting version bumps without a matching changelog entry.
- `.ai-policy/scripts/test-changelog-hook.sh` enforcement test, wired into `project-validation.sh`.

### Changed

- `ai-workflow-design-decisions/context-budget-and-maintenance.md` names `ai-workflow.md`'s `Version:` header as the canonical version source and requires a changelog entry for every bump.
- `lite-monolithic/ai-workflow.md` version header aligned to the canonical version.

## 2.5.1 - 2026-04-19

### Changed

- Renamed `project-spec` to `project-context` across workflow, skills, and agent entry points ([#99], [#107]).

## 2.5.0 - 2026-04-18

### Changed

- Namespaced core workflow skills with the `aiw-` prefix to avoid collisions with project-specific or third-party skills ([#100], [#105]).

## 2.4.0 - 2026-04-18

### Added

- `project-spec-management` skill, replacing the static `project-spec-template.md` ([#103]).

## 2.3.0 - 2026-04-13

### Changed

- Condensed the Validation Requirements, GitHub Workflow, and Boundary Rules sections ([#87], [#88]).

## 2.2.0 - 2026-04-13

### Added

- Test readiness checks in Step 1, feedback loop rules, and the `testing` skill ([#85], [#86]).

## 2.1.0 - 2026-04-13

### Added

- Explicit pre-PR readiness check as Step 11 ([#81], [#83]).

## 2.0.1 - 2026-04-13

### Fixed

- Audit-driven quick fixes across workflow wording and consistency ([#78], [#82]).

## 2.0.0 - 2026-04-12

### Changed

- Rewrote `ai-workflow.md` for writing quality, rule placement, and structural cleanup ([#77]).

[#77]: https://github.com/philippe-ths/ai-coding-workflow/pull/77
[#78]: https://github.com/philippe-ths/ai-coding-workflow/issues/78
[#81]: https://github.com/philippe-ths/ai-coding-workflow/issues/81
[#82]: https://github.com/philippe-ths/ai-coding-workflow/pull/82
[#83]: https://github.com/philippe-ths/ai-coding-workflow/pull/83
[#85]: https://github.com/philippe-ths/ai-coding-workflow/issues/85
[#86]: https://github.com/philippe-ths/ai-coding-workflow/pull/86
[#87]: https://github.com/philippe-ths/ai-coding-workflow/issues/87
[#88]: https://github.com/philippe-ths/ai-coding-workflow/pull/88
[#99]: https://github.com/philippe-ths/ai-coding-workflow/issues/99
[#100]: https://github.com/philippe-ths/ai-coding-workflow/issues/100
[#103]: https://github.com/philippe-ths/ai-coding-workflow/pull/103
[#105]: https://github.com/philippe-ths/ai-coding-workflow/pull/105
[#107]: https://github.com/philippe-ths/ai-coding-workflow/pull/107
[#104]: https://github.com/philippe-ths/ai-coding-workflow/issues/104
[#109]: https://github.com/philippe-ths/ai-coding-workflow/issues/109
[#110]: https://github.com/philippe-ths/ai-coding-workflow/issues/110
