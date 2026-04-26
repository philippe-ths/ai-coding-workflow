---
name: aiw-planning
description: "Structured planning process for producing a code-aware implementation plan before writing code. Use this skill when the agent needs to plan an implementation approach: identifying what files to touch, what assumptions to verify, what risks exist, and how to validate the change. The skill exists to prevent the agent from jumping straight into coding without thinking through scope, assumptions, and consequences."
---

# Code-Aware Planning

Read this file when producing or revising a code-aware plan.
This file contains the full requirements for a valid plan and for handling human feedback at review.

## Related Workflow Sections

This skill works alongside these workflow sections. Consult them when building the plan:

- **Scope Control**: plans must respect scope boundaries; flag multi-area changes or unrelated objectives.
- **Validation Requirements**: plans must account for how the change will be validated, including baseline comparison.

## What the Plan Must Contain

- State the branch the work will be implemented on.
- State the goal of the change in one or two sentences.
- State the user-visible behaviour that must change.
- State the files and code areas the change will touch.
- State the proposed implementation approach.
- State any assumptions the plan depends on.
- Separate issue assumptions from codebase-confirmed assumptions.
- State how each critical assumption will be verified.
- State any remaining uncertainties or ambiguities.
- State the risks and edge cases.
- Mark the change as higher-risk if it affects routing, persistence, sync, caching, reactive subscriptions, or state transitions.
- Include at least one runtime validation step for higher-risk changes.
- State the validation approach.
- State any logging or observability changes needed.

## How to Treat Issue Content vs. Codebase Reality

- Treat the issue goal as authoritative.
- Treat issue-suggested implementation details as provisional until the current codebase confirms them. (Why: Issues are written before implementation and may not reflect the current codebase.)
- Do not assume the files, data flow, or control points named in the issue are the real execution path.
- If the issue and the current codebase disagree, prioritise the codebase and flag the mismatch to the human.
- If the issue suggests a structure that the current codebase does not follow, plan against the real structure and flag the mismatch to the human.

## Assumption Classification

Classify every assumption the plan depends on as one of:

- **Issue-sourced.** The assumption comes from the issue text and has not yet been verified against the codebase.
- **Codebase-confirmed.** The assumption has been verified by reading the codebase.

State how each issue-sourced assumption will be verified before or during implementation.
If a codebase-confirmed assumption turns out to be wrong during implementation, stop and revise the plan.

## Handling Risk and Uncertainty

- State any remaining uncertainties or ambiguities before implementation begins.
- Mark the change as higher-risk if it affects routing, persistence, sync, caching, reactive subscriptions, or state transitions.
- Include at least one runtime validation step for higher-risk changes.
- If the risk level cannot be determined from the codebase alone, state this and flag it to the human.

## Keeping the Plan Concise

- Keep the plan concise.
- Do not include implementation detail that belongs in the code.
- Do not restate the issue verbatim.
- One sentence per item where possible.

## Handling Human Feedback at Plan Review

- If the human partially approves, update only the unapproved parts and present the revised plan.
- If the human adds new requirements, assess whether they change the scope and flag if they do.
- If the human's feedback contradicts the issue, flag the contradiction.
- After updating the plan, present the revised plan for re-approval before proceeding.
