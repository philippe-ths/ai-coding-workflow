---
name: aiw-issue-creation
description: "Structured process for creating follow-up or spin-off GitHub issues during a task. Use this skill when the agent discovers work outside the current scope that should be tracked. The skill exists to prevent implementation-heavy issues that bias the implementing agent and peg to stale code."
---

# Issue Creation

Read this file when creating a follow-up or spin-off GitHub issue.

## Before Creating the Issue

- Search open issues in the repository for overlap with the proposed issue's intent.
- If a potential overlap is found, surface the overlapping issue to the human before proceeding.
- Only proceed with creation after the human confirms there is no duplicate.

## What the Issue Must Contain

- State what needs to change from the user's perspective.
- State why the change is needed and what triggered the discovery.
- State acceptance criteria if they are clear.

## What the Issue Must Not Contain

- Do not include file paths, code snippets, or implementation approaches.
- Do not reference specific functions, variables, or line numbers.
- Do not prescribe how the implementing agent should solve the problem.
  (Why: Implementation details peg to the current codebase state and bias the implementing agent toward an approach that may not match the codebase when the issue is picked up.)

## Keeping Issues Concise

- Keep the issue short.
- State intent, not process.
- One issue per concern.
