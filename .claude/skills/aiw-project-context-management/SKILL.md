---
name: aiw-project-context-management
description: "Process for creating and updating `project-context.md`, the short record of what an agent would get wrong in a repository without being told. Use before any edit to that file, even a single fact, and when the human asks to create, scaffold, refresh, trim, or correct the project context, as in 'update the context' or 'the context file is too long'. Use it also when the branch changed a rule the repository enforces, a contract, what validation covers, or how it builds; older drift is a finding, not an inline refresh."
---

# Project Context Management

Read this file before creating or editing `project-context.md`.
`project-context.md` loads into every agent session, so it holds the repository's requirements and not a map of it.

## The Keep Test

A line belongs in the file only when both of these hold:

- An agent that did not know it would do something wrong: break a rule, skip a required step, run the wrong command, misread a term.
- The agent cannot learn it from the code in one step: a directory listing, a file's header, a manifest.

(Why: an overview of the code does not help an agent find the files a task needs, and every line it reads is one more thing it tries to satisfy, so a map costs steps as well as tokens.)

"`src/routes/`: the HTTP handlers" fails: `ls src/routes` and one header give it.
"Every migration must be registered in `migrations/index.ts`, and the build fails until it is" passes: an agent learns it only by breaking it.
The hard case is a line that names a path and carries a rule: "`.githooks/` holds the git hooks" fails, while "commits and pushes run validation through `.githooks/`, so `core.hooksPath` must point there" passes, because the rule is the requirement and the path is only where it lives.

## Sections

Use these sections, in order; omit one when nothing in the repository passes the keep test for it.

- `## Product Summary`: what the product is and who uses it, in two or three lines.
- `## Constraints`: each enforced rule, and what enforces it.
- `## Build and Validate`: the commands to build, run, and validate, the tools they need, and what validation does not cover.
- `## Domain Terms`: only terms an agent would misread from their name or from the code.
- `## Maintenance`: when the file must change.

Do not add a section listing paths, modules, dependencies, or architecture layers; the agent reads those from the tree when a task needs them.

## Base Rules

- Write exactly one sentence per line, and give a new fact its own line rather than extending a line that already exists.
  (Why: a fact fused onto an existing line is invisible in review, and it escapes any limit counted in lines, so the file can triple in weight while its line count barely moves.)
- Treat the file as full: hold it under 2000 tokens, and once it is at the limit, adding a fact means choosing which line leaves.
  (Why: every line costs tokens in every session, whether that session's task needs it or not. Most repositories need far less than the limit.)
- When choosing which line leaves, drop the line a reader is least likely to act on, not the line least related to the change you are making.
  (Why: relatedness is not value, and trading a load-bearing fact for a detail is worse than the crowding it relieved.)
- Where the repository can enforce that budget the way it enforces anything else, enforce it there.
  (Why: a limit nothing measures is a suggestion, and it is the first thing to go when a feature needs one more line.)
- State present-tense facts drawn from the codebase, not planned or aspirational behaviour.
  (Why: a context file that describes intent diverges quickly and misleads agents into planning against code that does not exist.)
- Mark a fact as unknown instead of guessing.
- Keep module, path, and entity names identical to the codebase.
- Omit rationale unless it is required for correctness.
- Do not duplicate a fact across sections, or one that an agent instruction file or skill already states; an enforced rule still gets one line here saying what blocks it, because the instruction file says what to do and not what will stop you.
- Exclude issue or PR references and how the team works by habit; a step the repository enforces or its build requires is a requirement and belongs.

## Scanning the Codebase

Look for requirements, not structure. Fill each section from the scan, not from issues, prior context files, or human descriptions.

1. **Enforcement.** Find git hooks, CI policy steps, agent hooks, linters configured to fail, environment-variable validation, and protected branches; record the rule each enforces. Feeds Constraints.
2. **Contracts.** Find what must not change silently: schema and migration rules, public interfaces, generated files not to edit by hand, required environment variables. Feeds Constraints.
3. **Build and validation.** Read the setup section of `README.md`, the scripts in each build or package manifest, and the canonical commands in CI config (`.github/workflows/`, `.circleci/`, `.gitlab-ci.yml`); record the commands, the tools they need that an agent would not assume, and what the tests leave uncovered. Feeds Build and Validate.
4. **Terms.** Note nouns in module and schema names whose meaning here differs from ordinary use. Feeds Domain Terms.
5. **Summary.** Take what the product is and who uses it from the top of `README.md`. Feeds Product Summary.

For large codebases, skim at the directory level first and only open files that are surfaced by the scan; do not try to read every file.

## Updating an Existing Context File

Most edits add one fact from work just finished.
Add a new line for the fact, and if the file is at its limit, name the line that leaves.
Do not extend a neighbouring line to carry it.

Worked example: a change adds a pre-push check that rejects a version bump without a changelog entry, and the file already says pushes run validation.
The tempting edit extends that line, because the new rule belongs with it.
Extend it and the diff reads as one line changed, the line count does not move, and no limit notices.
Give the rule its own line instead, and drop a line that has stopped earning its place if the file is full.

A full refresh is the rarer case:

- Rerun the scan above, then compare it to the current file fact by fact.
- Put every existing line through the keep test, and remove the lines that fail it, correct ones included. A file written as an overview is mostly map; rewrite it to the sections above rather than trimming at its edges.
- For each remaining line, find the codebase source that should confirm it; remove lines whose source no longer exists.
- For each requirement the scan surfaces, check whether the file already records it; add missing ones.
- Remove lines that no longer match the codebase rather than appending corrections.
  (Why: stale lines next to corrections leave the agent with two conflicting facts.)
- Merge overlapping lines when they state the same fact.
- Do not turn the context file into a changelog; recent history belongs in git.

## Before Handing Off

Read the diff, not just the file: if a line got longer instead of a line getting added, the fact was fused and the budget did not notice.
Put each added line through the keep test once more.
