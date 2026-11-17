#!/usr/bin/env bash
# Sourced, not run. Finds the files an agent reads later as instructions:
# check-pr-verification.sh asks which of them a branch changed, and
# block-unsmithed-prose.sh asks whether a write is about to land on one.
#
# Agent-facing prose is found by path: the skill and agent directories, the
# entry points and ai-workflow.md, and whatever an entry point pulls in with an
# @ token, followed through further @ tokens. An @ token is text from a file in
# the working tree, which a cloned repository can make hostile, so it is never
# handed to a shell: paths are restricted to a plain character set, may not
# leave the repository, may not themselves be symlinks, and are read with a
# size cap.

# Normalise a repository-relative path, resolving . and .., and print it; fail
# when the path climbs above the repository root. No filesystem access, so a
# symlink cannot redirect it, and no shell sees the text.
inside_repo() {
  local IFS='/' seg out=""
  case "$1" in /*) return 1 ;; esac
  for seg in $1; do
    case "$seg" in
      ''|'.') ;;
      '..') [ -n "$out" ] || return 1; case "$out" in */*) out="${out%/*}" ;; *) out="" ;; esac ;;
      *) out="${out:+$out/}$seg" ;;
    esac
  done
  [ -n "$out" ] || return 1
  printf '%s' "$out"
}

# The entry points and everything they include, transitively, read from the
# working tree and from the base commit. Prints one path per line.
prose_includes() {
  local root="$1" mb="$2" queue seen p tok dir cand src content
  queue="CLAUDE.md AGENTS.md .github/copilot-instructions.md"
  seen=""
  while [ -n "$queue" ]; do
    p="${queue%% *}"
    queue="${queue#"$p"}"; queue="${queue# }"
    case " $seen " in *" $p "*) continue ;; esac
    seen="$seen $p"
    dir="${p%/*}"; [ "$dir" = "$p" ] && dir=""
    for src in tree base; do
      if [ "$src" = tree ]; then
        [ -f "$root/$p" ] && [ ! -L "$root/$p" ] || continue
        content="$(head -c 1000000 -- "$root/$p" 2>/dev/null)" || continue
      else
        content="$(git -C "$root" show "$mb:$p" 2>/dev/null | head -c 1000000)" || continue
        [ -n "$content" ] || continue
      fi
      # Drop fenced code blocks (a demonstration is not an include), then take
      # every whitespace-delimited token that starts with @, less trailing
      # punctuation. Only plain paths are followed; anything else is ignored.
      for tok in $(printf '%s\n' "$content" | LC_ALL=C awk '/^[[:space:]]*```/ { f = !f; next } !f { print }' \
                    | grep -oE '(^|[[:space:](])@[^[:space:]]+' | sed -e 's/^[[:space:](]*@//' -e 's/[.,;:)]*$//' \
                    | grep -E '^[A-Za-z0-9._/-]+$' | sort -u); do
        [ "$(wc -w <<<"$seen $queue")" -lt 200 ] || break
        for cand in "${dir:+$dir/}$tok" "$tok"; do
          cand="$(inside_repo "$cand")" || continue
          if { [ -f "$root/$cand" ] && [ ! -L "$root/$cand" ]; } || git -C "$root" cat-file -e "$mb:$cand" 2>/dev/null; then
            case " $seen $queue " in *" $cand "*) ;; *) queue="$queue $cand" ;; esac
            break
          fi
        done
      done
    done
    queue="${queue# }"
  done
  printf '%s\n' $seen | grep -v '^$' || true
}
