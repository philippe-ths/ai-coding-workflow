---
name: aiw-testing
description: "Mechanical craft rules for writing tests well: choosing the right test level, consuming ground truth from aiw-ground-truth rather than fabricating it, organising tests for independence and clarity, and avoiding anti-patterns that produce green suites with no real authority. Use this skill whenever the agent is about to write or modify a test, choose a fixture, pick a test level (unit, integration, end-to-end), decide whether to mock a component, refactor test code, fill a coverage gap from aiw-verification, write a regression test, or when tempted to assert on internal calls or private state. It does not decide what counts as correct (aiw-ground-truth) or whether tests are sufficient evidence (aiw-verification). It owns test mechanics, test-level selection, modality-specific testing emphasis referencing aiw-ground-truth, the anti-patterns that produce misleading green bars, and the hygiene rules that keep a suite a reliable signal."
---

# Testing

Read this file when writing a new test, modifying an existing test, choosing a test level, picking a fixture, or deciding whether to mock a component.

## Why This Skill Exists

Testing is the mechanical craft of constructing a check that the code produces the expected output. It is the easy part of the three-skill set:

- **Ground truth** decides what counts as correct. The fixture, the expected output, the oracle.
- **Testing** decides how to construct the check.
- **Verification** decides whether the checks taken together are sufficient evidence the change works.

This skill is narrow on purpose. Pull the oracle from aiw-ground-truth. Let aiw-verification judge whether the tests cover the change. Do not let testing absorb either question — the failure mode that motivates this whole set is one actor playing all the roles. Keeping testing's job mechanical preserves the separation.

## Consuming Ground Truth

For inputs that represent real-system artifacts — real user data, real upstream outputs, real configurations — source the fixture from aiw-ground-truth. Do not fabricate the fixture inline and call it a test fixture; that is the closed-loop failure mode that motivates this entire set.

For every test that depends on a ground-truth fixture:

- Record the trust level of the fixture (the 1–5 hierarchy defined in aiw-ground-truth).
- If the fixture is synthetic (trust level 5), mark the test visibly so aiw-verification treats its result as weaker evidence.
- Do not modify the fixture to make the test pass. If the fixture is wrong, source a higher-trust replacement; if it is right, fix the code.

## The Boundary With Test Setup

Not every input a test uses is ground truth. The boundary rule lives in aiw-ground-truth; this skill consumes it.

- If the input represents something the real system would actually encounter, ground-truth rules apply: source from aiw-ground-truth, record trust level, do not invent.
- If the input is a synthetic shape that exercises a function's branches, error paths, or boundary conditions, and would not occur in the real system, it is test setup. Build it inline next to the test. No provenance metadata required.

Both skills must agree on which side of the line a given input lives. When in doubt, ask the question from aiw-ground-truth: "if a real user ran the real system, could this exact input occur?"

## Choosing the Test Level

Tests come in three levels. The agent's default tendency is to unit-test everything; resist it. The correct level depends on what the test is trying to catch.

- **Unit tests.** Pure functions, branch coverage of error paths and boundary conditions, input/output transformations with no IO. Fast, abundant, low fidelity. Catch logic mistakes inside a single function.
- **Integration tests.** Seams between two or more components inside the system. Database interactions, queue handling, module boundaries. Catch mismatched assumptions where components meet.
- **End-to-end tests.** Full pipelines, real interfaces, the system running as it will in production. Catch composition failures, sequencing bugs, and silent data-shape drift between stages.

Rules:

1. **Choose the highest level that reliably catches the failure mode in question.** A logic bug that only surfaces at the seam is not caught by a unit test of the function; it needs the seam.
2. **End-to-end tests are first-class.** aiw-verification frequently requires end-to-end runs (data crossing processes, pipeline stages, external interfaces, refactor/migrate, delete). Make end-to-end tests where the change crosses one of those boundaries, not after the fact when verification asks for them.
3. **Match granularity to risk.** Payments, authentication, data mutations, and irreversible operations warrant more tests and stronger levels. Formatting and display warrant fewer.
4. **Prefer the test level the failure speaks at.** A bug in serialisation between two services does not speak at the unit level; testing it at the unit level proves only that the agent's mental model of the serialisation is self-consistent.

## Modality-Specific Testing Emphasis

The modality for this task has already been classified — either during planning via aiw-planning, or directly via aiw-ground-truth for tasks started without a planning step. This section applies the testing emphasis for the already-classified modality; it does not re-classify.

