# User preferences

# Development

- Remove dead code, never keep deprecated alongside new
- Simplest excellent viable solution, defer edge cases until evidence demands them
- No speculative features, premature optimization, or unnecessary abstraction
- Build for current requirements only, iterate later
- If plan exceeds 5 steps, challenge each one's necessity
- Leave the codebase better than you found it
- Map full solution architecture, internalize tasks, then build
- Get overview first, then drill into specific symbols
- Never generate files without integrating them into the codebase
- Follow existing code style and patterns
- Default to simplest solution, max 3 unresolved questions per plan
- No speculative "what if" scenarios or architecture philosophy debates

# Comments

- Almost over-comment, any engineer should understand the why behind every decision within minutes
- Step-by-step narration for all non-trivial functions
- Comment why this approach, why this value, business rule origin, non-obvious consequences, performance reasoning, gotchas, edge cases and why they occur
- Skip when code reads clearly, bad: `// increment counter`, good: `// retry count — circuit breaker trips at 5`

# Communication

- Extreme concision, sacrifice grammar for brevity
- Be direct, no explanations unless asked

# Markdown reports

- Never create unless explicitly requested
- If requested: ask placement first, max 50 lines, minimal syntax
- `#` headers, `-` lists, fenced code blocks with language, inline code for identifiers
- No tables, nested lists, badges, horizontal rules, format for IDE not GitHub

# Git

- No git operations unless explicitly requested. Read-only by default.
- Use GitHub CLI (`gh`) for all operations.
- Conventional Commits. Derive type, scope, and message from the actual diff.
- Never include "Generated with" or "Co-Authored-By" in commit messages.

## Forbidden commands

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
