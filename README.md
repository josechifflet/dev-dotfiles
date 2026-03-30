# Secure Agentic Dev

Hardened configurations for AI coding agents. Drop-in configs that let Claude Code and Codex CLI read, stage, and commit — but never push, rewrite history, or destroy data.

[Claude Code](#claude-code) · [Codex CLI](#codex-cli) · [How it works](#how-it-works) · [Getting started](#getting-started)

## Overview

AI coding agents are powerful but dangerous when given unrestricted shell access. A single hallucinated `git push --force` or `git reset --hard` can cause irreversible damage.

This repo provides production-ready dotfile configurations for two major AI coding agents, enforcing a strict commit-only workflow through three independent safety layers.

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

Copy the relevant folder to your home directory:

```sh
# Claude Code
cp -r claude/.claude ~/

# Codex CLI
cp -r codex/.codex ~/
```

Or symlink via [GNU Stow](https://www.gnu.org/software/stow/):

```sh
# From the repo root
stow claude   # symlinks claude/.claude → ~/.claude
stow codex    # symlinks codex/.codex  → ~/.codex
```

> [!NOTE]
> The hook scripts require `jq` to parse tool call payloads. They **fail closed** — if `jq` is missing, all commands are blocked rather than silently allowed.

## Customization

- Add allowed commands — edit `permissions.allow` in `settings.json` (Claude) or add `prefix_rule(..., decision="allow")` in `default.rules` (Codex)
- Unblock a git command — remove it from all three layers (rules, deny-list, hook script) to maintain consistency
- Add rules — drop a `.md` file in `claude/.claude/rules/` or append to `codex/.codex/AGENTS.md`
- Plugins — edit `enabledPlugins` in `settings.json` (Claude) or configure in `config.toml` (Codex)

## Credits

- [This hook stops Claude Code running dangerous git commands](https://www.aihero.dev/this-hook-stops-claude-code-running-dangerous-git-commands) — original hook approach and git safety patterns
- [Trail of Bits claude-code-config](https://github.com/trailofbits/claude-code-config/blob/main/settings.json) — credential read deny-lists, shell config protections, and destructive command patterns
