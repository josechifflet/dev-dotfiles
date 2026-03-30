#!/usr/bin/env bash
set -euo pipefail

# Fail closed if `jq` is missing. The hook should never silently allow commands.
if ! command -v jq > /dev/null 2>&1; then
  echo "BLOCKED: jq is required for Codex hook evaluation but was not found." >&2
  exit 2
fi

INPUT="$(cat)"

# Missing or malformed payload means we cannot safely evaluate the command.
if ! COMMAND="$(printf '%s' "$INPUT" | jq -er '.tool_input.command' 2>/dev/null)"; then
  echo "BLOCKED: could not read the Bash command from the Codex hook payload." >&2
  exit 2
fi

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
case "$COMMAND" in
  "sudo "* | "mkfs "* | "dd "*)
    echo "BLOCKED: '$COMMAND' — privilege escalation or raw device access is forbidden." >&2
    exit 2
    ;;
esac

# Pipe-to-shell: block wget/curl piped into bash/sh — classic supply-chain vector.
if [[ "$COMMAND" =~ (wget|curl).*\|[[:space:]]*(bash|sh) ]]; then
  echo "BLOCKED: '$COMMAND' — pipe-to-shell execution is forbidden." >&2
  exit 2
fi

# ── Dangerous git commands ────────────────────────────────────────────────────

# Prefix-based patterns — match commands starting with these exact words.
case "$COMMAND" in
  # push / force | reset (all forms) | working-tree destruction |
  # stash destruction | history rewriting | tracked-file removal |
  # GC / recovery destruction | low-level ref manipulation
  "git push"          | "git push "* | \
  "git reset"         | "git reset "* | \
  "git clean -f"      | "git clean -f "* | \
  "git clean -fd"     | "git clean -fd "* | \
  "git branch -D"     | "git branch -D "* | \
  "git checkout --"   | "git checkout -- "* | \
  "git restore"       | "git restore "* | \
  "git switch"        | "git switch "* | \
  "git stash drop"    | "git stash drop "* | \
  "git stash clear"   | "git stash clear "* | \
  "git rebase"        | "git rebase "* | \
  "git commit --amend" | "git commit --amend "* | \
  "git rm"            | "git rm "* | \
  "git gc"            | "git gc "* | \
  "git prune"         | "git prune "* | \
  "git reflog expire" | "git reflog expire "* | \
  "git update-ref"    | "git update-ref "*)
    echo "BLOCKED: '$COMMAND' is forbidden by repo git policy. Work in the current tree only." >&2
    exit 2
    ;;
esac

# Substring patterns — catch variants like `git -c ... push --force` where the
# dangerous flag appears later in the command, not at the prefix.
case "$COMMAND" in
  *"push --force"* | *"push --force-with-lease"* | *"reset --hard"*)
    echo "BLOCKED: '$COMMAND' contains a forbidden git flag. Work in the current tree only." >&2
    exit 2
    ;;
esac

# Path-based checkout with a ref (e.g. `git checkout HEAD -- file`) — the prefix
# check only catches `git checkout --`, this catches `git checkout <ref> -- <path>`.
if [[ "$COMMAND" =~ ^git\ checkout\ .+\ --\  ]]; then
  echo "BLOCKED: '$COMMAND' is a path-based checkout that overwrites worktree files." >&2
  exit 2
fi

exit 0
