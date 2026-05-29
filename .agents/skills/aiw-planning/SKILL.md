---
name: aiw-planning
description: "Structured planning process for producing a code-aware implementation plan before writing code, including the pre-planning codebase baseline checks (smoke tests and the global suite, test readiness, bounded-change confirmation) and the task modality classification the rest of the plan depends on. Use this skill at the start of every task before any implementation, whether the user says 'plan' or just hands the agent an issue. It owns the codebase baseline check, the modality classification step (procedure in aiw-ground-truth), the plan's structure and required content, the oracle and verification expectations the plan must state, the issue-vs-codebase priority rule, assumption classification, bounded-change confirmation, and handling human feedback at plan review. It does not own oracle definitions or the trust hierarchy (aiw-ground-truth), test mechanics (aiw-testing), evidence and sufficiency (aiw-verification), or post-failure investigation (aiw-failure-analysis)."
---

# Planning

Read this file when producing or revising an implementation plan at the start of a task.

## Where This Skill Sits in the Workflow

Planning runs at the start of every task, before any implementation. It establishes what currently works in the codebase, classifies the task, names the oracle, and produces an implementation plan with high-level testing and verification expectations.

The plan does not reproduce the rules of the other four skills. It identifies what each skill will need to address during implementation and defers the mechanics to them. The plan is the entry point; aiw-ground-truth, aiw-testing, and aiw-verification are invoked as the work proceeds. If a "done" claim is later contradicted, aiw-failure-analysis runs and may re-plan.

## The Full Skill Sequence

For orientation, the skills are invoked across a task in roughly this order:

1. **aiw-github** at task start: confirm the GitHub issue, read it and its comments, create or switch to an issue-scoped branch.
2. **aiw-planning** (this skill): establish the codebase baseline, classify the modality, name the oracle, produce the plan for human review.
3. **Implementation.** As work proceeds, aiw-ground-truth governs fixtures and oracles, aiw-testing governs test mechanics, aiw-verification governs the evidence required to declare done.
4. **aiw-verification's justification step** before any "done" claim.
5. **aiw-github** again for commit, push, and pull request, each as a separate human-approved action.
6. **aiw-failure-analysis** if a "done" claim is later contradicted; it audits, may surface a plan-level flaw, and may restart the sequence from re-planning.

This skill owns step 2. The overview exists so the full sequence is visible at a glance; the other skills own their own territory and their own rules.

## Establish Codebase Baseline

Before drafting the plan, establish what the codebase currently does, what the test infrastructure tells you, and what is actually being asked. The plan depends on these facts.

### Read project context

- If `project-context.md` exists in the repository, read it as part of the baseline check.
- If `project-context.md` is stale, flag it to the human. Refreshing project context is its own task per aiw-project-context-management; do not refresh it inline as part of the current task.
- If `project-context.md` does not exist and the codebase is non-trivial, flag this and ask whether to scaffold one before proceeding.

### Run baseline validation

- Run smoke tests and the global test suite as they exist now.
- Record which tests pass and which tests fail.
- Treat pre-existing failures as known for the task's duration.
- Do not fix pre-existing failures unless the task requires it.

### Check test readiness

- Check whether the project has smoke tests that confirm the app builds and starts.
- Check whether the project has a test suite with at least one passing test.
- Check whether tests exist for the code area the task is likely to touch.
- If any of these are missing, flag the gap to the human before proceeding.
- Do not write tests to fill the gap unless the human approves.
- Skip this check if the task is specifically about writing tests.

### Confirm the task is a bounded change

- If the issue contains multiple unrelated objectives, flag this and ask the human whether to split them into separate tasks.
- If the task would require changes across many unrelated areas of the codebase, flag the risk and suggest decomposition.

If the baseline, test readiness, or task scope is unclear after these checks, stop and resolve before drafting the plan.

## Classify the Task's Modality

After the baseline is established and before the plan is drafted, run the modality decision procedure defined in aiw-ground-truth. Record the classification — one or more modalities — in the plan.

