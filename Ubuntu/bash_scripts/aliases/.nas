mount-video() {
  /usr/bin/gio mount smb://uttara.local/video
}

mount-home() {
  /usr/bin/gio mount smb://uttara.local/home
}

list-mounts() {
  /usr/bin/gio mount -li
}

ensure-video-mounted() {
  if ! /usr/bin/gio mount -l | grep -q 'smb://uttara.local/video'; then
    /usr/bin/gio mount smb://uttara.local/video
  fi
}

ensure-home-mounted() {
  if ! /usr/bin/gio mount -l | grep -q 'smb://uttara.local/home'; then
    /usr/bin/gio mount smb://uttara.local/home
  fi
}

export GVFS_ROOT="/run/user/$(id -u)/gvfs"
export NAS_VIDEO="$GVFS_ROOT/smb-share:server=uttara.local,share=video"
export NAS_HOME="$GVFS_ROOT/smb-share:server=uttara.local,share=home"
export RAW_RECORDINGS="$NAS_HOME/Creator/Raw Recordings"
