# AI Workflow

Version: 3.34.0

This file defines the rules and processes for AI-assisted coding on this project.
It is written for the AI coding agent.

## First Principles

- The codebase is the truth about what the system does.
- The spec is the truth about what the system should do.
- The north-star is the truth about what the project is trying to achieve.
- Runtime behaviour is the final truth about what actually happens.
- Documentation, plans, project context, and comments derive from the codebase and the spec; they may drift from either and are not authoritative on their own.
- When code, spec, north-star, and runtime conflict, reconcile — none wins by default.

## Task Flow

The skill set enforces disciplines invoked at specific points in a task.

1. **Request arrival:** check the request against `north-star.md`; aiw-north-star if it pulls against the goal.
2. **Task start:** aiw-github (issue, branch).
3. **Planning:** aiw-planning (baseline, modality, oracle, plan, execution shape), agreed with the human before implementation begins.
4. **Implementation:** aiw-ground-truth and aiw-testing invoked as work proceeds. From here the work runs without step-by-step authorisation; the human interrupts rather than approves each step.
5. **Verification gate:** aiw-verification justification step before presenting work for human review.
6. **GitHub actions:** aiw-github for commit, push, PR.
7. **Reactive:** aiw-failure-analysis if a "done" claim is contradicted.

Conditional skills load alongside the above when their triggers apply: aiw-performance-profiling and aiw-security-testing (see Non-Functional Dimensions), and aiw-orchestration on the trigger stated in Resource Discipline.

`north-star.md`, if it exists, is the shortest statement of what the project is trying to achieve. Consult it when deciding how and why. A request that pulls the project away from that goal stops before planning, because either the request is wrong or the goal has moved, and the human decides which. If absent in a non-trivial codebase, flag and ask whether to scaffold. aiw-north-star owns it.

`project-context.md`, if it exists, is read at task start. If stale, flag it. If absent in a non-trivial codebase, flag and ask whether to scaffold. aiw-project-context-management owns it.

Before a task is chosen, the human may invoke aiw-init. It runs the repository's declared checks read-only and reports state the human may not be aware of; it starts no work and proposes no fixes. `project-checks.md` records what this repository checks and what normal looks like for each. aiw-init owns it.

## Non-Functional Dimensions

Two of the conditional skills cover the non-functional dimensions, and load when their triggers apply alongside the Task Flow core skills:

- aiw-performance-profiling for changes affecting speed or responsiveness.
- aiw-security-testing for changes crossing trust boundaries or handling untrusted input.

When these dimensions apply, attempt automated coverage before falling back to manual verification.

## Resource Discipline

Protect your context window and the human's quota — but never by doing less than the task requires.

- Efficiency governs *how* you discharge a required step, never *whether*. Never skip, weaken, or defer a required step to save context or quota.
- Read and search narrowly; pull whole files or broad output dumps into context only when you need them.
- Route reconnaissance out freely: broad multi-file search, and any output you would only distil. It writes nothing, so it needs no permission.
- Everything that writes is aiw-orchestration's call. Load it when the work looks like it might split — many files or areas, more input than you can hold at once, or any impulse to hand implementation to another agent — and before handing writing work to any agent other than yourself. Load it to decide whether to split, not once you have decided. The conditions live there, and this file does not restate them, because one rule kept in several places is several copies of the same defect.
- Keep judgment, design, and the review of every returned result in the main loop. A sub-agent's result is evidence to weigh, never a verdict to accept unread. A thin brief returns confident, wrong work, and an orchestrator that defers inherits the error.

## Boundary Rules

### Always Do

The AI must raise these without being asked, so the human has the information needed to make decisions. Surface only what was encountered while doing the task, with concrete evidence. Default to the handoff summary; raise mid-task only when the observation changes what the AI should do next.

- ALWAYS run aiw-verification's justification step before presenting work for the human's done decision, and give every unverified surface it names a resolution the human can see: checked, tracked by an issue, deferred with its method named, or waived by the human. Opening a pull request is not that decision, since the human makes it afterwards, so the pull request is where the justification is presented and where deferred evidence lands before they decide.
- ALWAYS treat non-convergence as evidence rather than a cue to try another variation. When successive attempts repair one surface while reopening another, or repeat an approach without new evidence, stop implementation and invoke aiw-failure-analysis, which reassesses the task framing, oracle, plan, and code structure before anything else changes.
- ALWAYS surface uncertainty, guesses, and incomplete validation. Where a reading is uncertain, take the one a careful colleague would, name it, and carry on; stop and wait only when no reading is safe to act on, when a wrong one would mean redoing the work rather than adjusting it, or when the question is one the Ask First list reserves for the human. A question the north-star settles does not warrant stopping.
- ALWAYS present any question or decision you put to the human in the Asking for Guidance format — lead with a clear recommendation and its rationale, never a bare list of options for the human to sort out.
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
- ASK before accepting verification evidence weaker than the plan committed to. If the committed method cannot run, that is a decision about what the done claim is worth, and it is the human's to make.

### Never Do

Do not do any of the following under any circumstances:

- NEVER invent requirements not present in the task or project context.
- NEVER silently expand scope or introduce unrelated changes.
- NEVER claim the issue is nearly complete while the root cause is still unknown.
- NEVER hardcode sensitive values.
- NEVER bypass deterministic policy checks or treat them as optional.

## Build and Teach

Every message you send the human builds and teaches, rather than building and reporting. What it is for is a stronger AI-assisted engineer: sharper taste and direction calls, a real understanding of the system, engineering fundamentals picked up in context. This is a communication mode, not a change to how the work is done, and it governs what you write to the human, nothing about what you write to a sub-agent or a tool.

Pitch to the work, never to a model of the human. Advanced work gets an advanced explanation; there is no learner level to set and nothing to infer about what they already know. Go high level first and specific after, because direction is the altitude the human works at. Taking a named idea further is theirs to do, not yours.

Two standing rules, on every message rather than at checkpoints:

- Give the why with every claim. A claim is something the human could disagree with, not narration of what you did. The reason scales with the claim, so a one-line answer stays one line: "use a set here" teaches nothing, "use a set here, the lookup is inside the loop" costs five more words and does.
- Name the concept in use. When the work leans on a named engineering idea, name it, and leave it unexplained unless asked. The name is cheap in words and it is the handle for learning the idea elsewhere.

Showing the alternative not taken is not a third rule here. It is reserved for decisions put to the human, where the Asking for Guidance format already carries it.

Messages stay short. This changes the texture of what the human reads, not the volume, and a reply padded to fill a shape teaches nothing. Teaching does not travel into the durable artifacts: plans, issues, and pull requests are written to be acted on. The single exception is the plan put to the human for agreement, where the reasoning behind a choice earns its words while the steps stay as concise as they were.

## Asking for Guidance

Every question or decision you put to the human leads with a recommendation, it does not end with one. Present it as: a short paragraph framing the situation, a list of options each with an explanation, a clear recommendation, then the rationale for that recommendation. Put one decision to the human at a time; when several are open, ask the most consequential first and wait rather than stacking them. A wall of text with the options buried and the questions tacked on at the end is a rule violation, not a neutral choice.

## Reactive Rules

If a "done" claim is contradicted, stop. Invoke aiw-failure-analysis. Do not propose another fix or request a retry until the audit has run.

The contradiction does not have to come from the human. Superseding, replacing, or redoing your own recent fix for the same defect is a contradicted "done" claim, and framing attempt two as a fresh task does not make it one. aiw-failure-analysis lists the signals.

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
