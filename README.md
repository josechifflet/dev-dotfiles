# Secure Agentic Dev

Hardened configurations for AI coding agents. Drop-in configs that let Claude Code and Codex CLI read, stage, and commit — but never push, rewrite history, or destroy data.

[Claude Code](#claude-code) · [Cursor](#cursor) · [Codex CLI](#codex-cli) · [How it works](#how-it-works) · [Getting started](#getting-started)

## Overview

AI coding agents are powerful but dangerous when given unrestricted shell access. A single hallucinated `git push --force` or `git reset --hard` can cause irreversible damage.

This repo provides production-ready dotfile configurations for three major AI coding agents, enforcing a strict commit-only workflow through three independent safety layers.

## How it works

Every destructive operation is blocked at three layers simultaneously, so even a confused or adversarially-prompted agent cannot cause irreversible damage:

1. Rules & instructions — the agent is told which commands are forbidden and why
2. Permission deny-lists — the harness rejects matching commands before execution
3. PreToolUse hooks — shell scripts parse the command payload and hard-block on match

> [!IMPORTANT]
> All three layers must be bypassed for a destructive command to execute. Each layer works independently — if one fails, the others still catch it.

### Blocked commands

| Category | Commands |
|---|---|
| Git push | `git push`, `--force`, `--force-with-lease` |
| Git history | `git reset`, `rebase`, `commit --amend` |
| Git worktree | `git checkout --`, `restore`, `switch`, `clean -f` |
| Git deletion | `git branch -D`, `git rm`, `stash drop`, `stash clear` |
| Git recovery | `git gc`, `prune`, `reflog expire`, `update-ref` |
| Destructive shell | `rm -rf`, `rm -fr`, `sudo`, `mkfs`, `dd` |
| Pipe-to-shell | `curl \| bash`, `wget \| bash`, `curl \| sh`, `wget \| sh` |
| Shell config edit | `~/.bashrc`, `~/.zshrc`, `~/.bash_profile`, `~/.zprofile`, `~/.ssh/**` |
| Credential read | `~/.ssh`, `~/.gnupg`, `~/.aws`, `~/.azure`, `~/.config/gh`, `~/.git-credentials`, `~/.docker`, `~/.kube`, `~/.npmrc`, `~/.pypirc`, `~/.gem`, keychains, crypto wallets |

## Claude Code

```
claude/.claude/
├── CLAUDE.md                  # rule loader
├── settings.json              # permissions, hooks, env, plugins
├── statusline-command.sh      # custom TUI status line
├── hooks/
│   └── block-dangerous-git.sh # PreToolUse hook (regex-based)
└── rules/
    ├── comments.md            # commenting style
    ├── communication.md       # brevity rules
    ├── development.md         # coding philosophy
    ├── git.md                 # forbidden commands
    └── markdown.md            # output formatting
```

Key settings in `settings.json`:
- Telemetry disabled — `DISABLE_TELEMETRY`, `DISABLE_ERROR_REPORTING`, feedback survey off
- Permissions — read-only git + staging allowed, all destructive ops denied
- Hook — `block-dangerous-git.sh` fires on every Bash tool call
- Attribution blanked — no "Generated with" or "Co-Authored-By" trailers

## Cursor

```
cursor/.cursor/
├── hooks.json                 # hook registration (beforeShellExecution)
└── hooks/
    └── block-dangerous-git.sh # shell hook (JSON stdin/stdout protocol)
```

Rules are generated at sync time from `claude/.claude/rules/*.md` — each `.md` is converted to a `.mdc` file with YAML frontmatter injected. This keeps claude as the single source of truth for rules.

Key differences from Claude Code hook:
- Cursor uses a JSON stdin/stdout protocol (`{"permission":"allow"}` or `{"permission":"deny","agent_message":"..."}`)
- Hook is registered as `beforeShellExecution` in `hooks.json`
- Rules use `.mdc` format with `alwaysApply: true` frontmatter

## Codex CLI

```
codex/.codex/
├── AGENTS.md                  # combined behavioral rules
├── config.toml                # model, sandbox, privacy settings
├── hooks.json                 # hook registration
├── hooks/
│   └── block-dangerous-git.sh # PreToolUse hook (case-based)
└── rules/
    └── default.rules          # prefix_rule exec policy
```

Key settings in `config.toml`:
- All telemetry off — analytics, feedback, OTEL exporters all disabled
- Sandbox — `workspace-write` mode (can write files, cannot escape workspace)
- Exec policy — `default.rules` enumerates every allowed and forbidden command with justifications
- Attribution blanked — `commit_attribution = ""`

## Getting started

### Option A: sync scripts (recommended)

The sync scripts use a split strategy — symlinks for files that benefit from live editing (settings, hooks), copies for files that would cause duplicate context loading if symlinked (CLAUDE.md, rules). This prevents AI agents from loading config twice when working inside this repo.

```sh
# Claude Code — selective symlinks + copies to ~/.claude/
bin/sync-claude

# Cursor — symlinks for hooks, generated .mdc rules from claude sources to ~/.cursor/
bin/sync-cursor

# Codex CLI — selective symlinks + copies to ~/.codex/
bin/sync-codex
```

To remove managed entries:

```sh
bin/sync-claude --unlink
bin/sync-cursor --unlink
bin/sync-codex --unlink
```

Preview without writing:

```sh
bin/sync-claude --dry-run
bin/sync-cursor --dry-run
bin/sync-codex --dry-run
```

### Option B: plain copy

```sh
cp -r claude/.claude ~/   # Claude Code
cp -r cursor/.cursor ~/   # Cursor
cp -r codex/.codex ~/     # Codex CLI
```

### Option C: GNU Stow

```sh
# From the repo root — works but causes duplicate context loading when
# editing inside this repo (AI agents resolve symlinks)
stow claude
stow codex
```

> [!NOTE]
> The hook scripts require `jq` to parse tool call payloads. They **fail closed** — if `jq` is missing, all commands are blocked rather than silently allowed.

## Customization

- Add allowed commands — edit `permissions.allow` in `settings.json` (Claude) or add `prefix_rule(..., decision="allow")` in `default.rules` (Codex)
- Unblock a git command — remove it from all three layers (rules, deny-list, hook script) to maintain consistency
- Add rules — drop a `.md` file in `claude/.claude/rules/` (cursor `.mdc` rules are auto-generated on next `bin/sync-cursor`) or append to `codex/.codex/AGENTS.md`
- Plugins — edit `enabledPlugins` in `settings.json` (Claude) or configure in `config.toml` (Codex)

## Credits

- [This hook stops Claude Code running dangerous git commands](https://www.aihero.dev/this-hook-stops-claude-code-running-dangerous-git-commands) — original hook approach and git safety patterns
- [Trail of Bits claude-code-config](https://github.com/trailofbits/claude-code-config/blob/main/settings.json) — credential read deny-lists, shell config protections, and destructive command patterns
