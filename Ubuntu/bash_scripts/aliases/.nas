mount-video() {
  gio mount smb://uttara.local/video
}

mount-home() {
  gio mount smb://uttara.local/home
}

list-mounts() {
  gio mount -li
}

ensure-video-mounted() {
  if ! gio mount -l | grep -q 'smb://uttara.local/video'; then
    gio mount smb://uttara.local/video
  fi
}

ensure-home-mounted() {
  if ! gio mount -l | grep -q 'smb://uttara.local/home'; then
    gio mount smb://uttara.local/home
  fi
}

export GVFS_ROOT="/run/user/$(id -u)/gvfs"
export NAS_VIDEO="$GVFS_ROOT/smb-share:server=uttara.local,share=video"
export NAS_HOME="$GVFS_ROOT/smb-share:server=uttara.local,share=home"
export RAW_RECORDINGS="$NAS_VIDEO/Creator/Raw Recordings"
