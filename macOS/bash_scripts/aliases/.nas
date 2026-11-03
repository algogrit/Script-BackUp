# From macOS

export NAS_HOST="uttara.local"

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
  if ! mount | grep -q "$NAS_HOST/video"; then
    mkdir -p "$NAS_VIDEO"
    mount_smbfs "//$NAS_HOST/video" "$NAS_VIDEO"
  fi
}

ensure-downloads-mounted() {
  if ! mount | grep -q "$NAS_HOST/Downloads"; then
    mkdir -p "$NAS_DOWNLOADS"
    mount_smbfs "//$NAS_HOST/Downloads" "$NAS_DOWNLOADS"
  fi
}

ensure-home-mounted() {
  if ! mount | grep -q "$NAS_HOST/home"; then
    mkdir -p "$NAS_HOME"
    mount_smbfs "//$NAS_HOST/home" "$NAS_HOME"
  fi
}

ensure-codermana-drive-mounted() {
  if ! mount | grep -Fq " on $NAS_CODERMANA_DRIVE ("; then
    mkdir -p "$NAS_CODERMANA_DRIVE"
    mount_smbfs "//neo@$NAS_HOST/CoderMana%20Drive" "$NAS_CODERMANA_DRIVE"
  fi
}

export NAS_VIDEO="/Volumes/video"
export NAS_DOWNLOADS="/Volumes/Downloads"
export NAS_HOME="/Volumes/home"
# Keep this mount point inside the user home so a LaunchAgent can create it
# without administrator privileges. The remote SMB share remains CoderMana Drive.
export NAS_CODERMANA_DRIVE="$HOME/Volumes/CoderMana Drive"
export RAW_RECORDINGS="$NAS_HOME/Creator/Raw Recordings"