Modality is the most consequential decision in planning. It determines:

- What counts as the oracle for this task (aiw-ground-truth).
- What testing emphasis the implementation will need (aiw-testing).
- What evidence will be required to declare done (aiw-verification).

A refactor plan does not look like a feature plan; a fix plan does not look like a migrate plan. Making modality explicit forces the rest of the plan to be honest about which set of constraints applies. Do not skip this step because the task seems obvious — the most common failure is classifying a fix as a feature, a migrate as a refactor, or a delete as trivial. (See aiw-ground-truth for the common misclassifications.)

For compound tasks (e.g., "fix by adding a feature", "refactor while migrating"), record every modality that applies. The downstream sections of the plan apply the union of constraints, with the stricter rule winning where they conflict.

## What the Plan Must Contain

The plan the agent produces for the user should have these elements:

- **Branch.** The branch the work will be implemented on.
- **Goal.** The goal of the change in one or two sentences.
- **User-visible behaviour.** What must change from the user's perspective.
- **Modality classification.** The modality (or modalities) recorded above.
- **Oracle.** What counts as correct for this task and where it comes from. (See "The Oracle Section" below.)
- **Files and code areas.** What the change will touch.
- **Implementation approach.** The proposed approach, at the level of what will be done, not how every line is written.
- **Assumptions.** Separated into issue-sourced and codebase-confirmed. (See "Assumption Classification" below.)
- **Assumption verification.** How each issue-sourced assumption will be verified before or during implementation.
- **Risks and edge cases.** Including any higher-risk flag. (See "Higher-Risk Flags" below.)
- **Verification approach.** What evidence will be required to declare done. (See "Verification Approach in the Plan" below.)
- **Testing notes.** What test infrastructure exists, what gaps exist, what will be needed. (See "Testing Notes in the Plan" below.)
- **Remaining uncertainties.** What is still ambiguous before implementation begins.

## The Oracle Section

The plan must state what will be treated as the correct answer for this task, at what trust level, and from what source. Reference the trust hierarchy in aiw-ground-truth — do not reproduce it.

The oracle depends on the modality (aiw-ground-truth defines this per modality). Some examples:

- For a refactor, the oracle is the captured behaviour of the current code.
- For a fix, the oracle is the bug report plus characterisation of everything else.
- For a migrate, the oracle is the previous behaviour on real inputs, with an explicit exception list.
- For configure, the oracle is the real external system, not a mock.

If the modality requires a trust level higher than what is currently available, flag it at planning time. Apply aiw-ground-truth's sourcing protocol — stop and ask the user, do not invent a substitute. Discovering at implementation time that the required oracle was never available is more expensive than naming the gap now.

## How to Treat Issue Content vs Codebase Reality

- Treat the issue goal as authoritative.
- Treat issue-suggested implementation details as provisional until the current codebase confirms them. (Why: issues are written before implementation and may not reflect the current codebase.)
- Do not assume the files, data flow, or control points named in the issue are the real execution path.
- If the issue and the current codebase disagree, prioritise the codebase and flag the mismatch to the human.
- If the issue suggests a structure the current codebase does not follow, plan against the real structure and flag the mismatch to the human.

## Assumption Classification

Classify every assumption the plan depends on as one of:

- **Issue-sourced.** The assumption comes from the issue text and has not yet been verified against the codebase.
- **Codebase-confirmed.** The assumption has been verified by reading the codebase.

State how each issue-sourced assumption will be verified before or during implementation.

A codebase-confirmed assumption is not permanently safe. The codebase can be read incorrectly, behaviour at runtime can differ from what static reading suggests, and an assumption that held in one place may not hold in another. If a codebase-confirmed assumption turns out to be wrong during implementation, stop and revise the plan. If a contradicted "done" claim later traces back to a codebase-confirmed assumption that was wrong, that is the territory of aiw-failure-analysis.

## Higher-Risk Flags

Mark the change as higher-risk if it:

