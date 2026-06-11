#!/usr/bin/env bash
# Sandbox test for scripts/install.sh.
#
# Installs into throwaway git repos under a temp dir and asserts the product
# set lands, factory files do not, the target .gitignore records the vendored
# files, hooks are wired for the full profile, and the install is idempotent.
set -u

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL="$ROOT_DIR/scripts/install.sh"

pass=0
fail=0
ok()   { echo "  PASS: $1"; pass=$((pass + 1)); }
bad()  { echo "  FAIL: $1" >&2; fail=$((fail + 1)); }

present() { if [ -e "$1/$2" ]; then ok "present: $2"; else bad "missing: $2"; fi; }
absent()  { if [ -e "$1/$2" ]; then bad "should be absent: $2"; else ok "absent: $2"; fi; }
has_line() { if grep -qF "$2" "$1/.gitignore" 2>/dev/null; then ok ".gitignore has $2"; else bad ".gitignore missing $2"; fi; }

SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t aiw-install)"
trap 'rm -rf "$SANDBOX"' EXIT

new_target() {
  local d="$SANDBOX/$1"
  mkdir -p "$d"
  ( cd "$d" && git init -q && git config user.email t@t && git config user.name t ) >/dev/null 2>&1
  echo "$d"
}

echo "full / claude:"
T="$(new_target full-claude)"
"$INSTALL" --source "$ROOT_DIR" --target "$T" --tool claude --profile full >/dev/null 2>&1 || bad "install exited non-zero"
present "$T" CLAUDE.md
present "$T" .claude/settings.json
present "$T" .claude/skills
present "$T" ai-workflow.md
present "$T" .ai-policy/scripts/install-hooks.sh
present "$T" .githooks
absent  "$T" AGENTS.md
absent  "$T" .codex
absent  "$T" .gemini
absent  "$T" .vscode
absent  "$T" .agents
absent  "$T" observation
absent  "$T" CHANGELOG.md
absent  "$T" README.md
absent  "$T" install-manifest.json
absent  "$T" project-context.md
absent  "$T" .ai-policy/state/validation.status
has_line "$T" "CLAUDE.md"
has_line "$T" ".claude/"
has_line "$T" ".ai-policy/"
has_line "$T" ".githooks/"
has_line "$T" "ai-workflow.md"
hp="$(cd "$T" && git config core.hooksPath || true)"
if [ "$hp" = ".githooks" ]; then ok "core.hooksPath set"; else bad "core.hooksPath not set (got '$hp')"; fi

echo "idempotency (re-run):"
"$INSTALL" --source "$ROOT_DIR" --target "$T" --tool claude --profile full >/dev/null 2>&1
n="$(grep -cF "# >>> ai-workflow (vendored, managed by installer) >>>" "$T/.gitignore")"
if [ "$n" -eq 1 ]; then ok "single managed block after re-run"; else bad "managed block count = $n"; fi

echo "full / codex (tool specificity):"
T="$(new_target full-codex)"
"$INSTALL" --source "$ROOT_DIR" --target "$T" --tool codex --profile full >/dev/null 2>&1
present "$T" AGENTS.md
present "$T" .codex/config.toml
present "$T" .agents/skills
absent  "$T" CLAUDE.md
absent  "$T" .claude

echo "full / gemini (tool specificity):"
T="$(new_target full-gemini)"
"$INSTALL" --source "$ROOT_DIR" --target "$T" --tool gemini --profile full >/dev/null 2>&1
present "$T" GEMINI.md
present "$T" .gemini/settings.json
present "$T" .agents/skills
absent  "$T" CLAUDE.md
absent  "$T" .codex

echo "full / copilot (tool specificity):"
T="$(new_target full-copilot)"
"$INSTALL" --source "$ROOT_DIR" --target "$T" --tool copilot --profile full >/dev/null 2>&1
present "$T" .github/copilot-instructions.md
present "$T" .github/hooks/block-protected-branch.json
present "$T" .vscode/settings.json
present "$T" .agents/skills
absent  "$T" CLAUDE.md
absent  "$T" GEMINI.md

echo "lite / claude:"
T="$(new_target lite-claude)"
"$INSTALL" --source "$ROOT_DIR" --target "$T" --tool claude --profile lite >/dev/null 2>&1
present "$T" ai-workflow.md
present "$T" CLAUDE.md
absent  "$T" .ai-policy
absent  "$T" .githooks
absent  "$T" .claude
if grep -qF "self-contained" "$T/ai-workflow.md"; then ok "lite workflow content copied"; else bad "lite workflow content wrong"; fi
has_line "$T" "ai-workflow.md"
has_line "$T" "CLAUDE.md"
hp="$(cd "$T" && git config core.hooksPath || true)"
if [ -z "$hp" ]; then ok "no hooks for lite"; else bad "lite should not set hooks (got '$hp')"; fi

echo
echo "Results: $pass passed, $fail failed."
[ "$fail" -eq 0 ]
