# Project Context Design Decisions

This document defines maintenance rules for `project-context.md` files.
It is for humans who maintain project context files.
Use these rules when creating or editing a project context file.

## Core Purpose

The project context records current implementation truth.
The project context is a factual reference, not a roadmap.
The project context should help an AI agent orient quickly before planning changes.

## Base Rules

Every line must contain exactly one sentence.
Keep the file short and under 300 lines.
Keep each sentence concrete and specific.
Prefer present-tense facts over future intentions.
Avoid rationale unless it is required for correctness.
Do not duplicate the same rule or fact in multiple sections.
If a fact is uncertain, mark it as unknown instead of guessing.

## Section Shape

Use stable sections so agents can parse the file quickly.
Include Product Summary, Domain Concepts, Scope, Important Constraints, Architecture Summary, Key Dependencies, Project Structure, and Testing Overview.
Remove empty sections only when the project has no reliable information for that section.
Use one bullet per fact in list sections.

## Content Quality

Prefer codebase-confirmed facts over issue or ticket suggestions.
If issue text conflicts with the codebase, document the codebase truth and note the mismatch.
State constraints as enforceable facts, not advice.
Keep names aligned with real module, path, and entity names.
Update outdated terms when the codebase is renamed or refactored.

## Maintenance

Update the context file when routes, schema, sync rules, persistence, or provider behavior changes.
Update the context file when build, runtime, or dependency boundaries change.
During reviews, remove stale lines instead of accumulating historical notes.
Do not let this file exceed 300 lines.
If the file approaches 300 lines, merge overlapping facts and remove low-value detail.