- Crosses real seams between components (process boundaries, service boundaries, module boundaries with persistent state).
- Touches external systems or third-party integrations.
- Modifies data flow between processes or pipeline stages.
- Affects state that other parts of the system depend on.
- Falls in any modality that aiw-verification requires end-to-end execution for (data flowing between processes, pipeline stage changes, external interfaces, refactor or migrate claiming behaviour preservation, delete).

Project-specific failure modes — routing changes, sync overwrites, caching, reactive subscriptions, state transitions, persistence layers — fit under these categories rather than living as a separate list in a project-agnostic skill. Use them as examples where they apply to the project, not as the rule itself.

For higher-risk changes, the plan must:

- Include at least one runtime validation step in the verification approach.
- Name the specific surface that makes the change risky, so the human can challenge the framing if needed.

If the risk level cannot be determined from the codebase alone, state this and flag it to the human.

## Verification Approach in the Plan

State what evidence will be required to declare done, at a high level. The evidence hierarchy and the sufficiency rules live in aiw-verification — do not reproduce them. The plan names what the verification will look like, not how it will be performed.

What "high level" means in practice:

- "End-to-end run on real input required" rather than enumerating each end-to-end check.
- "Characterisation comparison before and after" rather than listing each test to run.
- "Real external system exercised at least once" for configure modality.
- "Dependency search across the codebase, including dynamic references" for delete modality.
- "Failing test that reproduces the bug, then passing after the fix" for fix modality.

Reference aiw-verification for the modality-specific verification requirements that apply. The implementation will run through aiw-verification's full process at done time; the plan's job is to surface the expectation now so it is not a surprise then.

## Testing Notes in the Plan

The testing notes section is a report on infrastructure and gaps, not a plan of tests. aiw-testing handles what tests will be written during implementation.

State:

- What test infrastructure currently exists for the code area.
- What gaps exist (no smoke tests in this area, no tests for this module, no end-to-end harness for this pipeline).
- What test type the modality will require (characterisation, regression, end-to-end on real input, etc.) at the same high level as the verification approach.
- Whether the existing test suite is likely to fail when the code is broken, or whether it is structurally insufficient to catch the kind of change being proposed.

Do not enumerate specific tests in the plan. aiw-testing will make those calls during implementation. The plan flags gaps; aiw-testing fills them.

## Keeping the Plan Concise

- Keep the plan concise.
- Do not include implementation detail that belongs in the code.
- Do not restate the issue verbatim.
- One sentence per item where possible.
- The plan is a structured handoff to implementation, not a substitute for it.

## Handling Human Feedback at Plan Review

- If the human partially approves, update only the unapproved parts and present the revised plan.
- If the human adds new requirements, assess whether they change the scope and flag if they do.
- If the human's feedback contradicts the issue, flag the contradiction.
- After updating the plan, present the revised plan for re-approval before proceeding.

## Anti-Patterns

- **Skipping modality classification because the task seems obvious.** It usually is not. Common misclassifications (fix as feature, migrate as refactor, delete as trivial) are exactly the cases that look obvious until the oracle question surfaces them.
- **Treating the issue as authoritative on implementation details.** The issue is authoritative on intent. Implementation details in the issue are provisional and must be verified against the codebase.
- **Producing a plan without naming the oracle.** Refactor and migrate plans are especially vulnerable: the oracle (captured previous behaviour, previous behaviour on real inputs with an exception list) is the most important question for those modalities, and silence about it is a planning failure.
- **Reproducing rules from aiw-testing or aiw-verification.** The plan references them at the level of expectation. Mechanics belong in the implementation phase and in the skills that own them.
- **Jumping to implementation after baseline checks without producing the actual plan.** The baseline is preparatory; the plan is the artifact the human reviews. Skipping the plan removes the review checkpoint.
- **Treating codebase-confirmed assumptions as permanently safe.** They can still turn out to be wrong, which is when aiw-failure-analysis triggers and the plan may need to be re-opened.
