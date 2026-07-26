# From macOS

## Credential tip — store credentials once with:
# security add-internet-password -s uttara.local -a youruser -w yourpassword

mount-video() {
  open 'smb://uttara.local/video'
}

mount-downloads() {
  open 'smb://uttara.local/Downloads'
}

mount-home() {
  open 'smb://uttara.local/home'
}

list-mounts() {
  mount | grep 'uttara.local'
}

ensure-video-mounted() {
  if ! mount | grep -q 'uttara.local/video'; then
    mkdir -p "$NAS_VIDEO"
    mount_smbfs '//uttara.local/video' "$NAS_VIDEO"
  fi
}

ensure-downloads-mounted() {
  if ! mount | grep -q 'uttara.local/Downloads'; then
    mkdir -p "$NAS_DOWNLOADS"
    mount_smbfs '//uttara.local/Downloads' "$NAS_DOWNLOADS"
  fi
}

ensure-home-mounted() {
  if ! mount | grep -q 'uttara.local/home'; then
    mkdir -p "$NAS_HOME"
    mount_smbfs '//uttara.local/home' "$NAS_HOME"
  fi
}

export NAS_VIDEO="/Volumes/video"
export NAS_DOWNLOADS="/Volumes/Downloads"
export NAS_HOME="/Volumes/home"
export RAW_RECORDINGS="$NAS_HOME/Creator/Raw Recordings"
