#!/usr/bin/env bash
#
# Apply the curated macOS System Settings tweaks and login items.
#
# Called by restore_scripts.sh during a full restore, but can also be run on its
# own to re-apply just these settings (e.g. after a macOS update resets them):
#
#   cd ~/Script-BackUp/macOS && ./apply_system_settings.sh
#
# Kept lenient (no `set -e`): individual steps guard themselves with `|| true`.

echo "\033[1;31mApplying macOS System Settings...\033[0m"

# Desktop & Screen Saver > Hot Corner: bottom-left = Put Display to Sleep (action 10)
defaults write com.apple.dock wvous-bl-corner -int 10
defaults write com.apple.dock wvous-bl-modifier -int 0

# Keyboard: use F1, F2, etc. as standard function keys (press Fn for special features)
defaults write NSGlobalDomain com.apple.keyboard.fnState -bool true

# Trackpad: tap to click (driver domains + NSGlobalDomain mirror; -currentHost holds it at login)
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# Trackpad: App Expose (four-finger swipe down). macOS routes gestures off the NSGlobalDomain
# com.apple.trackpad.* mirror keys, so each driver-domain key below is mirrored there too.
defaults write com.apple.dock showAppExposeGestureEnabled -int 1
defaults write com.apple.AppleMultitouchTrackpad TrackpadFourFingerVertSwipeGesture -int 2
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerVertSwipeGesture -int 2
defaults write NSGlobalDomain com.apple.trackpad.fourFingerVertSwipeGesture -int 2

# Trackpad: Tracking Speed = Fastest (slider max = 3.0)
defaults write NSGlobalDomain com.apple.trackpad.scaling -float 3.0

# Accessibility > Pointer Control: enable dragging with three fingers.
# macOS cannot bind three fingers to both swipe and drag, so the three-finger swipe
# gestures must be turned off or the drag never engages (System Settings does this for you).
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -bool true
defaults write NSGlobalDomain com.apple.trackpad.threeFingerDragGesture -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerHorizSwipeGesture -int 0
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerHorizSwipeGesture -int 0
defaults write NSGlobalDomain com.apple.trackpad.threeFingerHorizSwipeGesture -int 0
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerVertSwipeGesture -int 0
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerVertSwipeGesture -int 0
defaults write NSGlobalDomain com.apple.trackpad.threeFingerVertSwipeGesture -int 0

# Security & Privacy: require password immediately after sleep / screen saver.
# Modern macOS ignores the legacy `defaults write com.apple.screensaver askForPassword`,
# so use the supported, version-agnostic sysadminctl. NOTE: this prompts for the account password.
sysadminctl -screenLock immediate -password -

# Control Center: show battery percentage in the menu bar.
# Tahoe/Big Sur+ moved this out of the legacy menu extra into Control Center,
# a per-host key applied by restarting ControlCenter (see killall below).
defaults -currentHost write com.apple.controlcenter BatteryShowPercentage -bool true

killall cfprefsd 2>/dev/null || true
killall Dock SystemUIServer ControlCenter 2>/dev/null || true
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u 2>/dev/null || true
echo "  IMPORTANT: keyboard Fn and trackpad changes only apply after a LOG OUT / RESTART."

# Login Items: open these apps at login (only if installed). Uses System Events'
# shared login-item list (System Settings > General > Login Items > "Open at Login").
# The first run may prompt once for Automation permission to control System Events.
echo "\033[1;31mAdding login items...\033[0m"
LOGIN_ITEMS=(
  "/Applications/Caffeine.app"
  "/Applications/Google Drive.app"
  "/Applications/iTerm.app"
  "/Applications/MenuMeters.app"
  "/Applications/Raycast.app"
  "/Applications/Rectangle.app"
  "/Applications/Synology Drive Client.app"
  "/Applications/Usage.app"
  "/Applications/Zoho WorkDrive TrueSync.app"
)
for app in "${LOGIN_ITEMS[@]}"; do
  if [ -d "$app" ]; then
    name="$(basename "$app" .app)"
    osascript <<EOF 2>/dev/null
tell application "System Events"
  if not (exists login item "$name") then
    make login item at end with properties {path:"$app", hidden:false}
  end if
end tell
EOF
  else
    echo "  Skipping login item (not installed): $app"
  fi
done
