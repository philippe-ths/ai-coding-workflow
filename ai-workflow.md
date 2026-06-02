# AI Workflow

Version: 3.3.0

This file defines the rules and processes for AI-assisted coding on this project.
It is written for the AI coding agent.

## First Principles

- The codebase is the truth about what the system does.
- The spec is the truth about what the system should do.
- Runtime behaviour is the final truth about what actually happens.
- Documentation, plans, project context, and comments derive from the codebase and the spec; they may drift from either and are not authoritative on their own.
- When code, spec, and runtime conflict, reconcile — none wins by default.

## Task Flow

The skill set enforces disciplines invoked at specific points in a task.

1. **Task start:** aiw-github (issue, branch).
2. **Planning:** aiw-planning (baseline, modality, oracle, plan).
3. **Implementation:** aiw-ground-truth and aiw-testing invoked as work proceeds.
4. **Verification gate:** aiw-verification justification step before presenting work for human review.
5. **GitHub actions:** aiw-github for commit, push, PR.
6. **Reactive:** aiw-failure-analysis if a "done" claim is contradicted.

Conditional skills (aiw-performance-profiling, aiw-security-testing) load alongside the above when their triggers apply — see Non-Functional Dimensions.

`project-context.md`, if it exists, is read at task start. If stale, flag it. If absent in a non-trivial codebase, flag and ask whether to scaffold. aiw-project-context-management owns it.

## Non-Functional Dimensions

Two skills load conditionally when their triggers apply, alongside the Task Flow core skills:

- aiw-performance-profiling for changes affecting speed or responsiveness.
- aiw-security-testing for changes crossing trust boundaries or handling untrusted input.

When these dimensions apply, attempt automated coverage before falling back to manual verification.

## Boundary Rules

### Always Do

The AI must raise these without being asked, so the human has the information needed to make decisions. Surface only what was encountered while doing the task, with concrete evidence. Default to the handoff summary; raise mid-task only when the observation changes what the AI should do next.

- ALWAYS run aiw-verification's justification step before presenting work for the human's done decision.
- ALWAYS surface uncertainty, guesses, and incomplete validation, and stop to ask when anything is unclear, risky, or out of scope.
- ALWAYS surface follow-up work discovered during the task that falls outside scope, without acting on it.
- ALWAYS surface performance concerns observed in the code paths the task touched, with the concrete signal that prompted them.
- ALWAYS surface security concerns observed in the code paths the task touched, with the concrete signal that prompted them.
- ALWAYS surface refactoring opportunities directly relevant to the task code, without acting on them.
- ALWAYS surface notable entries from logs consulted during the task: errors, warnings, and unexpected patterns.

### Ask First

Stop and ask the human before doing any of the following:

- ASK before adding a new dependency.
- ASK before changing architecture, patterns, or conventions documented in project context.
- ASK before changing database schema, sync behaviour, public interfaces, or shared contracts.
- ASK before refactoring code that is not required by the task.
- ASK before deleting any file, function, class, or module.
- ASK before weakening, skipping, or removing tests.

### Never Do

Do not do any of the following under any circumstances:

- NEVER invent requirements not present in the task or project context.
- NEVER silently expand scope or introduce unrelated changes.
- NEVER claim the issue is nearly complete while the root cause is still unknown.
- NEVER hardcode sensitive values.
- NEVER bypass deterministic policy checks or treat them as optional.

## Reactive Rules

If a "done" claim is contradicted, stop. Invoke aiw-failure-analysis. Do not propose another fix or request a retry until the audit has run.

This rule overrides the rest of the workflow when triggered.

## The Human is Responsible For

The AI cannot perform these tasks.
The human must complete them.

- Make judgements that depend on lived human experience: visual quality, UX flow, real-device behaviour, subjective response.
- Provide first-hand reports of runtime behaviour. These reports are evidence the AI cannot dismiss.
- Authorise actions that affect systems or people beyond the local working tree: pushing to remote, deploying, opening or commenting on PRs, posting to external services, modifying CI.
- Approve destructive or hard-to-reverse local actions: `git reset --hard`, force-push, deleting working-tree state, dropping schema, removing or downgrading dependencies.
- Merge pull requests.
- Interrupt the AI when it is chasing the wrong root cause, looping on failed approaches, or about to take an action that conflicts with intent.
- Decide when the work is complete.
