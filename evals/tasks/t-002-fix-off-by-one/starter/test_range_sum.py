from range_sum import range_sum


def test_inclusive_sum():
    assert range_sum(1, 5) == 15


def test_single():
    assert range_sum(7, 7) == 7
