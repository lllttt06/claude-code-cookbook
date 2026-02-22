# Linking Policy for Codex/Claude Shared Assets

## Canonical Directories
- Canonical command directory: `~/.claude/commands`
- Canonical skill directory: `~/.claude/skills`

`~/.codex` keeps compatibility paths as symlinks:
- `~/.codex/prompts -> ~/.claude/commands`
- `~/.codex/skills -> ~/.claude/skills`

## Editing Rule
- Add/update command markdown files in `~/.claude/commands`.
- Add/update shared skills in `~/.claude/skills`.
- Do not edit command/skill content via `~/.codex/*` paths directly unless you intentionally rely on symlinked behavior.

## Scope Excluded from Linking
The following remain tool-specific and should not be linked:
- auth/config/runtime files
- history, logs, caches, sessions, telemetry

Examples:
- `~/.codex/history.jsonl`
- `~/.claude/history.jsonl`

## Rollback
1. Remove symlinks:
   - `~/.codex/prompts`
   - `~/.codex/skills`
2. Restore backed-up directories from:
   - `~/dotfiles/claude-code-cookbook/backups/link-migration-*/`
