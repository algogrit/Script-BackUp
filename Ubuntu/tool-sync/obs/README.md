# OBS Studio sync

Cross-platform backup/restore of OBS Studio config. One `sync.sh` is shared by
every machine; the backup itself lives once at the repo root in `shared/OBS/` and is
sanitized so it restores cleanly on macOS, Linux, or Windows.

## Usage

```sh
./tool-sync/obs/sync.sh backup     # live OBS config -> repo/shared/OBS/
./tool-sync/obs/sync.sh restore    # repo/shared/OBS/      -> live OBS config
```

(`backup` is run from each platform's `update_scripts.sh`; `restore` from
`restore_scripts.sh`.)

**Quit OBS before either operation** — OBS rewrites its config on exit, so a
restore done while it is running gets clobbered. The script refuses to restore
while OBS is running and warns on backup.

## What is synced

- `basic/scenes/` — scene collections
- `basic/profiles/` — profiles (encoder/output/video/audio settings)
- `plugin_config/` — e.g. `rtmp-services`, `obs-websocket`, `text-freetype2`
- `global.ini`

## What is NOT synced (deliberately)

`obs-browser/` (the Chromium browser-source cache), all `*.log`, lock files,
and leveldb/cache churn. OBS regenerates these; keeping them only bloated the
repo and broke restores.

## Cross-platform handling

- **Paths under `$HOME`** (recording dirs, scene media) are stored as the token
  `__OBS_HOME__` and expanded to the local `$HOME` on restore, so they follow
  you across machines and OSes.
- `global.ini` has `Renderer`, `InstallGUID`, and the macOS permissions flag
  stripped, so each OS picks its own.
- Auto-detected config locations: macOS `~/Library/Application Support`,
  Linux native `~/.config`, Flatpak `~/.var/app/...`, Snap `~/snap/...`,
  Windows `%APPDATA%`. Override with `OBS_CONFIG_DIR=/path`.

### Known limits (degrade gracefully)

Encoder names (`apple_h264`, `CoreAudio_AAC`) and the audio monitoring-device
GUID are inherently machine-specific. OBS falls back to a working default when
they are unavailable, but you may want to re-pick the encoder/monitor on a new
machine. Absolute paths **outside** `$HOME` are not translated.

A timestamped copy of the previous live config is saved next to the OBS config
dir (`obs-studio.pre-restore.<timestamp>`) before each restore.
