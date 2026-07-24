# macOS

These scripts are used everyday on a couple of macOSes to keep them in sync. Works well for my purposes, no guarantees though.

## Non-System files

- This `README.md`.
- `update_scripts.sh` - Use to backup the sytem to this folder. Also snapshots iTerm2 prefs into `iTerm2/`, Claude Code settings into `Claude/` (`settings.json`, `keybindings.json`, `CLAUDE.md`, `commands/`, `agents/`, `skills/`, `hooks/`, and `plugins/{known_marketplaces,installed_plugins}.json`), Codex settings into `Codex/` (`config.toml`, `AGENTS.md`, `rules/`, `prompts/`, and user skills), and ramayan config into `ramayan/` (`config.toml`). `~/.claude.json` and Claude session/project state are intentionally excluded (they hold oauth/identity and machine-local history). Codex `auth.json`, `installation_id`, `history.jsonl`, `sessions/`, `cache/`, `.tmp/`, `tmp/`, `shell_snapshots/`, SQLite state, `models_cache.json`, `version.json`, `plugins/`, and `skills/.system` are also excluded.
- `restore_scripts.sh` - Copies scripts from this folder to the original, filesystem locations. Applies the System Settings tweaks (via `apply_system_settings.sh`), restores iTerm2 prefs + enables iTerm2's native custom-folder sync, restores Claude Code settings from `Claude/` into `~/.claude/`, restores Codex settings from `Codex/` into `~/.codex/`, and restores ramayan config from `ramayan/` into `~/.config/ramayan/`. Quit iTerm2 before running.
- `apply_system_settings.sh` - Applies the curated `defaults write` System Settings tweaks and login items. Also sets up Finder: Column view, new windows open `~/Downloads`, and the sidebar favourites (`~/Desktop`, `~/Developer`, `~`, `/tmp`, added only if missing). Called by `restore_scripts.sh`; can also be run on its own to re-apply just these settings. Also enforces Private Wi-Fi Address (off for "Om AX", on everywhere else) — this part needs `sudo` **and** the terminal to have Full Disk Access (System Settings > Privacy & Security > Full Disk Access), and fully applies after a reboot or Wi-Fi off/on.

## Checklist

These are the manual bootstrap steps; the rest (Rosetta, Xcode license, casks, App Store apps, settings, login items) is handled by `restore_scripts.sh`.

- Xcode
- Command Line Tools (`xcode-select --install`)
- Accept License (`sudo xcodebuild -license`) — auto-accepted by `restore_scripts.sh` once Xcode is installed
- ssh (https://help.github.com/articles/generating-ssh-keys/; https://blog.g3rt.nl/upgrade-your-ssh-keys.html; `ssh-keygen -o -a 100 -t ed25519 -C your_email@example.com`)
  - Github & Bitbucket
- git (`git clone git@github.com:algogrit/Script-BackUp.git`)
- Brew (http://brew.sh/)
  - Bootstrap the essentials up front (also in `brews.list`; installed early as a safety net)
  - `brew install mas bash`
- Install Rosetta `sudo softwareupdate --install-rosetta` — auto-installed by `restore_scripts.sh` on Apple Silicon

[Tips & Tricks](https://gist.github.com/brandonb927/3195465)

## Other Settings

- Desktop & Screen Saver
  - Hot Corner (Put display to Sleep)
- Security & Privacy
  - Require Password (immediately)
- Keyboard (Fn keys)
- Trackpad
  - App Expose
  - Tracking Speed: Fastest
- Accessibility
  - Pointer Control (Enable dragging with 3 fingers)
- Show Battery Percentage
- Login Items
  - Caffeine
  - Google Drive
  - iTerm2
  - MenuMeters
  - Raycast
  - Rectangle
  - Synology Drive Client
  - Usage
  - Zoho WorkDrive TrueSync
- Show in Taskbar
  - Displays (when one is connected)
  - Bluetooth
  - Volume
