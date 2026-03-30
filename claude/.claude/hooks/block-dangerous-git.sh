#!/usr/bin/env bash
set -euo pipefail

# [SECURITY] Fail-closed: if jq is missing, block all commands rather than
# silently allowing everything through.
if ! command -v jq > /dev/null 2>&1; then
  echo "BLOCKED: jq is required for hook evaluation but not found." >&2
  exit 2
fi

INPUT=$(cat)
COMMAND=$(jq -r '.tool_input.command' <<< "$INPUT")

# ── Destructive shell commands ────────────────────────────────────────────────

# Recursive force-delete: catch `rm` with both -r/-R (recursive) and -f (force)
# in any flag order (e.g. `rm -rf`, `rm -fr`, `rm --recursive --force`, etc.).
if echo "$COMMAND" | grep -qiE '(^|;[[:space:]]*|&&[[:space:]]*|[|][|][[:space:]]*|[|][[:space:]]*)rm[[:space:]]' \
  && echo "$COMMAND" | grep -qiE '(^|[[:space:]])-[a-zA-Z]*[rR]|--recursive' \
  && echo "$COMMAND" | grep -qiE '(^|[[:space:]])-[a-zA-Z]*[fF]|--force'; then
  echo "BLOCKED: recursive force-delete detected in '$COMMAND'. Use trash instead of rm -rf." >&2
  exit 2
fi

# Privilege escalation, raw disk write, filesystem format.
if [[ "$COMMAND" =~ ^sudo\  || "$COMMAND" =~ ^mkfs\  || "$COMMAND" =~ ^dd\  ]]; then
  echo "BLOCKED: '$COMMAND' — privilege escalation or raw device access is forbidden." >&2
  exit 2
fi

# Pipe-to-shell: block wget/curl piped into bash/sh — classic supply-chain vector.
if [[ "$COMMAND" =~ (wget|curl).*\|[[:space:]]*(bash|sh) ]]; then
  echo "BLOCKED: '$COMMAND' — pipe-to-shell execution is forbidden." >&2
  exit 2
fi

# ── Dangerous git commands ────────────────────────────────────────────────────

# Anchored patterns — match only at the start of the command string so that
# mentions of git subcommands inside heredoc/commit-message bodies don't
# trigger false positives.
ANCHORED_PATTERNS=(
  # --- push / force ---
  "^git push"

  # --- reset (all forms: --hard, --mixed, --soft) ---
  # Moving HEAD orphans commits; eventually lost to GC.
  "^git reset"

  # --- working-tree destruction ---
  "^git clean -f"
  "^git branch -D"
  # Bare `checkout --` AND path-based checkout (e.g. `git checkout HEAD -- file`)
  "^git checkout --"
  "^git checkout .+ -- "
  # git restore always rewrites the index or worktree. Block all forms rather
  # than trying to whitelist pathspec or staged/worktree variants.
  "^git restore"

  # --- stash destruction ---
  "^git stash drop"
  "^git stash clear"

  # --- history rewriting ---
  "^git rebase"
  "^git commit --amend"

  # --- tracked-file removal ---
  "^git rm"

  # --- GC / recovery destruction ---
  "^git gc"
  "^git prune"
  "^git reflog expire"

  # --- low-level ref manipulation ---
  "^git update-ref"
)

for pattern in "${ANCHORED_PATTERNS[@]}"; do
  if [[ "$COMMAND" =~ $pattern ]]; then
    echo "BLOCKED: '$COMMAND' matches dangerous pattern '$pattern'. The user has prevented you from doing this." >&2
    echo "You must work in the current branch, and only commit."
    exit 2
  fi
done

# Substring patterns — catch variants like `git -c ... push --force` where the
# dangerous flag appears later in the command, not at the prefix.
SUBSTRING_PATTERNS=(
  "push --force"
  "push --force-with-lease"
  "reset --hard"
)

for pattern in "${SUBSTRING_PATTERNS[@]}"; do
  if [[ "$COMMAND" =~ $pattern ]]; then
    echo "BLOCKED: '$COMMAND' matches dangerous pattern '$pattern'. The user has prevented you from doing this." >&2
    echo "You must work in the current branch, and only commit."
    exit 2
  fi
done

exit 0
