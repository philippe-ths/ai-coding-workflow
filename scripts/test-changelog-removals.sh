#!/usr/bin/env bash
# Tests for scripts/check-changelog-removals.sh.
set -u

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHECK="$ROOT_DIR/scripts/check-changelog-removals.sh"

pass=0
fail=0
ok()  { echo "  PASS: $1"; pass=$((pass + 1)); }
bad() { echo "  FAIL: $1" >&2; fail=$((fail + 1)); }

TMP="$(mktemp -d 2>/dev/null || mktemp -d -t aiw-clog)"
trap 'rm -rf "$TMP"' EXIT

# 1. Compliant: every Removed bullet leads with a backticked path; Added bullets are ignored.
cat > "$TMP/good.md" <<'MD'
# Changelog

## 1.0.0

### Removed

- `foo/bar.sh` — gone
- `baz/` — whole dir gone

### Added

- a feature described in prose, not a path
MD
if "$CHECK" "$TMP/good.md" >/dev/null 2>&1; then ok "compliant changelog passes"; else bad "compliant changelog should pass"; fi

# 2. Non-compliant: a Removed bullet that does not lead with a path.
cat > "$TMP/bad.md" <<'MD'
# Changelog

## 1.0.0

### Removed

- The thing in `foo/bar.sh` was removed
MD
if "$CHECK" "$TMP/bad.md" >/dev/null 2>&1; then bad "non-compliant changelog should fail"; else ok "non-compliant changelog fails"; fi

# 3. Non-compliant only outside Removed must still pass (scope is Removed-only).
cat > "$TMP/scope.md" <<'MD'
# Changelog

## 1.0.0

### Changed

- reworded a prose bullet, not a path

### Removed

- `x/y.sh` — gone
MD
if "$CHECK" "$TMP/scope.md" >/dev/null 2>&1; then ok "non-path bullets outside Removed are ignored"; else bad "should ignore bullets outside Removed"; fi

# 4. Regression: this repo's real CHANGELOG.md complies.
if "$CHECK" "$ROOT_DIR/CHANGELOG.md" >/dev/null 2>&1; then ok "real CHANGELOG.md complies"; else bad "real CHANGELOG.md does not comply"; fi

echo
echo "Results: $pass passed, $fail failed."
[ "$fail" -eq 0 ]
