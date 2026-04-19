# t-003-rename-function

## Acceptance criteria
- The function `old_greeting` is renamed to `new_greeting` in `greeting.py`.
- All call sites in `app.py` are updated to use `new_greeting`.
- Behaviour is unchanged: `new_greeting("world") == "hello, world"`.
- No reference to `old_greeting` remains in any `.py` file in the workspace.

## Prompt
Rename the function `old_greeting` in `greeting.py` to `new_greeting`, and
update every call site in `app.py` to use the new name. Preserve behaviour.
Do not change the test files in `tests/`.
