---
name: aiw-testing
description: "Test construction rules for writing tests that serve the AI implementation feedback loop. Use this skill when the agent needs to write new tests, improve existing tests, or when Step 6 identifies missing test coverage. The skill exists to prevent common test quality pitfalls that break the feedback loop: tests coupled to implementation details, vague failure messages, shared mutable state, and duplicate coverage."
---

# Writing Tests

Read this file when writing new tests or improving existing tests.
This file contains rules for test construction that serve the implementation feedback loop.

## Related Workflow Sections

This skill works alongside these workflow sections. Consult them when writing tests:

- **Validation Requirements**: covers when to run tests, baseline comparison, and result reporting. This skill covers how to write them.
- **Test Readiness**: covers the pre-implementation check for test infrastructure gaps. This skill covers filling those gaps when approved.
- **Non-Functional Test Coverage**: covers when automated coverage for UI state transitions, latency, and security must be attempted before manual verification.
- **aiw-performance-profiling**: detailed rules for writing performance and UI-state-transition tests. Load it in addition to this skill when the change triggers those conditions.
- **aiw-security-testing**: detailed rules for writing security tests. Load it in addition to this skill when the change touches a trust boundary or handles untrusted input.

## Non-Functional Coverage

Before suggesting manual verification for any change, attempt automated coverage of the following categories when they apply to the change:

- UI state transitions and reactive rerender paths.
- Execution latency and throughput on the affected code path.
- Security-relevant behaviour: authorisation checks, input validation, escaping, secret handling, and data-access boundaries.

If the change affects UI state, reactive subscriptions, caching, heavy loops, or manual state resets, load the `aiw-performance-profiling` skill and follow its rules.

If the change touches authentication, authorisation, untrusted input, file-path or shell-command construction, secret handling, external API consumers, or data-access boundaries, load the `aiw-security-testing` skill and follow its rules. At minimum, exercise the negative path: rejected input, forbidden access, malformed tokens, and boundary conditions. A passing happy-path test is not sufficient security coverage.

If automated coverage is not feasible for a category, state the reason in writing in the plan or summary, and propose a manual check with explicit success and failure signals. Do not silently fall back to manual verification.

## Test Construction Rules

1. Test behaviour, not implementation.
   Assert on outputs, side effects, and observable state.
   Do not assert on internal method calls, private state, or code structure.

2. Each test must be independent.
   No shared mutable state between tests.
   No ordering dependencies.

3. Assertions must be specific.
   "Assert the response status is 404" not "assert the response is truthy."

4. Failure messages must identify what went wrong.
   Include expected value, actual value, and which behaviour was being tested.

5. Prefer the testing patterns already established in the project.
   Do not introduce a new test framework or convention without asking.

6. Match test granularity to risk.
   High-risk paths (payments, auth, data mutations) get more tests.
   Low-risk paths (formatting, display) get fewer.

7. Do not write tests that duplicate existing coverage without adding new signal.

8. Do not write tests that require external services, network access, or manual setup unless the project already has that pattern.

9. When writing tests for a bug fix, write the test first, confirm it fails, then fix the code.
   This verifies the test actually catches the bug.
