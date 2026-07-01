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

# Keyboard: Key Repeat = Fast (slider max) and Delay Until Repeat = Short (slider max).
# Lower numbers are faster; these match the rightmost slider positions in System Settings.
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

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

# Control Center: show Bluetooth, Volume (Sound) and Displays in the menu bar.
# Module int values: 8 = Always Show in Menu Bar, 18 = Show When Active, 2 = Don't Show.
# "Displays (when one is connected)" == Show When Active.
# NOTE: like BatteryShowPercentage/Wi-Fi, these keys are macOS-version-specific; if one
# doesn't take, set it by hand and read the live value back with
# `defaults -currentHost read com.apple.controlcenter`, then hardcode it here.
defaults -currentHost write com.apple.controlcenter Bluetooth -int 8
defaults -currentHost write com.apple.controlcenter Sound     -int 8
defaults -currentHost write com.apple.controlcenter Display   -int 18

# Private Wi-Fi Address (MAC randomization): keep it ON everywhere except the
# "Om AX" network, which is turned OFF.
#   - Per-SSID lives in com.apple.wifi.known-networks.plist as a string key
#     PrivateMACAddressModeUserSetting ("off" | "rotating" | "static"); "On" = rotating.
#   - The system default lives in airport.preferences.plist as an int key
#     PrivateMACAddressModeSystemSetting (0 = On, 1 = Off); we pin it to 0.
# Both plists are root-owned AND TCC-protected, so this needs `sudo` *and* the
# terminal running this script must have Full Disk Access (System Settings >
# Privacy & Security > Full Disk Access). Without FDA the read is denied and the
# block self-skips. Values are version-specific (verified on macOS Sequoia).
echo "\033[1;31mApplying Private Wi-Fi Address settings (Om AX off, rest on)...\033[0m"
sudo python3 - <<'PY' || echo "  Skipped Wi-Fi settings (needs sudo + Full Disk Access for this terminal)."
import plistlib, sys

OFF_SSID = "Om AX"  # the one network whose Private Wi-Fi Address stays OFF
KN = "/Library/Preferences/com.apple.wifi.known-networks.plist"
AP = "/Library/Preferences/SystemConfiguration/com.apple.airport.preferences.plist"
PREFIX = "wifi.network.ssid."

try:
    with open(KN, "rb") as f:
        kn = plistlib.load(f)
except PermissionError:
    print("  Full Disk Access missing for this terminal; cannot edit Wi-Fi settings.")
    sys.exit(1)

changed = False
saw_off_ssid = False
for key, entry in kn.items():
    if not key.startswith(PREFIX) or not isinstance(entry, dict):
        continue
    ssid = key[len(PREFIX):]
    want = "off" if ssid == OFF_SSID else "rotating"
    saw_off_ssid = saw_off_ssid or ssid == OFF_SSID
    if entry.get("PrivateMACAddressModeUserSetting") != want:
        entry["PrivateMACAddressModeUserSetting"] = want
        changed = True
        print(f"  {ssid}: Private Wi-Fi Address -> {'Off' if want == 'off' else 'On'}")
if not saw_off_ssid:
    print(f'  Note: "{OFF_SSID}" is not a known network yet; nothing to turn off.')
if changed:
    with open(KN, "wb") as f:
        plistlib.dump(kn, f, fmt=plistlib.FMT_BINARY)

# System default: pin to 0 (On) so unknown/future networks randomize by default.
with open(AP, "rb") as f:
    ap = plistlib.load(f)
if ap.get("PrivateMACAddressModeSystemSetting") != 0:
    ap["PrivateMACAddressModeSystemSetting"] = 0
    with open(AP, "wb") as f:
        plistlib.dump(ap, f, fmt=plistlib.FMT_BINARY)
    print("  System default: Private Wi-Fi Address -> On")
PY
# Reload the Wi-Fi daemon so it re-reads the plist (full effect after a reboot or
# Wi-Fi off/on; without this the daemon keeps the old cached value).
sudo killall -HUP airportd 2>/dev/null || true
echo "  NOTE: Private Wi-Fi Address changes fully apply after a REBOOT or Wi-Fi off/on."

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
