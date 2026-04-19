# Changelog

This changelog follows [Common Changelog](https://common-changelog.org/).

The canonical version is the `Version:` header in `ai-workflow.md`. Every bump of that header requires a matching entry here; the pre-push hook enforces this.

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
