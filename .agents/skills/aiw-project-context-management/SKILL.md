---
name: aiw-project-context-management
description: "Structured process for initializing and updating `project-context.md`, a repository's factual reference of current implementation truth. Use this skill before any edit to that file, including adding a single fact from work just completed, and when the human asks to create, scaffold, refresh, or correct the project context, with phrasings like 'update the context', 'the architecture summary is out of date', 'document the project structure', or 'the project-context.md is stale'. Also use it when the agent notices the file has drifted from the codebase after changes to routes, schema, sync rules, dependencies, project structure, or test coverage. The skill exists to prevent context files from drifting into planned architecture, roadmap language, or multi-sentence lines that degrade agent parsing in future sessions."
---

# Project Context Management

Read this file before creating or editing `project-context.md`.
`project-context.md` is a repository's factual reference of current implementation truth; agents consult it to orient quickly before planning changes.

## Required Sections

Use these sections, in order; omit one only when the repository has no reliable information for it.

- `## Product Summary`: what the product is, who uses it, the core user flow.
- `## Domain Concepts`: the main entities and their relationships.
- `## Scope`: what the product currently supports, major workflows, known non-goals.
- `## Important Constraints`: hard product, technical, policy, data, or environment constraints.
- `## Architecture Summary`: architecture style, runtime layers, primary data flow, external boundaries.
- `## Key Dependencies`: each dependency and why it exists.
- `## Project Structure`: each significant path or module and what it owns.
- `## Testing Overview`: test framework, coverage, major gaps.
- `## Maintenance Checklist`: when the context file must be updated.

## Base Rules

- Write exactly one sentence per line, and give a new fact its own line rather than extending a line that already exists.
  (Why: a fact fused onto an existing line is invisible in review, and it escapes any limit counted in lines, so the file can triple in weight while its line count barely moves.)
- Treat the file as full: hold it near 300 lines, and once it is at the limit, adding a fact means choosing which line leaves.
  (Why: `project-context.md` loads into agent context on every task; every line competes with task-specific content.)
- When choosing which line leaves, drop the line a reader is least likely to act on, not the line least related to the change you are making.
  (Why: relatedness is not value, and trading a load-bearing fact for a detail is worse than the crowding it relieved.)
- Where the repository can enforce that budget the way it enforces anything else, enforce it there.
  (Why: a limit nothing measures is a suggestion, and it is the first thing to go when a feature needs one more line.)
- State present-tense facts drawn from the codebase, not planned or aspirational behaviour.
  (Why: a context file that describes intent diverges quickly and misleads agents into planning against code that does not exist.)
- Mark a fact as unknown instead of guessing.
- Keep module, path, and entity names identical to the codebase.
- Omit rationale unless it is required for correctness.
- Do not duplicate the same fact across sections.
- Record implementation facts only; exclude issue or PR references and workflow or process documentation (how the team works, not what the code does).

## Scanning the Codebase

Do a systematic pass before writing. Fill each section from the scan, not from issues, prior context files, or human descriptions.

1. **Root.** Read `README.md` and every build or package manifest (`package.json`, `pyproject.toml`, `go.mod`, or equivalent); record why each direct dependency exists. Feeds Product Summary and Key Dependencies.
2. **Entry points.** Locate the runtime entry points (`main.*`, `index.*`, `cli.*`, framework route files); from each, trace the top-level wiring and list user-visible routes, commands, or public API. Ignore internal helpers. Feeds Scope and Architecture Summary.
3. **Data.** Find schema, migration, and model files; note recurring nouns in module names. Feeds Domain Concepts.
4. **Constraints.** Find environment-variable validation, feature flags, CI policy scripts, git hooks, and any product-visible enforced limits. Feeds Important Constraints.
5. **Structure.** Walk the directory tree; for each top-level path, record what it owns in one bullet. Feeds Project Structure.
6. **Tests.** Locate the test runner(s), read the canonical test command in CI config (`.github/workflows/`, `.circleci/`, `.gitlab-ci.yml`), note uncovered areas. Feeds Testing Overview.

For large codebases, skim at the directory level first and only open files that are surfaced by the scan; do not try to read every file.

## Updating an Existing Context File

Most edits add one fact from work just finished.
Add a new line for the fact, and if the file is at its limit, name the line that leaves.
Do not extend a neighbouring line to carry it.

Worked example: a change adds a `superseded_at` column to a model the file already describes.
The tempting edit extends that model's line, because the new fact belongs with it.
Extend it and the diff reads as one line changed, the line count does not move, and no limit notices.
Give the column its own line instead, and drop a line that has stopped earning its place if the file is full.

A full refresh is the rarer case:

- Rerun the scan above, then compare it to the current file fact by fact.
- For each line in the context file, find the codebase source that should confirm it; remove lines whose source no longer exists.
- For each source the scan surfaces, check whether the context file already records it; add missing facts.
- Remove lines that no longer match the codebase rather than appending corrections.
  (Why: stale lines next to corrections leave the agent with two conflicting facts.)
- Merge overlapping bullets when they describe the same fact.
- Do not turn the context file into a changelog; recent history belongs in git.

## Before Handing Off

Read the diff, not just the file: if a line got longer instead of a line getting added, the fact was fused and the budget did not notice.
