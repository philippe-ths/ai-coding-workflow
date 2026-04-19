import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from utils import sum_list  # noqa: E402


def test_empty():
    assert sum_list([]) == 0


def test_nonempty():
    assert sum_list([1, 2, 3]) == 6


def test_negative():
    assert sum_list([-1, -2, 3]) == 0