- **New.** Example-driven. Tests pin the worked examples from ground truth as expected outputs. Behaviour the agent inferred but the user did not confirm stays out of tests; tests against inferred behaviour confirm only the agent's inference.
- **Feature.** Two test sets, both required: tests for the new behaviour on user-confirmed examples, and regression tests for the existing behaviour the feature interacts with. A green run on the new path alone is half a test pass.
- **Fix.** Write the failing test first; confirm it fails; then fix the code; confirm it passes. (Why: writing it after the fix produces a test that confirms the patch, not a test that catches the bug — and you have no evidence the test would have failed pre-fix.) Beyond the specific reproducer, propose at least one broader test that would have caught this class of bug, so the coverage gap that let the bug ship is closed, not just the single hole.
- **Refactor.** Characterisation tests and snapshot-style tests dominate. Few new behavioural tests are written — the work is preserving behaviour, not adding any. Existing tests are pinned, run before, and run after. New tests added during a refactor should pin behaviour the existing suite missed, not assert on new ideas.
- **Improve.** For behavioural aspects, follow the refactor rule. For purely non-behavioural changes (naming, readability, simplification), write no new tests. Do not write tests that claim to test readability or naming quality. There is no oracle for those; a test asserting them is theatre.
- **Investigate.** A failing test that reliably reproduces the issue is often the most valuable deliverable. Prioritise producing the reproducer over any other testing output for this modality.
- **Migrate.** Characterisation tests of behaviour on real inputs, with an explicit exception list for behaviour intentionally changed (the same exception list defined in aiw-ground-truth). Tests covering the exception list should fail against the old substrate — that is the signal the migration changed what it was supposed to change.
- **Configure.** Smoke tests that hit the real external system are more valuable than unit tests of the wiring. Discourage proliferating mocks: a mock at the boundary asserts the agent's model of the external system, not the system itself. If a mock must exist (for latency, for cost, for rate limits), it lives alongside a real-system smoke test, not in place of one.
- **Delete.** Existing tests should continue to pass after the deletion. Do not add new tests; the work for a delete is dependency search, which aiw-verification owns. If existing tests cover code being removed, remove those tests as part of the change.

## Test Construction Rules

These rules apply across modalities.

1. **Assert on observable behaviour, not implementation.** Outputs, side effects, externally-visible state. Do not assert on internal method calls, private state, or code structure.
2. **Assertions must be specific.** "Response status is 404" beats "response is truthy". The more specific the assertion, the more it constrains what passing means.
3. **Failure messages must identify what went wrong.** Include the expected value, the actual value, and which behaviour was being checked. A test that says only "assertion failed" wastes the next reader's time.
4. **Prefer testing patterns already established in the project.** Do not introduce a new test framework, runner, or convention without asking. Consistency makes the suite legible; inconsistency hides signal.
5. **One test, one claim.** A test that bundles three assertions about three different behaviours fails ambiguously. Split into three tests, each with a clear name.
6. **Name the test after what it checks, not what it does.** "rejects_request_with_expired_token" beats "test_token_validation_3".

## Test Suite Hygiene

A test suite is only a reliable signal if a green bar means the code works and a red bar means it does not. These rules keep the suite honest.

- **Tests must be independently runnable.** No shared mutable state between tests, no ordering dependencies. A test that passes only when run after another test is a false signal.
- **Tests must fail when the code is broken.** Periodically apply a mutation-style spot check: deliberately break a piece of code that should be covered and confirm a test fails. A green suite that does not turn red under deliberate breakage is not a test suite, it is decoration.
- **Slow tests are tagged.** Tests that take materially longer than the rest of the suite get a marker so aiw-verification can decide whether to include them in a given run. Slow tests should not be skipped silently; they should be opted into deliberately.
- **Do not duplicate existing coverage without adding new signal.** A second test of the same path with the same fixture adds maintenance cost and no information.

## Anti-Patterns

These patterns produce green tests that prove nothing about the code under test.

- **Mocking the thing being tested.** A parser test that mocks the parser confirms only that the mock behaves like the mock. The thing under test must run for the test to mean anything.
- **Asserting on implementation details rather than observable behaviour.** Tests coupled to internals break on every refactor and trap the code in its current shape. They also miss the bugs that matter, which live in observable behaviour.
- **Tests written after the code that simply restate what the code does.** A test that mirrors the implementation is a tautology; it passes by construction. Fix-modality tests in particular must be written before the fix and confirmed to fail.
- **Tests passing by accident through shared state.** A test that relies on another test having run is unreliable; a test that relies on global mutable state is worse.
- **Mocking the external boundary the code is supposed to integrate with.** In Configure modality especially, a mock at the boundary the code is meant to talk to is the opposite of verification. See the Configure modality rule above.
- **Generating real-system fixtures inline.** If the input represents something the real system would actually encounter, it is ground truth and must come from aiw-ground-truth. Inline-generating it inside the test is the closed-loop failure mode this entire skill set exists to prevent.
