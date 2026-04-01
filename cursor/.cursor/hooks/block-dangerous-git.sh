#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Block dangerous git commands in Cursor
# ==============================================================================
#
# Cursor beforeShellExecution hook. Receives JSON on stdin with shape:
#   { "command": "<full terminal command>", "cwd": "...", "sandbox": false }
# Must output JSON to stdout. Exit code 2 = deny.

# Fail closed — if jq is missing, block everything rather than silently allowing.
if ! command -v jq > /dev/null 2>&1; then
  echo '{"permission":"deny","agent_message":"BLOCKED: jq is required for hook evaluation but was not found."}' >&2
  exit 2
fi

INPUT="$(cat)"

# Extract the command string from Cursor's payload format.
if ! COMMAND="$(printf '%s' "$INPUT" | jq -er '.command' 2> /dev/null)"; then
  echo '{"permission":"deny","agent_message":"BLOCKED: could not read command from hook payload."}'
  exit 2
fi

# ── Destructive shell commands ────────────────────────────────────────────────

# Recursive force-delete: catch `rm` with both -r/-R (recursive) and -f (force)
# in any flag order (e.g. `rm -rf`, `rm -fr`, `rm --recursive --force`, etc.).
if echo "$COMMAND" | grep -qiE '(^|;[[:space:]]*|&&[[:space:]]*|[|][|][[:space:]]*|[|][[:space:]]*)rm[[:space:]]' \
  && echo "$COMMAND" | grep -qiE '(^|[[:space:]])-[a-zA-Z]*[rR]|--recursive' \
  && echo "$COMMAND" | grep -qiE '(^|[[:space:]])-[a-zA-Z]*[fF]|--force'; then
  echo "{\"permission\":\"deny\",\"agent_message\":\"BLOCKED: recursive force-delete detected in '$COMMAND'. Use trash instead of rm -rf.\"}"
  exit 2
fi

# Privilege escalation, raw disk write, filesystem format.
case "$COMMAND" in
  "sudo "* | "mkfs "* | "dd "*)
    echo "{\"permission\":\"deny\",\"agent_message\":\"BLOCKED: '$COMMAND' — privilege escalation or raw device access is forbidden.\"}"
    exit 2
    ;;
esac

# Pipe-to-shell: block wget/curl piped into bash/sh — classic supply-chain vector.
if [[ "$COMMAND" =~ (wget|curl).*\|[[:space:]]*(bash|sh) ]]; then
  echo "{\"permission\":\"deny\",\"agent_message\":\"BLOCKED: '$COMMAND' — pipe-to-shell execution is forbidden.\"}"
  exit 2
fi

# ── Dangerous git commands ────────────────────────────────────────────────────

# --- Prefix-based patterns ---
# Match commands starting with these exact words so that mentions inside
# heredoc/commit-message bodies don't trigger false positives.
case "$COMMAND" in
  "git push" | "git push "* | \
    "git reset" | "git reset "* | \
    "git clean -f" | "git clean -f "* | \
    "git clean -fd" | "git clean -fd "* | \
    "git branch -D" | "git branch -D "* | \
    "git checkout --" | "git checkout -- "* | \
    "git restore" | "git restore "* | \
    "git switch" | "git switch "* | \
    "git stash drop" | "git stash drop "* | \
    "git stash clear" | "git stash clear "* | \
    "git rebase" | "git rebase "* | \
    "git commit --amend" | "git commit --amend "* | \
    "git rm" | "git rm "* | \
    "git gc" | "git gc "* | \
    "git prune" | "git prune "* | \
    "git reflog expire" | "git reflog expire "* | \
    "git update-ref" | "git update-ref "*)
    echo "{\"permission\":\"deny\",\"agent_message\":\"BLOCKED: '$COMMAND' is forbidden by repo git policy. Work in the current tree only.\"}"
    exit 2
    ;;
esac

# --- Substring patterns ---
# Catch variants like `git -c ... push --force` where the dangerous flag
# appears later in the command, not at the prefix.
# Patterns ordered narrow-to-broad: force-with-lease checked before force.
case "$COMMAND" in
  *"push --force-with-lease"*)
    echo "{\"permission\":\"deny\",\"agent_message\":\"BLOCKED: '$COMMAND' contains a forbidden git flag. Work in the current tree only.\"}"
    exit 2
    ;;
  *"push --force"* | *"reset --hard"*)
    echo "{\"permission\":\"deny\",\"agent_message\":\"BLOCKED: '$COMMAND' contains a forbidden git flag. Work in the current tree only.\"}"
    exit 2
    ;;
esac

# Path-based checkout with a ref (e.g. `git checkout HEAD -- file`).
if [[ "$COMMAND" =~ ^git\ checkout\ .+\ --\  ]]; then
  echo "{\"permission\":\"deny\",\"agent_message\":\"BLOCKED: '$COMMAND' is a path-based checkout that overwrites worktree files.\"}"
  exit 2
fi

# Command is safe — allow it.
echo '{"permission":"allow"}'
exit 0
