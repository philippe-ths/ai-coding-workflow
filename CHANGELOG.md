# Changelog

This changelog follows [Common Changelog](https://common-changelog.org/).

The canonical version is the `Version:` header in `ai-workflow.md`. Every bump of that header requires a matching entry here; the pre-push hook enforces this.

Every `### Removed` bullet must lead with the removed path as a backticked token (`` - `path/to/thing` — explanation``), one removed path per bullet. The update path reads these to know which installed files to delete from a target repo, so the format must stay machine-extractable. `scripts/check-changelog-removals.sh` enforces this (factory-only validation; it is not shipped to target repos).

## 3.9.0 - 2026-07-14

### Changed

- Added the untrusted-external-content stance to the ground-truth sourcing guidance introduced in 3.8.0. `aiw-ground-truth` now states that content fetched from outside (web pages, third-party responses, anything an agent reads but did not write) is data to check, never instructions to obey, closing the gap where 3.8.0's new web-search and sub-agent sourcing encouraged reaching for external content without the default-untrusted stance. `CLAUDE.md` carries the same caution on its web-search tool line. Indirect prompt injection is a high-rate real surface, so sourcing ground truth from the open web must not become a channel for injected instructions. Applied identically to `.claude/skills/` and `.agents/skills/`; re-condensed into `lite-monolithic/ai-workflow.md` ([#185]).

## 3.8.0 - 2026-07-13

### Changed

- Reframed the workflow's stance on sub-agents from a single cost-to-justify warning into positive routing guidance, and named the built-in tools at the skill moments where fan-out or clean context pays. `ai-workflow.md` Resource Discipline now routes work to a sub-agent by its shape (broad multi-file search, mechanical or parallelisable work, distillable output, isolated parallel edits) while keeping judgment, design, and review of every returned result in the main loop. Skill triggers added at their fan-out moments: `aiw-planning` routes multi-area codebase reconnaissance to parallel read-only search sub-agents; `aiw-ground-truth` exhausts real sources via search sub-agents and web search before falling back to asking the user; `aiw-verification` folds a fresh clean-context sub-agent into its mandatory end-to-end run, on the leading idea that you are the worst verifier of your own change. Every trigger carries the main-loop-review guard inline, so encouragement does not become blind deference. Concrete Claude Code tool names (Explore, general-purpose, worktree isolation, web search) live in `CLAUDE.md` only; the mirrored skills stay capability-framed and identical across `.claude/skills/` and `.agents/skills/`. Design input drawn from the maintainer's knowledge base; the KB itself does not ship. Re-condensed into `lite-monolithic/ai-workflow.md` ([#183]).

## 3.7.3 - 2026-07-13

### Changed

- Trimmed skill-body openings that restated the frontmatter `description` the loader already matches on, so the body starts at what it uniquely adds. `aiw-github` lost its intro line outright (pure restatement of the description's action enumeration, already the section headings below). `aiw-ground-truth`, `aiw-performance-profiling`, and `aiw-security-testing` kept only the part beyond the description (the re-entry trigger, the added scope of sync/async conversion and stated latency requirement plus platform examples, and the "broader than they look" amplification), dropping the trigger-recap framing. `aiw-planning` collapsed its two adjacent orientation sections ("Where This Skill Sits" and "The Full Skill Sequence") into one, keeping the numbered sequence and the defers-to-other-skills principle. No trigger or rule intent was lost. Surfaced by running the `aiw-prompt-smith` skill across the skill set. Applied identically to `.claude/skills/` and `.agents/skills/`; the lite condensation carries no skill intros, so only its `Version:` header is synced ([#180]).

## 3.7.2 - 2026-07-11

### Changed

- Removed the redundant negative-restatement tail sections ("Anti-Patterns", "What Not to Do", "What Not to Include") from seven skills, where each mostly re-stated in "don't" form a rule the body already gives positively. `aiw-planning`, `aiw-failure-analysis`, and `aiw-verification` lost the section outright (every bullet was a restatement). `aiw-testing`, `aiw-performance-profiling`, `aiw-security-testing`, and `aiw-project-context-management` kept their genuinely net-new items, promoted into the body as positive rules: the component under test must actually run (testing); host-independent assertions and non-production input (performance); testing the project's own use of a framework rather than the framework itself (security); and excluding issue/PR references and process documentation (project-context). No rule's intent was lost. Surfaced by running the `aiw-prompt-smith` skill across the skill set. Applied identically to `.claude/skills/` and `.agents/skills/` ([#178]).

## 3.7.1 - 2026-07-10

### Changed

- `aiw-issue-creation`: collapsed the four-item "What the Issue Must Not Contain" enumeration and its rationale note into a single class-level principle folded into the "may contain" path guidance. The prohibitions (reproducing file contents, code snippets, function/line references, prescribing an approach) were four instances of one class the skill's own note already named; they now read as one rule built on the leading word "peg", stated once, so the guidance also covers cases the list did not enumerate. Applied identically to `.claude/skills/` and `.agents/skills/`; the lite condensation already stated the class-level form, so only its `Version:` header is synced ([#175]).

## 3.7.0 - 2026-07-10

### Added

- `aiw-prompt-smith` skill added to `.claude/skills/` and `.agents/skills/`: a meta-authoring skill for writing and repairing prompting artifacts (system prompts, `CLAUDE.md`, `AGENTS.md`/`AGENT.md`, and other skills). It is organised around *altitude* — fixing the class an instance belongs to rather than appending a narrow rule per failure — and covers a write mode and a repair mode over a shared set of principles. It ships in the full profile to all four tools and is pulled by its description rather than wired into the numbered task flow, like `aiw-issue-creation`. The `lite-monolithic` condensation is unchanged in content because prompt-smith is orthogonal to the coding task flow it condenses; only its `Version:` header is synced to the canonical anchor ([#173]).

## 3.6.0 - 2026-06-18

### Added

- `ai-workflow.md`: new `Resource Discipline` section instructing the agent to protect its context window and the human's quota without doing less than the task requires. It establishes a single priority order (minimise total token cost, with correctness as an absolute floor), a general floor rule that efficiency governs how a required step is discharged and never whether, narrow reading qualified by need, and subagent use tied to the sanctioned parallelism/clean-context purposes rather than spawned as a reflex to empty the main context. The companion rationale and misuse analysis are recorded in `design/decisions/context-economics.md` ([#170]).

## 3.5.2 - 2026-06-12

### Fixed

- `lite-monolithic/ai-workflow.md`: closed the remaining content drift against the canonical workflow and skills. The lite condensation had silently fallen behind on a handful of agent-facing rules; the genuine gaps are now inlined: a new "Test Construction" section (write the failing test first for a Fix, propose a broader class-of-bug test and name the coverage gap, do not mock the boundary a Configure/Migrate must exercise, assert on observable behaviour, and the mutation-style spot check that a suite turns red under deliberate breakage); ground-truth provenance metadata; duplicate-issue search before creating a follow-up; the back-up-the-working-tree safeguard before a risky branch transition; adding observability when the runtime path has no output to read; and the post-merge issue comment and checkbox steps ([#114]).

### Added

- `scripts/repo-validation.sh` now fails when `lite-monolithic/ai-workflow.md`'s `Version:` header does not equal the canonical `ai-workflow.md` version. The lite parity rule was documentation-only and drifted unnoticed; this turns a lagging lite version into a loud validation failure so a canonical bump cannot silently leave the lite file unsynced ([#114]).

## 3.5.1 - 2026-06-12

### Fixed

- The update path now removes the superseded un-prefixed skill directories left behind when upgrading an install that predates the `aiw-` skill-name prefix. The prefix rename ([#100], [#105]) and the project-spec to project-context rename ([#99], [#107]) were recorded only under `### Changed`, never as removable paths, so the updater treated the old directories as local additions and kept them next to the current `aiw-*` skills. They are now recorded as `### Removed` paths below, so the existing directory-removal reconciliation in `scripts/update.sh` deletes them while still preserving genuine local additions (skill directories with no current-product counterpart) ([#165]).

### Removed

- `.claude/skills/planning/` — superseded by `aiw-planning` in the `aiw-` prefix rename; left behind on upgrades from pre-prefix installs.
- `.claude/skills/testing/` — superseded by `aiw-testing`.
- `.claude/skills/failure-analysis/` — superseded by `aiw-failure-analysis`.
- `.claude/skills/issue-creation/` — superseded by `aiw-issue-creation`.
- `.claude/skills/project-spec-management/` — superseded by `aiw-project-context-management` (renamed in the project-spec to project-context move).
- `.claude/skills/logging-and-observability/` — content redistributed into `aiw-verification` and `aiw-failure-analysis`; no standalone skill remains.
- `.agents/skills/planning/` — superseded by `aiw-planning`.
- `.agents/skills/testing/` — superseded by `aiw-testing`.
- `.agents/skills/failure-analysis/` — superseded by `aiw-failure-analysis`.
- `.agents/skills/issue-creation/` — superseded by `aiw-issue-creation`.
- `.agents/skills/project-spec-management/` — superseded by `aiw-project-context-management`.
- `.agents/skills/logging-and-observability/` — content redistributed into `aiw-verification` and `aiw-failure-analysis`.

## 3.5.0 - 2026-06-11

### Added

- `ai-workflow.md` and `lite-monolithic/ai-workflow.md`: new "Asking for Guidance" section. Whenever the agent asks the human a question or requests guidance on a decision, it must present it as a short framing paragraph, a list of options each with an explanation, a clear recommendation, and the rationale for that recommendation.

## 3.4.1 - 2026-06-09

### Fixed

- `.ai-policy/scripts/project-validation.sh` now warns loudly when no `./scripts/repo-validation.sh` is wired, instead of silently skipping it. A fresh install previously reported "Validation passed" while running only the policy-layer self-checks — none of the host project's tests, linters, or type checks — implying coverage that was not there. The validator now prints an unmistakable `WARNING` whenever repo-specific checks are absent (and announces them when present), so a fresh install can no longer present a silently-empty green gate. Behaviour is unchanged for repos that have wired their own checks ([#155]).

### Added

- `.ai-policy/scripts/test-project-validation.sh`: sandbox regression test asserting the validator warns and still passes when `./scripts/repo-validation.sh` is absent, and runs it without warning when present.

## 3.4.0 - 2026-06-07

### Changed

- `aiw-issue-creation` skill (both `.agents/skills/` and `.claude/skills/`): issues may now reference relevant files by path to locate a concern, while restating, pasting, or paraphrasing file contents is forbidden. This reconciles the former blanket "no file paths" rule into a single coherent boundary — a bare path locates the concern (allowed); file contents, an implementation approach, or a function/line reference bias the implementing agent (forbidden). Issues may also carry an optional, non-binding list of suggested workflow skills to orient whoever implements them ([#156]).

## 3.3.0 - 2026-06-02

### Removed

- `telemetry/` — the entire local OTEL Collector + Prometheus + Loki + Grafana stack, the five dashboards, the redaction pipeline, and both launchd autostart installers. The OTLP/Prometheus pipeline was silently dropping ~80% of sessions and required a babysitting skill to keep alive.
- `evals/` — the baseline evaluation harness. The statistical A/B apparatus (pass^k, McNemar, the n=20 readiness gate) could not produce trustworthy verdicts from a single developer's sparse, cross-repo data.
- `scripts/run-baseline.sh` — baseline harness runner.
- `scripts/compare-versions.py` — pass^k / McNemar comparison.
- `scripts/eval-preflight.sh` — between-review readiness gate.
- `.agents/skills/aiw-evaluation/` — review-readiness skill.
- `.claude/skills/aiw-evaluation/` — review-readiness skill.
- `.agents/skills/aiw-telemetry-setup/` — telemetry enablement skill.
- `.claude/skills/aiw-telemetry-setup/` — telemetry enablement skill.
- `design/decisions/evaluation.md` — evaluation gate rationale.
- `docs/telemetry-setup.md` — telemetry setup guide.
- `docs/telemetry-schema.md` — per-session JSON contract.
- `docs/spikes/d0-sandbox-otel.md` — sandbox OTEL spike.
- `.envrc.example` — telemetry env template.
- `.ai-policy/scripts/update-session-tags.sh` — session-tag writer.

### Added

- `observation/`: a local, single-developer session-observation tool that reads Claude Code transcripts already on disk into a JSONL Session Store and a self-contained static HTML dashboard. Descriptive only, no Docker, no server, nothing running in the background. Captures token usage, estimated cost, tool calls, skill activations, session length, and user turns per session across all repos.
- Global capture installed by `observation/install-observation.sh`: a defensive SessionStart Manifest hook (records `workflow_version` per session) and a `/rate` skill (records a 1-4 quality Rating). Capture is per-developer and global; only the reader and dashboard live in this repo.
- `docs/adr/0001` and `docs/adr/0002` recording the move from statistical comparison to descriptive observation and the global-not-per-repo capture decision; `CONTEXT.md` glossary for the observation domain.

### Changed

- `project-context.md` rewritten to describe the observation tool and corrected skill inventory; `Version:` header bumped to `1.12.0`.
- `scripts/repo-validation.sh` now validates `observation/` (shell syntax, `py_compile`, the parser regression test, JSONL fixture validity) instead of the removed telemetry and harness surface.
- `README.md` and `design/README.md` updated to drop the removed telemetry and evaluation surface.

## 3.2.1 - 2026-05-29

### Fixed

- Shortened the frontmatter `description` of five skills (`aiw-planning`, `aiw-ground-truth`, `aiw-testing`, `aiw-verification`, `aiw-failure-analysis`) in both `.agents/skills/` and `.claude/skills/` to under 1024 characters. OpenAI Codex enforces a 1024-character maximum on skill descriptions and was silently skipping these five at load time, leaving Codex users running the workflow without its core planning, ground-truth, testing, verification, and failure-analysis disciplines. Intent and triggering content are preserved; the repo's own authoring rule (`design/decisions/authoring.md`) already mandated the 1024-character limit ([#152]).

## 3.2.0 - 2026-05-28

### Added

- `scripts/eval-preflight.sh` Condition 5: `.envrc` `OTEL_RESOURCE_ATTRIBUTES` must match the values recomputed from current ruleset files. Catches the recurring tagging-staleness class where a workflow bump or rule edit was never propagated to `.envrc`, so the current session's data was being emitted under the wrong tag.
- `scripts/eval-preflight.sh` Condition 6: the baseline harness must be able to resolve `workflow_version` and `ruleset_hash` at import time. Catches code-side breakage in `evals/harness/context.py` before the next review walks into it.
- `design/decisions/evaluation.md` minimum-data gate updated to document Conditions 5 and 6.

### Fixed

- `evals/harness/context.py` was reading `ruleset_hash` from `.claude/settings.json`'s `env` block, which the telemetry policy (`aiw-telemetry-setup/SKILL.md`) explicitly forbids and `update-session-tags.sh` never writes there. The baseline harness raised `RuntimeError` on every invocation. Now reads from `.envrc`, which is the policy-mandated source.

## 3.1.0 - 2026-05-28

### Added

- `aiw-evaluation` skill in both `.agents/skills/` and `.claude/skills/`: enforces the between-review readiness gate before the periodic workflow review process can produce proposals. Reads `telemetry/eval-readiness.json` (produced by `scripts/eval-preflight.sh`), refuses to run the review past a red gate, and writes a thin-data report under `observations/workflow-reviews/<date>.md` instead. Hands off to `design/decisions/evaluation.md` only when the preflight returns exit 0 ([#145]).

### Changed

- `project-context.md` Project Structure section lists `aiw-evaluation`; `Version:` header bumped to `1.10.0` ([#145]).

## 3.0.0 - 2026-05-28

Major redesign of the workflow structure. The 14-step numbered workflow plus reference sections in `ai-workflow.md` is replaced by a leaner four-section structure (First Principles, Task Flow, Boundary Rules, The Human is Responsible For) that delegates enforcement to a refactored skill set. Three new core skills own concerns previously fused into a single workflow document.

### Added

- `aiw-verification` skill in both `.agents/skills/` and `.claude/skills/`: owns the required justification step before any "done" claim, the evidence hierarchy from static checks through end-to-end runs on real artifacts, the rules for when end-to-end execution is mandatory, modality-aware verification requirements, and the scoping step that names what was not checked.
- `aiw-ground-truth` skill in both directories: establishes where trusted inputs and expected outputs come from during coding tasks. Owns the canonical task modality decision procedure (New, Feature, Fix, Refactor, Improve, Investigate, Migrate, Configure, Delete) shared across `aiw-planning`, `aiw-testing`, and `aiw-verification`.
- `aiw-github` skill in both directories: rules for every GitHub and git history action during a task, including branch safety, rebase discipline, and the rule that commit, push, and PR creation are separate human-approved actions.
- `ai-workflow.md` Task Flow section: six high-level steps that delegate enforcement to the skill set at each step.
- `ai-workflow.md` Non-Functional Dimensions section: conditional loading triggers for `aiw-performance-profiling` and `aiw-security-testing`.
- `ai-workflow.md` Reactive Rules section: explicit override stating that `aiw-failure-analysis` runs when a "done" claim is contradicted, before any fix is proposed; this rule overrides the rest of the workflow when triggered.
- Entry-point files (`CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, `.github/copilot-instructions.md`) now require the agent to confirm reading both `ai-workflow.md` and `project-context.md` and being able to invoke the `aiw-*` project skills before responding to the first task message.
- `observations/workflow-reviews/2026-05-28.md`: second worked-example execution of the periodic review process; demonstrates the gate refusing on structural data thinness rather than just sample-size thinness.

### Changed

- `ai-workflow.md` restructured around four sections (First Principles, Task Flow, Boundary Rules, The Human is Responsible For) plus a Reactive Rules override and a Non-Functional Dimensions loader. Replaces the prior 14-step numbered workflow plus reference-section structure.
- `aiw-planning` skill rewritten to own the pre-planning codebase baseline checks (smoke tests, global suite, test readiness, bounded-change confirmation), the task modality classification step that hooks into `aiw-ground-truth`, oracle naming, assumption classification (issue-sourced vs codebase-confirmed), higher-risk flagging, and verification-approach expectations.
- `aiw-testing` skill rewritten to focus on test mechanics, test-level selection, modality-specific testing emphasis (cross-referenced into `aiw-ground-truth`), the anti-patterns that produce misleading green bars, and the hygiene rules that keep a test suite a reliable signal. Ground-truth concerns move to `aiw-ground-truth`; verification-sufficiency concerns move to `aiw-verification`.
- `aiw-failure-analysis` skill rewritten to own the structured pause after a contradicted "done" claim, the audit of the three core skills (`aiw-ground-truth`, `aiw-testing`, `aiw-verification`) to locate where the gap opened, the hypothesis-and-evidence loop that replaces speculative fixing, the convergence check for when repeated fixes are not working, and plan-level flaw detection.
- `aiw-performance-profiling` and `aiw-security-testing` skills retained with light edits to align with the new section structure.

### Removed

- `.agents/skills/aiw-logging-and-observability/` — content redistributed into `aiw-verification` (runtime-output reading as evidence) and `aiw-failure-analysis` (diagnostic logging during investigation). No standalone observability skill remains; the obligations are owned by the verification and failure-analysis skills that consume them.
- `.claude/skills/aiw-logging-and-observability/` — content redistributed into `aiw-verification` and `aiw-failure-analysis`.

## 2.16.0 - 2026-04-26

### Added

- `aiw-security-testing` skill in both `.agents/skills/` and `.claude/skills/`: automated security testing rules for changes that touch authentication, authorisation, untrusted input, file-path or shell-command construction, secret handling, external API consumers, or data-access boundaries. Names the trigger surface explicitly and prescribes negative-path coverage, boundary testing, threat-model-aligned assertions, attack-corpus testing for path and command construction, parser/escaper round-trip testing, fixture-secret hygiene, redaction-boundary assertions for log leak coverage, bypass-path testing for trusted-caller exemptions, a feasibility-fallback rule that forbids silent reversion to manual, and a rule against weakening failing security tests without investigation. Motivated by issue #129: security coverage was previously a single negative-path bullet inside `aiw-testing`, which is too narrow for projects with real security surface ([#129]).
- `Security Testing` loader section in `ai-workflow.md`: names the trigger conditions under which `aiw-security-testing` must be loaded, including the catch-all for novel trust boundaries introduced during implementation ([#129]).

### Changed

- `aiw-testing` skill in both skill directories now cross-references `aiw-security-testing` from its `Related Workflow Sections` block and from its `Non-Functional Coverage` security paragraph; the existing one-line negative-path summary remains in place as a minimum bar so `aiw-testing` is still useful when read on its own ([#129]).
- `design/decisions/ai-workflow-line-by-line.md` gains a `### Security Testing` block with rationale entries for each new line in the loader, mirroring the structure used for `Performance and UI-State Profiling` ([#129]).
- `project-context.md` Project Structure section lists `aiw-security-testing`; `Version:` header bumped to `1.8.0` ([#129]).

## 2.15.0 - 2026-04-22

### Changed

- `aiw-telemetry-setup` skill in both `.agents/skills/` and `.claude/skills/` rewritten so that invoking it is the only user-facing action required to turn on telemetry in a target repository. Phase 1 now catches poisoned identity (an `OTEL_RESOURCE_ATTRIBUTES` whose `workflow_repo` does not match the target directory basename, or `workflow_repo=ai-coding-workflow` outside the upstream repo), missing exporters (`OTEL_LOGS_EXPORTER` or `OTEL_METRICS_EXPORTER` absent while telemetry is enabled), protocol/endpoint mismatch, stale identity in tracked `.claude/settings.json`, and local-stack reachability for Prometheus and Loki. Phase 2 always writes both exporters and always bases `workflow_repo` on the target directory. Phase 3 writes to gitignored `.envrc` (direnv path) or `.claude/settings.local.json` (IDE path), never to tracked `.claude/settings.json`. Phase 4 gains a fourth probe layer that emits a synthetic OTLP counter and verifies round-trip via Prometheus, so a configuration that passes but emits no metrics can no longer be mistaken for success ([#136]).
- `.claude/settings.json` no longer carries `env.OTEL_RESOURCE_ATTRIBUTES`. Telemetry identity moves to gitignored `.envrc`, so copying this repository's files into a target repository cannot silently propagate `workflow_repo=ai-coding-workflow` into that target ([#136]).
- `.ai-policy/scripts/update-session-tags.sh` retargets to `.envrc` and inserts/updates a sentinel-delimited managed block idempotently. The `--check` drift mode is removed because there is no longer a tracked file to drift. The script self-scopes to the `ai-coding-workflow` repository by directory-basename check and exits 0 in any other repo ([#136]).
- `README.md` promotes `aiw-telemetry-setup` from an "Optional" extra to the standard telemetry install step for Claude Code. The "Session Telemetry" reference section is rewritten to reflect `.envrc`-hosted identity and the removal of the pre-commit drift check ([#136]).
- `docs/telemetry-setup.md` restructured so the target-repo path points at the skill and the `ai-coding-workflow` path points at `.envrc.example`; both list `OTEL_METRICS_EXPORTER=otlp` and `OTEL_LOGS_EXPORTER=otlp` as required-together ([#136]).
- `.envrc.example` now declares `OTEL_RESOURCE_ATTRIBUTES` alongside the exporter variables so enabling telemetry in this repo sets identity in one place ([#136]).
- `.envrc.example`, the `aiw-telemetry-setup` skill's required change set, README, and `docs/telemetry-setup.md` now require `OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE=cumulative`. Claude Code defaults to delta temporality, but the shipped `prometheusremotewrite` exporter requires cumulative — without the override, real Claude Code sessions emit logs to Loki but metrics silently fail to reach Prometheus, leaving the Session Overview, Tool Usage, and Version Comparison dashboards empty. Discovered while post-implementation-verifying that real telemetry (not just the synthetic probe) was reaching both backends ([#136]).

### Removed

- `.ai-policy/hooks/check-session-tags.sh` — pre-commit hook (and its invocation from `.githooks/pre-commit`). The drift it caught was drift in a tracked file; now that identity is no longer tracked, the drift class does not exist ([#136]).
- `.ai-policy/scripts/test-session-tags-hook.sh` — covered the deleted hook ([#136]).
- `.ai-policy/scripts/project-validation.sh` — removed the session-tags test gating from it ([#136]).

## 2.14.0 - 2026-04-20

### Changed

- `ai-workflow.md` Step 9 header reframed from "fix and revalidate" to "check [Failure Analysis Mode] before proposing a fix" so the trigger check runs ahead of the fix; the bullet count drops from four to three ([#98]).
- `ai-workflow.md` Failure Analysis Mode section rewritten to name the dominant trigger inline (user says behaviour is still broken, a fix didn't help, or what they see contradicts what validation reported), retain the manual-verification and runtime-contradiction triggers, and add an explicit "if uncertain, enter" line; total length held to five short sentences ([#98]).
- `aiw-failure-analysis` skill in both `.agents/skills/` and `.claude/skills/` updated: the frontmatter description now names concrete user phrases ("still broken", "still doesn't work", "didn't help", "the bug remains", "not working", "doing the wrong thing") to raise Claude Code auto-surface salience, and the em-dash construction is removed. The skill body is unchanged; triggers live once, in the description, and the body describes the process after entry ([#98]).
- `lite-monolithic/ai-workflow.md` mirrors the Step 9 reframe and the leaner Failure Analysis Mode wording inline; `Version:` header bumped to `2.14.0` ([#98]).

## 2.13.0 - 2026-04-19

### Changed

- `.ai-policy/scripts/project-validation.sh` is now portable across repos. It validates only the policy layer itself (`bash -n` on `.ai-policy/scripts/`, `.ai-policy/hooks/`, and `.githooks/`) and then runs each `test-*.sh` under `.ai-policy/scripts/` whose matching agent entry point is installed: `test-claude-code-enforcement.sh` and `test-session-tags-hook.sh` require `./.claude/`, `test-codex-enforcement.sh` requires `./.codex/`, `test-gemini-enforcement.sh` requires `./.gemini/`, `test-vscode-copilot-enforcement.sh` requires `./.github/hooks/`; `test-changelog-hook.sh` and `test-pre-push-hook.sh` always run. If `./scripts/repo-validation.sh` exists and is executable, it runs at the end. Fresh target-repo installs following the README no longer fail validation on missing paths, and per-tool installs (Claude-Code-only, Codex-only, etc.) are now supported out of the box without editing any shipped file ([#131]).

### Added

- `scripts/repo-validation.sh` at the repo root carries this repo's repo-specific checks (telemetry YAML/JSON syntax, baseline-harness Python `py_compile`, `bash -n` on `telemetry/*.sh` and `scripts/run-baseline.sh`, `docker compose config -q`). The file is not part of the shipped policy layer; target repos supply their own `scripts/repo-validation.sh` to declare their tests, linters, or type checks. The shipped `project-validation.sh` invokes it automatically when present ([#131]).
- README `Post-install setup` now documents `scripts/repo-validation.sh` as the per-repo extension point and describes the agent-gated skipping behaviour of the enforcement tests ([#131]).

## 2.12.0 - 2026-04-19

### Added

- `aiw-performance-profiling` skill in both `.agents/skills/` and `.claude/skills/` — automated performance and UI-state-transition coverage rules. Lists the trigger conditions (UI state transitions, reactive rerenders, caching, memoisation, debouncing, manual state resets, heavy data loops, sync/async path swaps) and prescribes baseline capture, tolerance-anchored latency assertions, multi-run stable-statistic benchmarks, isolated timed sections, UI transition outcome plus latency assertions, caching-workaround regression tests, a feasibility-fallback rule that forbids silent reversion to manual, and a rule against weakening failing thresholds without investigation ([#127]).
- `Non-Functional Test Coverage` reference section in `ai-workflow.md` — requires the agent to attempt automated coverage for UI state transitions, execution latency, and security-relevant behaviour before suggesting manual verification, and to state in writing when automation is not feasible. Motivated by Entry 21 in `observed-ai-failings.md`, where the agent passed functional tests while shipping severe UI stuttering and latency regressions in FCP Auto-Editor ([#127]).
- `Performance and UI-State Profiling` loader section in `ai-workflow.md` — names the conditions under which `aiw-performance-profiling` must be loaded ([#127]).

### Changed

- `Manual Verification Requirements` in `ai-workflow.md` tightened — manual checks must cite the non-functional coverage section before being proposed, and the "automated tests can verify" exclusion is rephrased to target behaviour rather than checks ([#127]).
- Step 7 in `ai-workflow.md` now points at `Non-Functional Test Coverage` and restricts manual checks to what automation cannot cover ([#127]).
- `aiw-testing` skill in both skill directories gained a `Non-Functional Coverage` subsection covering the three categories, a pointer to `aiw-performance-profiling`, a security negative-path rule, and the feasibility-fallback rule ([#127]).
- `lite-monolithic/ai-workflow.md` mirrors the Non-Functional Test Coverage rules inline and carries `Version: 2.12.0`; the file had drifted from canonical since `2.8.0` and this change realigns it only for the non-functional coverage rule set, not for changes introduced between `2.9.0` and `2.11.0` ([#127]).
- `project-context.md` Project Structure section lists `aiw-performance-profiling`; `Version:` header bumped to `1.5.0` ([#127]).

## 2.11.0 - 2026-04-19

### Added

- `aiw-telemetry-setup` skill in both `.agents/skills/` and `.claude/skills/` — guided, mostly-automated process for enabling Claude Code session telemetry in any repository and verifying end-to-end that tagged data reaches the local telemetry store before reporting success. The skill automates pre-flight detection (collector reachability, direnv presence, launch context, existing configuration) and the round-trip probe (collector reachability, shell-env propagation, synthetic OTLP log carrying a fresh UUID matched back in Loki), presents a single consolidated change set for user approval, and never enables telemetry as a default side effect. Motivated by a silent non-emission failure observed during acceptance testing of #101 on 2026-04-19, where an IDE-launched Claude Code session in this repo emitted nothing because `.envrc` did not propagate through the VS Code launch path ([#124]).

### Changed

- `project-context.md` Project Structure section lists `aiw-telemetry-setup` in the enumerated skill set; `Version:` header bumped to `1.4.0` ([#124]).
- `.ai-policy/scripts/update-session-tags.sh` self-scopes to the `ai-coding-workflow` upstream repository. When the current `env.OTEL_RESOURCE_ATTRIBUTES` does not declare `workflow_repo=ai-coding-workflow`, both `--check` and write modes exit 0 without reading, writing, or drift-checking. Downstream repositories that copy `.ai-policy/` wholesale per the install instructions no longer have their skill-written repo-distinguishing tag strings overwritten or commits blocked by the session-tags hook. Covered by three new cases in `.ai-policy/scripts/test-session-tags-hook.sh` ([#124]).

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
[#156]: https://github.com/philippe-ths/ai-coding-workflow/issues/156
[#155]: https://github.com/philippe-ths/ai-coding-workflow/issues/155
[#99]: https://github.com/philippe-ths/ai-coding-workflow/issues/99
[#165]: https://github.com/philippe-ths/ai-coding-workflow/issues/165
[#114]: https://github.com/philippe-ths/ai-coding-workflow/issues/114
[#170]: https://github.com/philippe-ths/ai-coding-workflow/issues/170
[#173]: https://github.com/philippe-ths/ai-coding-workflow/issues/173
[#175]: https://github.com/philippe-ths/ai-coding-workflow/issues/175
[#178]: https://github.com/philippe-ths/ai-coding-workflow/issues/178
[#180]: https://github.com/philippe-ths/ai-coding-workflow/issues/180
[#183]: https://github.com/philippe-ths/ai-coding-workflow/issues/183
[#185]: https://github.com/philippe-ths/ai-coding-workflow/issues/185
