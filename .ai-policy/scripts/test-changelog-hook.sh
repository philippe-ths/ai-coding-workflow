#!/usr/bin/env bash
set -eu

# Tests for the pre-push changelog-discipline hook.
# Builds a throwaway git repository, stages commits that do and do not
# bump ai-workflow.md's Version header, and invokes check-changelog.sh
# via the standard pre-push stdin contract.

ROOT_DIR="$(git rev-parse --show-toplevel)"
HOOK="$ROOT_DIR/.ai-policy/hooks/check-changelog.sh"

PASS=0
FAIL=0

assert_exit() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if [ "$actual" -eq "$expected" ]; then
    PASS=$((PASS + 1))
    echo "  PASS: $label"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $label (expected exit $expected, got $actual)"
  fi
}

SANDBOX="$(mktemp -d)"
cleanup() { rm -rf "$SANDBOX"; }
trap cleanup EXIT

cd "$SANDBOX"
git init -q .
git checkout -q -b main 2>/dev/null || git symbolic-ref HEAD refs/heads/main
git config user.email "test@example.invalid"
git config user.name "Changelog Hook Test"
git config commit.gpgsign false

# Baseline commit: Version 1.0.0 + matching CHANGELOG.
cat > ai-workflow.md <<'EOF'
# AI Workflow

Version: 1.0.0

Body.
EOF
cat > CHANGELOG.md <<'EOF'
# Changelog

## 1.0.0 - 2026-01-01

### Added

- Initial.
EOF
git add ai-workflow.md CHANGELOG.md
git commit -q -m "baseline 1.0.0"
BASE="$(git rev-parse HEAD)"
ZERO="0000000000000000000000000000000000000000"

echo "Changelog hook tests:"

# Case A: version bump WITH matching entry → allowed.
cat > ai-workflow.md <<'EOF'
# AI Workflow

Version: 1.1.0

Body.
EOF
cat > CHANGELOG.md <<'EOF'
# Changelog

## 1.1.0 - 2026-02-01

### Added

- Thing.

## 1.0.0 - 2026-01-01

### Added

- Initial.
EOF
git add ai-workflow.md CHANGELOG.md
git commit -q -m "bump 1.1.0 with entry"
HEAD_OK="$(git rev-parse HEAD)"

rc=0
printf 'refs/heads/main %s refs/heads/main %s\n' "$HEAD_OK" "$BASE" \
  | "$HOOK" >/dev/null 2>&1 || rc=$?
assert_exit "bump with matching entry is allowed" 0 "$rc"

# Case B: version bump WITHOUT matching entry → blocked.
# Rewrite CHANGELOG on HEAD to drop the 1.1.0 entry.
cat > CHANGELOG.md <<'EOF'
# Changelog

## 1.0.0 - 2026-01-01

### Added

- Initial.
EOF
git add CHANGELOG.md
git commit -q -m "drop 1.1.0 entry"
HEAD_BAD="$(git rev-parse HEAD)"

rc=0
printf 'refs/heads/main %s refs/heads/main %s\n' "$HEAD_BAD" "$BASE" \
  | "$HOOK" >/dev/null 2>&1 || rc=$?
assert_exit "bump without matching entry is blocked" 1 "$rc"

# Case C: no version change at all → allowed.
echo "unrelated" > other.txt
git add other.txt
git commit -q -m "unrelated change"
HEAD_NOOP="$(git rev-parse HEAD)"

rc=0
printf 'refs/heads/main %s refs/heads/main %s\n' "$HEAD_NOOP" "$HEAD_BAD" \
  | "$HOOK" >/dev/null 2>&1 || rc=$?
assert_exit "no version change is allowed" 0 "$rc"

# Case D: new branch push (remote_sha = zero) with a clean-state bump → allowed.
# Reset the sandbox back to the known-good HEAD_OK for this case.
git checkout -q "$HEAD_OK"
git checkout -q -b feature/x
NEW_SHA="$(git rev-parse HEAD)"

rc=0
printf 'refs/heads/feature/x %s refs/heads/feature/x %s\n' "$NEW_SHA" "$ZERO" \
  | "$HOOK" >/dev/null 2>&1 || rc=$?
# No DEFAULT_BASE (origin/main) exists in the sandbox, so the hook skips.
assert_exit "new-branch push with no base skips cleanly" 0 "$rc"

# Case E: bracketed '## [1.2.0]' heading style is accepted.
git checkout -q main
cat > ai-workflow.md <<'EOF'
# AI Workflow

Version: 1.2.0

Body.
EOF
cat > CHANGELOG.md <<'EOF'
# Changelog

## [1.2.0] - 2026-03-01

### Added

- Thing.

## 1.0.0 - 2026-01-01

### Added

- Initial.
EOF
git add ai-workflow.md CHANGELOG.md
git commit -q -m "bump 1.2.0 bracketed heading"
HEAD_BRK="$(git rev-parse HEAD)"

rc=0
printf 'refs/heads/main %s refs/heads/main %s\n' "$HEAD_BRK" "$HEAD_OK" \
  | "$HOOK" >/dev/null 2>&1 || rc=$?
assert_exit "bracketed heading style is accepted" 0 "$rc"

echo ""
echo "Results: $PASS passed, $FAIL failed out of $((PASS + FAIL)) tests."

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
