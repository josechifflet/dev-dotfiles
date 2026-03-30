# Git

- No git operations unless explicitly requested, read-only by default
- Use GitHub CLI (`gh`) for all operations
- Conventional Commits, derive type/scope/message from the actual diff
- Never include "Generated with" or "Co-Authored-By" in commit messages

## forbidden commands

These are permanently blocked unless explicitly told otherwise. No exceptions.

- `git push`, `push --force`, `push --force-with-lease`
- `git reset` — all forms blocked (`--hard`, `--mixed`, `--soft`); moves HEAD, can orphan commits
- `git clean -fd`, `git clean -f`
- `git branch -D`
- `git checkout --` and `git checkout <ref> -- <path>` — overwrites worktree files
- `git restore` — all forms blocked; rewrites index or worktree regardless of flags
- `git switch` — all forms blocked; use `gh` workflows instead
- `git stash drop`, `git stash clear` — permanently destroys stashed work
- `git rebase`, `git rebase -i` — rewrites history, can drop commits
- `git commit --amend` — replaces previous commit, old becomes dangling
- `git rm` — removes tracked files from worktree and index
- `git gc`, `git prune`, `git reflog expire` — destroys recovery safety net
- `git update-ref` — low-level ref manipulation, can delete any ref
