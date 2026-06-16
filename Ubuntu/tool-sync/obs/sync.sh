#!/usr/bin/env bash
#
# Cross-platform OBS Studio config backup / restore.
#
#   ./sync.sh backup     # live OBS config  ->  repo  (sanitized, portable)
#   ./sync.sh restore    # repo             ->  live OBS config (re-localized)
#
# The backup is stored ONCE at the repo root in OBS/ so the same config is
# shared across machines/OSes. Paths under $HOME are tokenized to __OBS_HOME__
# on backup and expanded back to the local $HOME on restore, so recording
# directories and scene media paths follow you across macOS/Linux/Windows.
#
# Browser-source cache (obs-browser/) and all logs/locks/leveldb churn are
# deliberately NOT backed up -- OBS regenerates them and they only bloat the
# repo and break restores.

set -euo pipefail
shopt -s nullglob

MODE="${1:-backup}"
HOME_TOKEN="__OBS_HOME__"

# ---------------------------------------------------------------------------
# Locate the repo and the shared store (CWD-independent).
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
    :
else
    # Fallback: walk up until we find a .git, else assume two levels up.
    REPO_ROOT="$SCRIPT_DIR"
    while [ "$REPO_ROOT" != "/" ] && [ ! -d "$REPO_ROOT/.git" ]; do
        REPO_ROOT="$(dirname "$REPO_ROOT")"
    done
    [ -d "$REPO_ROOT/.git" ] || REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
fi
STORE="$REPO_ROOT/OBS"

# ---------------------------------------------------------------------------
# Detect the live OBS config directory for this OS / install method.
# ---------------------------------------------------------------------------
detect_obs_dir() {
    # Honour an explicit override.
    if [ -n "${OBS_CONFIG_DIR:-}" ]; then
        printf '%s\n' "$OBS_CONFIG_DIR"
        return
    fi
    local candidates=(
        "$HOME/Library/Application Support/obs-studio"                       # macOS
        "$HOME/.config/obs-studio"                                           # Linux native
        "$HOME/.var/app/com.obsproject.Studio/config/obs-studio"            # Linux Flatpak
        "$HOME/snap/obs-studio/current/.config/obs-studio"                  # Linux Snap
        "${APPDATA:-$HOME/AppData/Roaming}/obs-studio"                      # Windows (Git Bash)
    )
    local d
    for d in "${candidates[@]}"; do
        [ -d "$d" ] && { printf '%s\n' "$d"; return; }
    done
    # Nothing exists yet (e.g. fresh install before first launch): on restore
    # we still need a target, so fall back to the OS-default location.
    case "$(uname -s)" in
        Darwin) printf '%s\n' "$HOME/Library/Application Support/obs-studio" ;;
        *)      printf '%s\n' "$HOME/.config/obs-studio" ;;
    esac
}
OBS_DIR="$(detect_obs_dir)"

# Sub-trees that hold meaningful, portable config.
SYNC_PATHS=(basic/scenes basic/profiles plugin_config)

