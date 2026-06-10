#!/usr/bin/env bash
set -eu

# Tests for project-validation.sh's repo-validation wiring branch.
# Builds a minimal sandbox containing only project-validation.sh (plus trivially
# valid files so its upfront `bash -n` glob has something to check) and exercises
# both branches: repo checks absent (must warn loudly, still pass) and present
# (must run them, no warning).

ROOT_DIR="$(git rev-parse --show-toplevel)"
SRC="$ROOT_DIR/.ai-policy/scripts/project-validation.sh"
PASS=0
FAIL=0

assert_contains() {
  local label="$1" haystack="$2" needle="$3"
  case "$haystack" in
    *"$needle"*) PASS=$((PASS + 1)); echo "  PASS: $label" ;;
    *) FAIL=$((FAIL + 1)); echo "  FAIL: $label (missing: $needle)" ;;
  esac
}

assert_not_contains() {
  local label="$1" haystack="$2" needle="$3"
  case "$haystack" in
    *"$needle"*) FAIL=$((FAIL + 1)); echo "  FAIL: $label (unexpected: $needle)" ;;
    *) PASS=$((PASS + 1)); echo "  PASS: $label" ;;
  esac
}

assert_exit() {
  local label="$1" expected="$2" actual="$3"
  if [ "$actual" -eq "$expected" ]; then
    PASS=$((PASS + 1)); echo "  PASS: $label"
  else
    FAIL=$((FAIL + 1)); echo "  FAIL: $label (expected exit $expected, got $actual)"
  fi
}

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

mkdir -p "$SANDBOX/.ai-policy/scripts" "$SANDBOX/.ai-policy/hooks" "$SANDBOX/.githooks" "$SANDBOX/scripts"
cp "$SRC" "$SANDBOX/.ai-policy/scripts/project-validation.sh"
chmod +x "$SANDBOX/.ai-policy/scripts/project-validation.sh"

# Minimal valid files so the upfront `bash -n .../*.sh .../* ` globs resolve.
printf '#!/usr/bin/env bash\n:\n' > "$SANDBOX/.ai-policy/hooks/noop.sh"
printf '#!/usr/bin/env bash\n:\n' > "$SANDBOX/.githooks/noop"

WARN_MARKER="no ./scripts/repo-validation.sh found"

cd "$SANDBOX"

echo "project-validation repo-check branch tests:"

# Case A — no ./scripts/repo-validation.sh: must warn loudly and still pass.
rc=0
out_absent="$(./.ai-policy/scripts/project-validation.sh 2>&1)" || rc=$?
assert_exit "absent repo-validation still passes" 0 "$rc"
assert_contains "absent repo-validation warns" "$out_absent" "$WARN_MARKER"

# Case B — executable ./scripts/repo-validation.sh present: must run it, no warning.
cat > scripts/repo-validation.sh <<'STUB'
#!/usr/bin/env bash
echo "REPO_CHECKS_RAN_SENTINEL"
STUB
chmod +x scripts/repo-validation.sh

rc=0
out_present="$(./.ai-policy/scripts/project-validation.sh 2>&1)" || rc=$?
assert_exit "present repo-validation passes" 0 "$rc"
assert_contains "present repo-validation is invoked" "$out_present" "REPO_CHECKS_RAN_SENTINEL"
assert_not_contains "present repo-validation does not warn" "$out_present" "$WARN_MARKER"

echo ""
echo "Results: $PASS passed, $FAIL failed out of $((PASS + FAIL)) tests."

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
