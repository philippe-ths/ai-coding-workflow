import re
import sys
from pathlib import Path

WORKSPACE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(WORKSPACE))


def test_new_name_works():
    import importlib

    greeting = importlib.import_module("greeting")
    assert hasattr(greeting, "new_greeting"), "greeting.new_greeting must exist"
    assert greeting.new_greeting("world") == "hello, world"

    app = importlib.import_module("app")
    assert app.greet_world() == "hello, world"
    assert app.greet_team() == "hello, team"


def test_old_name_removed():
    for py in WORKSPACE.rglob("*.py"):
        if "_grader" in py.parts:
            continue
        text = py.read_text()
        assert not re.search(r"\bold_greeting\b", text), (
            f"old_greeting still referenced in {py.relative_to(WORKSPACE)}"
        )
