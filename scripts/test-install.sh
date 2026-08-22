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
has_line() { if LC_ALL=C grep -qF "$2" "$1/.gitignore" 2>/dev/null; then ok ".gitignore has $2"; else bad ".gitignore missing $2"; fi; }
exactly_once() { local c; c="$(LC_ALL=C grep -cxF "$2" "$1/.gitignore" 2>/dev/null || true)"; if [ "${c:-0}" -eq 1 ]; then ok ".gitignore has exactly one '$2'"; else bad ".gitignore has $c '$2' (expected 1)"; fi; }

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

echo "pre-existing unmarked .gitignore entries (no duplicates):"
T="$(new_target preexisting-gitignore)"
cat > "$T/.gitignore" <<'GI'
# user's own ignores
node_modules/
ai-workflow.md
.claude/
.ai-policy
.githooks/
CLAUDE.md
GI
"$INSTALL" --source "$ROOT_DIR" --target "$T" --tool claude --profile full >/dev/null 2>&1
exactly_once "$T" "ai-workflow.md"
exactly_once "$T" ".claude/"
exactly_once "$T" ".ai-policy/"
exactly_once "$T" ".githooks/"
exactly_once "$T" "CLAUDE.md"
has_line   "$T" "node_modules/"

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

# --- multi-tool helpers ---------------------------------------------------
manifest_paths() { # tool -> full-profile vendored paths, one per line
  jq -r --arg t "$1" '[.profiles.full.shared[], .profiles.full.tools[$t][]] | .[]' "$ROOT_DIR/install-manifest.json"
}
tool_paths() { # tools... -> deduplicated union of their vendored paths
  local tool
  for tool in "$@"; do manifest_paths "$tool"; done | sort -u
}
block_count() { local n; n="$(LC_ALL=C grep -cF "# >>> ai-workflow (vendored, managed by installer) >>>" "$1/.gitignore" 2>/dev/null || true)"; echo "${n:-0}"; }
outside_block() { # lines of .gitignore that are NOT inside the managed block
  LC_ALL=C awk -v b="# >>> ai-workflow (vendored, managed by installer) >>>" \
      -v e="# <<< ai-workflow <<<" \
      '$0==b {skip=1} skip==0 {print} $0==e {skip=0}' "$1/.gitignore" 2>/dev/null
}
has_outside() { if outside_block "$1" | LC_ALL=C grep -qxF "$2"; then ok "kept outside block: $2"; else bad "lost outside block: $2"; fi; }
one_block() { local n; n="$(block_count "$1")"; if [ "$n" -eq 1 ]; then ok "single managed block"; else bad "managed block count = $n"; fi; }
no_untracked_vendored() { # target, then tools... : git status must not report vendored paths
  local t="$1"; shift
  local paths untracked p u pn un offenders=""
  paths="$(tool_paths "$@")"
  untracked="$(git -C "$t" status --porcelain 2>/dev/null | awk '/^\?\? /{print substr($0, 4)}')"
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    pn="${p%/}"
    while IFS= read -r u; do
      [ -z "$u" ] && continue
      un="${u%/}"
      case "$pn" in "$un"|"$un"/*) offenders="$offenders $p" ; continue ;; esac
      case "$un" in "$pn"|"$pn"/*) offenders="$offenders $p" ;; esac
    done <<UNTRACKED
$untracked
UNTRACKED
  done <<PATHS
$paths
PATHS
  if [ -z "$offenders" ]; then
    ok "git status reports no vendored paths as untracked"
  else
    bad "git status reports vendored paths as untracked:$offenders"
  fi
}

echo "multi-tool install (gemini then claude, same target):"
T="$(new_target multi-gemini-claude)"
"$INSTALL" --source "$ROOT_DIR" --target "$T" --tool gemini --profile full >/dev/null 2>&1 || bad "gemini install exited non-zero"
"$INSTALL" --source "$ROOT_DIR" --target "$T" --tool claude --profile full >/dev/null 2>&1 || bad "claude install exited non-zero"
while IFS= read -r p; do has_line "$T" "$p"; done <<EOF
$(tool_paths gemini claude)
EOF
exactly_once "$T" ".agents/skills/"
exactly_once "$T" ".ai-policy/"
exactly_once "$T" "ai-workflow.md"
one_block "$T"
no_untracked_vendored "$T" gemini claude

echo "multi-tool install (third tool: codex on top):"
"$INSTALL" --source "$ROOT_DIR" --target "$T" --tool codex --profile full >/dev/null 2>&1 || bad "codex install exited non-zero"
while IFS= read -r p; do has_line "$T" "$p"; done <<EOF
$(tool_paths gemini claude codex)
EOF
exactly_once "$T" ".agents/skills/"
one_block "$T"
no_untracked_vendored "$T" gemini claude codex

echo "hand-maintained entries outside the managed block survive a later install:"
T="$(new_target hand-maintained)"
"$INSTALL" --source "$ROOT_DIR" --target "$T" --tool gemini --profile full >/dev/null 2>&1 || bad "gemini install exited non-zero"
cat >> "$T/.gitignore" <<'GI'

# keep these - hand maintained
.agents/skills/
build-output/
GI
"$INSTALL" --source "$ROOT_DIR" --target "$T" --tool codex --profile full >/dev/null 2>&1 || bad "codex install exited non-zero"
has_outside "$T" "# keep these - hand maintained"
has_outside "$T" ".agents/skills/"
has_outside "$T" "build-output/"
one_block "$T"

# The one moment the installer cannot tell a deliberate hand-maintained entry
# from the residue of an earlier manual install is the first one, because there
# is no managed block yet to date the file against. It folds on that run only
# (#166's normalisation), and never again (#216). Pinned so the boundary is a
# chosen behaviour rather than an accident.
echo "a first install folds a pre-existing vendored path, and only that path:"
T="$(new_target fold-on-first)"
cat > "$T/.gitignore" <<'GI'
# keep these - hand maintained
.agents/skills/
build-output/
GI
"$INSTALL" --source "$ROOT_DIR" --target "$T" --tool gemini --profile full >/dev/null 2>&1 || bad "gemini install exited non-zero"
exactly_once "$T" ".agents/skills/"
has_outside  "$T" "build-output/"
has_outside  "$T" "# keep these - hand maintained"
if git -C "$T" status --porcelain 2>/dev/null | grep -qE '\.agents/|\.gemini/|GEMINI\.md'; then
  bad "a vendored path is untracked after the fold"
else
  ok "no vendored path is untracked after the fold"
fi

# --- byte- and shape-hostile .gitignore content (#229) --------------------
# A target's .gitignore is arbitrary bytes written by humans and other tools.
# Each case below is a real .gitignore that silently un-ignored vendored paths,
# truncated the file, or grew a block per install.

insert_in_block() { # target, line : add a line just inside the managed block
  local t="$1" l="$2"
  LC_ALL=C awk -v e="# <<< ai-workflow <<<" -v l="$l" '$0==e {print l} {print}' \
    "$t/.gitignore" > "$t/.gitignore.ins" && mv "$t/.gitignore.ins" "$t/.gitignore"
}

echo "a non-UTF-8 byte inside the managed block does not truncate .gitignore:"
T="$(new_target invalid-utf8-in-block)"
printf 'node_modules/\n# >>> ai-workflow (vendored, managed by installer) >>>\nL\xf6sungen/\n.claude/\n# <<< ai-workflow <<<\n' > "$T/.gitignore"
before_bytes="$(wc -c < "$T/.gitignore" | tr -d ' ')"
"$INSTALL" --source "$ROOT_DIR" --target "$T" --tool claude --profile full >/dev/null 2>&1 || bad "install exited non-zero on an invalid-UTF-8 .gitignore"
after_bytes="$(wc -c < "$T/.gitignore" | tr -d ' ')"
if [ "${after_bytes:-0}" -ge "${before_bytes:-0}" ]; then
  ok ".gitignore not truncated ($before_bytes -> $after_bytes bytes)"
else
  bad ".gitignore truncated ($before_bytes -> $after_bytes bytes)"
fi
has_line "$T" "node_modules/"
has_line "$T" "$(printf 'L\xf6sungen/')"
exactly_once "$T" ".claude/"
one_block "$T"
no_untracked_vendored "$T" claude

echo "a non-UTF-8 byte outside the block does not append a second block per install:"
T="$(new_target invalid-utf8-outside-block)"
printf 'node_modules/\nL\xf6sungen/\n' > "$T/.gitignore"
"$INSTALL" --source "$ROOT_DIR" --target "$T" --tool claude --profile full >/dev/null 2>&1 || bad "first install exited non-zero"
"$INSTALL" --source "$ROOT_DIR" --target "$T" --tool claude --profile full >/dev/null 2>&1 || bad "second install exited non-zero"
one_block "$T"
exactly_once "$T" ".claude/"
has_line "$T" "node_modules/"
absent "$T" .gitignore.tmp
no_untracked_vendored "$T" claude

echo "a block entry containing a literal '|' does not un-ignore a vendored path:"
T="$(new_target pipe-in-block)"
"$INSTALL" --source "$ROOT_DIR" --target "$T" --tool gemini --profile full >/dev/null 2>&1 || bad "gemini install exited non-zero"
insert_in_block "$T" 'a|.claude|b'
"$INSTALL" --source "$ROOT_DIR" --target "$T" --tool claude --profile full >/dev/null 2>&1 || bad "claude install exited non-zero"
exactly_once "$T" ".claude/"
has_line "$T" 'a|.claude|b'
if git -C "$T" check-ignore -q .claude/settings.json; then ok "git still ignores .claude/settings.json"; else bad "git no longer ignores .claude/settings.json"; fi
one_block "$T"

echo "a leading-whitespace block entry does not shadow the real vendored path:"
T="$(new_target leading-space-in-block)"
"$INSTALL" --source "$ROOT_DIR" --target "$T" --tool gemini --profile full >/dev/null 2>&1 || bad "gemini install exited non-zero"
insert_in_block "$T" '  .claude/'
"$INSTALL" --source "$ROOT_DIR" --target "$T" --tool claude --profile full >/dev/null 2>&1 || bad "claude install exited non-zero"
exactly_once "$T" ".claude/"
if git -C "$T" check-ignore -q .claude/settings.json; then ok "git ignores .claude/settings.json"; else bad "git does not ignore .claude/settings.json"; fi
one_block "$T"
no_untracked_vendored "$T" gemini claude

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
