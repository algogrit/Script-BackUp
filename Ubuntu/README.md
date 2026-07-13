# Ubuntu

Scripts/settings synced on/from Ubuntu.

- `update_scripts.sh` - Use to backup the system to this folder. Also snapshots Claude Code settings
  into `Claude/` (`settings.json`, `keybindings.json`, `CLAUDE.md`, `commands/`, `agents/`,
  `skills/`, `hooks/`, and `plugins/{known_marketplaces,installed_plugins}.json`) and Codex settings
  into `Codex/` (`config.toml`, `AGENTS.md`, `rules/`, `prompts/`, and user skills).
  `~/.claude.json` and Claude session/project state are intentionally excluded (they hold
  oauth/identity and machine-local history). Codex `auth.json`, `installation_id`, `history.jsonl`,
  `sessions/`, `cache/`, `.tmp/`, `tmp/`, `shell_snapshots/`, SQLite state, `models_cache.json`,
  `version.json`, `plugins/`, and `skills/.system` are also excluded.
- `restore_scripts.sh` - Copies scripts from this folder to their original filesystem locations,
  including Claude Code settings from `Claude/` into `~/.claude/` and Codex settings from `Codex/`
  into `~/.codex/`.

Both are allowlists: only the files named above are copied, so new session/cache directories added
by a future Claude or Codex release cannot silently leak into the repo.

To compare and converge these configs against the macOS machine, see `shared/bin/ai-config-sync.sh`.
