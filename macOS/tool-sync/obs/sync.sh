#!/usr/bin/env bash

# OBS Snap config path
OBS_DIR="$HOME/Library/Application Support/obs-studio"
PLUGIN_DIR="$HOME/Library/Application Support/obs-studio/plugins"
SYNC_DIR="obs"

mkdir -p $SYNC_DIR

MODE=${1:-backup}  # backup or restore

echo "=== OBS Plugin List ==="
if [ -d "$PLUGIN_DIR" ]; then
    ls "$PLUGIN_DIR"
else
    echo "Plugin directory not found at $PLUGIN_DIR"
fi

echo
echo "=== OBS Sync Mode: $MODE ==="
echo "OBS Config Dir: $OBS_DIR"
echo "Sync Dir: $SYNC_DIR"

sync_path() {
    local path="$1"
    local name="$2"
    echo ">> Syncing $name..."
    if [ "$MODE" == "backup" ]; then
        mkdir -p "$SYNC_DIR/$path/"
        rsync -av --delete "$OBS_DIR/$path/" "$SYNC_DIR/$path/"
    elif [ "$MODE" == "restore" ]; then
        rsync -av --delete "$SYNC_DIR/$path/" "$OBS_DIR/$path/"
    else
        echo "Invalid mode: $MODE"
        exit 1
    fi
}

# Sync profiles
sync_path "basic/profiles" "Profiles"

# Sync scenes
sync_path "basic/scenes" "Scenes"

# Sync plugin configs
sync_path "plugin_config" "Plugin Config"

# Sync global.ini (top-level file)
if [ "$MODE" == "backup" ]; then
    cp "$OBS_DIR/global.ini" "$SYNC_DIR/global.ini"
else
    cp "$SYNC_DIR/global.ini" "$OBS_DIR/global.ini"
fi
echo ">> Synced global.ini"

rm -f $SYNC_DIR/**/LOG*
rm -f $SYNC_DIR/**/*.log

echo "All done."
