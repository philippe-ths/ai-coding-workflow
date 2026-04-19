import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from range_sum import range_sum  # noqa: E402


def test_grader_inclusive():
    assert range_sum(1, 5) == 15
    assert range_sum(0, 10) == 55
    assert range_sum(3, 3) == 3
    assert range_sum(-2, 2) == 0
