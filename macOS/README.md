# macOS

These scripts are used everyday on a couple of macOSes to keep them in sync. Works well for my purposes, no guarantees though.

## Non-System files

- This `README.md`.
- `update_scripts.sh` - Use to backup the sytem to this folder.
- `restore_scripts.sh` - Copies scripts from this folder to the original, filesystem locations.

## Checklist

- Xcode
- Command Line Tools (`xcode-select --install`)
- Accept License (`sudo xcodebuild -license`)
- ssh (https://help.github.com/articles/generating-ssh-keys/; https://blog.g3rt.nl/upgrade-your-ssh-keys.html; `ssh-keygen -o -a 100 -t ed25519 -C your_email@example.com`)
- git (`git clone git@github.com:algogrit/Script-BackUp.git`)
- Brew (http://brew.sh/)
- Install Rosetta `sudo softwareupdate --install-rosetta`

[Tips & Tricks](https://gist.github.com/brandonb927/3195465)

## Other Settings

- Desktop & Screen Saver
  - Hot Corner (Put display to Sleep)
- Security & Privacy
  - Require Password (immediately)
- Keyboard (Fn keys)
- Trackpad
  - App Expose
- Accessibility
  - Pointer Control (Enable dragging with 3 fingers)
