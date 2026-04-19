# t-002-fix-off-by-one

## Acceptance criteria
- `range_sum(lo, hi)` returns the inclusive sum of integers from `lo` to `hi`.
- `range_sum(1, 5)` returns `15`, not `10`.
- The existing failing test in `test_range_sum.py` passes after the fix.

## Prompt
`range_sum.py` has an off-by-one bug: `range_sum(1, 5)` returns `10` but the
docstring and the test in `test_range_sum.py` expect the inclusive sum `15`.
Fix the bug in `range_sum.py`. Do not change the tests.
