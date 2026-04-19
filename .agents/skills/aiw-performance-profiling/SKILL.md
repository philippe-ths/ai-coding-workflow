---
name: aiw-performance-profiling
description: "Automated performance and UI-state-transition coverage rules. Use this skill when implementing changes to user interfaces, reactive state, heavy data loops, caching logic, or any code path where runtime speed affects usability. The skill exists to prevent the pattern where functional tests pass while real-world execution becomes sluggish or stutters."
---

# Performance Profiling and Latency Coverage

Read this file when the change touches runtime paths where speed or responsiveness matters.
This file contains rules for writing automated performance and UI-state-transition tests before deferring to manual verification.

## Related Workflow Sections

This skill works alongside these workflow sections — consult them when writing performance tests:

- **Non-Functional Test Coverage** — defines when automated coverage must be attempted before manual verification.
- **aiw-testing** — general test construction rules. This skill covers the performance-specific subset.
- **aiw-logging-and-observability** — covers ad-hoc runtime diagnostics. This skill covers pre-commit automated tests.

## When This Skill Applies

Load this skill when the change does any of the following:

- Touches a UI state transition, reactive subscription, or view-layer rerender path.
- Introduces or modifies caching, memoisation, debouncing, or throttling.
- Introduces or modifies manual state resets or session invalidation.
- Adds or modifies a data-processing loop over non-trivial input.
- Adds a UI decorator or wrapper that affects render frequency.
- Converts a synchronous path to asynchronous or vice versa.

If any of these apply and no automated performance coverage exists for the affected path, add coverage as part of the change.

## Rules

1. Capture a baseline measurement before writing the test.
   Run the existing code path on a representative input and record the measured time.
   Anchor the regression test to that number.

2. Write the latency assertion against the baseline plus a stated tolerance.
   State the tolerance inline in the test.
   Do not pick a round-number threshold unrelated to the baseline.

3. Run the benchmark multiple times and assert on a stable statistic.
   Prefer median or 95th percentile over a single sample.
   Single-sample assertions produce flaky tests.

4. Isolate the measurement from unrelated work.
   Do not include setup, teardown, or unrelated I/O in the timed section.

5. For UI state transitions, assert on the transition outcome and on the input-to-rendered-state time.
   Assert the final state equals the expected state.
   Assert the transition completed within the latency bound.

6. For heavy data loops, assert on total wall-clock time and on per-iteration time when iteration count varies.
   Do not assert only on total time when input size is not fixed.

7. When a caching workaround or manual state reset is added, write a test that proves the workaround does not reintroduce the problem it is patching.
   A passing functional test is not sufficient proof.

8. If automated performance coverage is not feasible, state the reason in writing and propose a manual check with explicit success and failure signals.
   Do not silently fall back to manual verification.

9. Do not weaken a failing performance threshold before investigating the cause.
   (Why: Lowering the bar to make a test pass hides the regression the test was written to catch.)

10. Keep only benchmarks that run in the regular test suite.
    Remove one-off benchmark scripts before completion.

## What Not to Do

- Do not claim performance coverage based on a functional test that happens to pass quickly.
- Do not assert on absolute numbers that depend on the host machine without documenting the host assumption.
- Do not write a performance test that requires production data or credentials.