# Junk we never want in the repo (cache, logs, locks, leveldb, browser cache).
EXCLUDES=(
    --exclude=obs-browser/
    --exclude='*.log'
    --exclude='*LOG*'
    --exclude='*.bak'
    --exclude=Cache/
    --exclude=GPUCache/
    --exclude='Code Cache/'
    --exclude=DawnGraphiteCache/
    --exclude=DawnWebGPUCache/
    --exclude=ShaderCache/
    --exclude=GrShaderCache/
    --exclude='Service Worker/'
    --exclude='Session Storage/'
    --exclude='Local Storage/'
    --exclude=blob_storage/
    --exclude='*.ldb'
    --exclude=LOCK
    --exclude=CURRENT
    --exclude='MANIFEST-*'
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
is_obs_running() {
    # Match the OBS app binary only (obs / OBS / obs64) -- NOT background
    # daemons like the virtual-camera system extension, which would otherwise
    # false-positive and wrongly block restores.
    pgrep -x obs >/dev/null 2>&1 || pgrep -x OBS >/dev/null 2>&1 \
        || pgrep -x obs64 >/dev/null 2>&1
}

# Escape a string for safe use as a sed replacement / pattern.
sed_escape() { printf '%s' "$1" | sed -e 's/[\/&|]/\\&/g'; }

# Rewrite literal $from -> $to in every *.ini / *.json under $dir (in place).
rewrite_paths() {
    local dir="$1" from="$2" to="$3"
    local efrom eto f
    efrom="$(sed_escape "$from")"
    eto="$(sed_escape "$to")"
    while IFS= read -r -d '' f; do
        sed -i.tmp "s|$efrom|$eto|g" "$f" && rm -f "$f.tmp"
    done < <(find "$dir" \( -name '*.ini' -o -name '*.json' \) -type f -print0 2>/dev/null)
}

# Drop machine-specific keys that should not travel between machines/OSes.
sanitize_global_ini() {
    local f="$1"
    [ -f "$f" ] || return 0
    sed -i.tmp -E '/^(Renderer|InstallGUID|MacOSPermissionsDialogLastShown)=/d' "$f"
    rm -f "$f.tmp"
}

# ---------------------------------------------------------------------------
# Backup:  live OBS  ->  repo (sanitized + tokenized)
# ---------------------------------------------------------------------------
do_backup() {
    if [ ! -d "$OBS_DIR" ]; then
        echo "!! OBS config dir not found: $OBS_DIR" >&2
        exit 1
    fi
    if is_obs_running; then
        echo "!! OBS appears to be running -- config DBs may be mid-write." >&2
        echo "   Quit OBS and re-run for a clean backup." >&2
    fi

    echo "=== OBS backup ==="
    echo "Source: $OBS_DIR"
    echo "Store : $STORE"
    [ -d "$OBS_DIR/plugins" ] && { echo "Plugins:"; ls "$OBS_DIR/plugins"; }

    mkdir -p "$STORE"
    local p
    for p in "${SYNC_PATHS[@]}"; do
        [ -d "$OBS_DIR/$p" ] || { echo ">> skip (absent): $p"; continue; }
        echo ">> backup $p"
        mkdir -p "$STORE/$p"
        rsync -a --delete "${EXCLUDES[@]}" "$OBS_DIR/$p/" "$STORE/$p/"
    done

    if [ -f "$OBS_DIR/global.ini" ]; then
        cp "$OBS_DIR/global.ini" "$STORE/global.ini"
        sanitize_global_ini "$STORE/global.ini"
        echo ">> backup global.ini"
    fi

    # Make absolute home paths portable.
    rewrite_paths "$STORE" "$HOME" "$HOME_TOKEN"
    echo "All done. (paths under \$HOME tokenized as $HOME_TOKEN)"
}

# ---------------------------------------------------------------------------
# Restore:  repo  ->  live OBS (re-localized to this machine)
# ---------------------------------------------------------------------------
do_restore() {
    if [ ! -d "$STORE" ]; then
        echo "!! No backup found at $STORE" >&2
        exit 1
    fi
    if is_obs_running; then
        echo "!! OBS is running. Quit it before restoring (it would overwrite" >&2
        echo "   your config on exit and clobber the restore). Aborting." >&2
        exit 1
    fi

    echo "=== OBS restore ==="
    echo "Store : $STORE"
    echo "Target: $OBS_DIR"
    mkdir -p "$OBS_DIR"

    # Snapshot current live config before we touch it.
    if [ -d "$OBS_DIR" ] && [ -n "$(ls -A "$OBS_DIR" 2>/dev/null)" ]; then
        local backup="$OBS_DIR.pre-restore.$(date +%Y%m%d-%H%M%S)"
        cp -a "$OBS_DIR" "$backup"
        echo ">> saved current config to: $backup"
    fi

    local p
    for p in "${SYNC_PATHS[@]}"; do
        [ -d "$STORE/$p" ] || { echo ">> skip (absent): $p"; continue; }
        echo ">> restore $p"
        mkdir -p "$OBS_DIR/$p"
        rsync -a --delete "${EXCLUDES[@]}" "$STORE/$p/" "$OBS_DIR/$p/"
    done

    if [ -f "$STORE/global.ini" ]; then
        cp "$STORE/global.ini" "$OBS_DIR/global.ini"
        echo ">> restore global.ini"
    fi

    # Re-localize tokenized paths to this machine's $HOME.
    rewrite_paths "$OBS_DIR" "$HOME_TOKEN" "$HOME"
    echo "All done. (paths re-localized to $HOME)"
}

case "$MODE" in
    backup)  do_backup  ;;
    restore) do_restore ;;
    *) echo "Usage: $0 {backup|restore}" >&2; exit 1 ;;
esac
