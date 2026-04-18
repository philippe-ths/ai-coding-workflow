---
name: project-spec-management
description: "Structured process for initializing and updating `project-spec.md`, a repository's factual reference of current implementation truth. Use this skill when the human asks to create, scaffold, refresh, or correct the project spec — including phrasings like 'update the spec', 'the architecture summary is out of date', 'document the project structure', or 'the project-spec.md is stale' — and when the agent detects the existing spec has drifted from the codebase after changes to routes, schema, sync rules, dependencies, project structure, or test coverage. The skill exists to prevent specs from drifting into planned architecture, roadmap language, or multi-sentence lines that degrade agent parsing in future sessions."
---

# Project Spec Management

Read this file before creating or editing `project-spec.md`.
`project-spec.md` is a repository's factual reference of current implementation truth — agents consult it to orient quickly before planning changes.

## Required Sections

Use these sections, in order; omit one only when the repository has no reliable information for it.

- `## Product Summary` — what the product is, who uses it, the core user flow.
- `## Domain Concepts` — the main entities and their relationships.
- `## Scope` — what the product currently supports, major workflows, known non-goals.
- `## Important Constraints` — hard product, technical, policy, data, or environment constraints.
- `## Architecture Summary` — architecture style, runtime layers, primary data flow, external boundaries.
- `## Key Dependencies` — each dependency and why it exists.
- `## Project Structure` — each significant path or module and what it owns.
- `## Testing Overview` — test framework, coverage, major gaps.
- `## Maintenance Checklist` — when the spec must be updated.

## Base Rules

- Write exactly one sentence per line.
  (Why: per-line facts are easy to diff, quote, and selectively update across future sessions.)
- Keep the file under 300 lines.
  (Why: `project-spec.md` loads into agent context on every task; every line competes with task-specific content.)
- State present-tense facts drawn from the codebase, not planned or aspirational behaviour.
  (Why: a spec that describes intent diverges quickly and misleads agents into planning against code that does not exist.)
- Mark a fact as unknown instead of guessing.
- Keep module, path, and entity names identical to the codebase.
- Omit rationale unless it is required for correctness.
- Do not duplicate the same fact across sections.

## Scanning the Codebase

Do a systematic pass before writing — fill each section from the scan, not from issues, prior specs, or human descriptions.

1. **Root.** Read `README.md` and every build or package manifest (`package.json`, `pyproject.toml`, `go.mod`, or equivalent); record why each direct dependency exists. → Product Summary, Key Dependencies.
2. **Entry points.** Locate the runtime entry points (`main.*`, `index.*`, `cli.*`, framework route files); from each, trace the top-level wiring and list user-visible routes, commands, or public API. Ignore internal helpers. → Scope, Architecture Summary.
3. **Data.** Find schema, migration, and model files; note recurring nouns in module names. → Domain Concepts.
4. **Constraints.** Find environment-variable validation, feature flags, CI policy scripts, git hooks, and any product-visible enforced limits. → Important Constraints.
5. **Structure.** Walk the directory tree; for each top-level path, record what it owns in one bullet. → Project Structure.
6. **Tests.** Locate the test runner(s), read the canonical test command in CI config (`.github/workflows/`, `.circleci/`, `.gitlab-ci.yml`), note uncovered areas. → Testing Overview.

For large codebases, skim at the directory level first and only open files that are surfaced by the scan; do not try to read every file.

## Updating an Existing Spec

- Rerun the scan above, then compare it to the current file fact by fact.
- For each line in the spec, find the codebase source that should confirm it; remove lines whose source no longer exists.
- For each source the scan surfaces, check whether the spec already records it; add missing facts.
- Remove lines that no longer match the codebase rather than appending corrections.
  (Why: stale lines next to corrections leave the agent with two conflicting facts.)
- Merge overlapping bullets when they describe the same fact.
- If the file approaches 300 lines, drop low-value detail before adding new content.
- Do not turn the spec into a changelog; recent history belongs in git.

## What Not to Include

- Planned features, future refactors, open questions, issue or PR references.
- Multi-sentence bullets or prose paragraphs.
- Workflow or process documentation — the spec records implementation facts, not how the team works.

## Before Handing Off

- File is under 300 lines.
- Every line is a single sentence.
- Each section's facts are verifiable against the current codebase.
