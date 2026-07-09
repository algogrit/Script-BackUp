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

# Keyboard > Input Sources: enable "Hindi - Transliteration" alongside U.S.
# (phonetic Devanagari: typing "namaste" produces नमस्ते). The input source is
# provided by /System/Library/Input Methods/TransliterationIM.app.
#
# NOTE: a raw `defaults write com.apple.HIToolbox AppleEnabledInputSources -array-add`
# only sets the preference — it does NOT register the source with the live Text Input
# System, so an input *method/mode* (unlike a plain com.apple.keylayout.* layout) never
# shows up in System Settings or the input menu, even after a restart. The reliable fix
# is Apple's Text Input Services API (TISEnableInputSource) — the same call System
# Settings makes. Enabling an already-enabled source is a harmless no-op (idempotent).
#
# IMPORTANT: both the PARENT input method (com.apple.inputmethod.TransliterationIM)
# and the .hi input MODE must be enabled. With only the mode enabled, TIS reports it
# enabled=true yet it never appears in the input menu, because macOS hides an input
# mode whose parent input method is disabled.
if command -v swift >/dev/null 2>&1; then
  swift - <<'SWIFT' && echo "  Enabled Hindi (Transliteration) input source." \
                    || echo "  WARNING: could not enable Hindi input source."
import Carbon
func enable(_ id: String) -> Bool {
    let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
    guard let list = TISCreateInputSourceList(filter, true)?.takeRetainedValue()
            as? [TISInputSource] else { return false }
    // The parent IM can appear under more than one source kind; enable every match.
    var ok = false
    for src in list where TISEnableInputSource(src) == noErr { ok = true }
    return ok
}
// Parent first: the .hi mode stays invisible while its input method is disabled.
guard enable("com.apple.inputmethod.TransliterationIM"),
      enable("com.apple.inputmethod.TransliterationIM.hi") else {
    FileHandle.standardError.write("could not enable input source\n".data(using: .utf8)!)
    exit(1)
}
exit(0)
SWIFT
else
  # Fallback for machines without a Swift toolchain: write the preference directly.
  # (May require a log out / login before the source registers — see note above.)
  enabled_sources=$(defaults read com.apple.HIToolbox AppleEnabledInputSources 2>/dev/null)
  # Parent input method entry (required, or the Hindi mode below stays hidden).
  # defaults prints each dict across several lines, so pair the Bundle ID line
  # with the InputSourceKind line that follows it.
  if ! echo "$enabled_sources" | grep -A2 'Bundle ID.*TransliterationIM' \
       | grep -q '"Keyboard Input Method"'; then
    defaults write com.apple.HIToolbox AppleEnabledInputSources -array-add \
      '{ "Bundle ID" = "com.apple.inputmethod.TransliterationIM"; InputSourceKind = "Keyboard Input Method"; }'
  fi
  if ! echo "$enabled_sources" | grep -q "com.apple.inputmethod.TransliterationIM.hi"; then
    defaults write com.apple.HIToolbox AppleEnabledInputSources -array-add \
      '{ "Bundle ID" = "com.apple.inputmethod.TransliterationIM"; "Input Mode" = "com.apple.inputmethod.TransliterationIM.hi"; InputSourceKind = "Input Mode"; }'
    echo "  Added Hindi input source via defaults (no swift; may require logout to register)."
  else
    echo "  Hindi (Transliteration) input source already enabled."
  fi
fi

# Keyboard: show the Input menu (flag/globe) in the menu bar, so the active layout is
# visible and switchable from there in addition to the Fn/Globe toggle below.
defaults write com.apple.TextInputMenu visible -bool true

# Keyboard: "Press 🌐 (Fn/Globe) key to" = Change Input Source, so Fn toggles
# between English and Hindi. Value 1 = Change Input Source (0 = Emoji & Symbols /
# default, 2/3 = Dictation / Do Nothing); verified on macOS Tahoe. NOTE: applied
# via `defaults`, this key only takes effect after a RESTART. (Independent of
# com.apple.keyboard.fnState above, which only affects the F1–F12 function-key row.)
defaults write com.apple.HIToolbox AppleFnUsageType -int 1

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

# Finder: default new windows to Column view (clmv; other values: icnv, Nlsv, glyv)
defaults write com.apple.finder FXPreferredViewStyle -string "clmv"

# Finder: new windows open ~/Downloads. PfLo = "Other..." (an arbitrary path), whose
# location comes from NewWindowTargetPath as a file:// URL with a trailing slash.
defaults write com.apple.finder NewWindowTarget -string "PfLo"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/Downloads/"

# Finder > Sidebar ("left bar") favourites: Desktop, Developer, home, /tmp.
#
# NOTE: there is no `defaults` key for this. The favourites are bookmark-encoded blobs
# in ~/Library/Application Support/com.apple.sharedfilelist/
# com.apple.LSSharedFileList.FavoriteItems.sfl4, reachable only through an API.
#
# The documented API is LSSharedFileList (what `mysides` wraps). Do NOT use it to add:
# on macOS Tahoe, LSSharedFileListInsertItemURL SEGFAULTS. (Its read and remove calls
# still work; only insert is broken. This is why Homebrew disabled `mysides` in Oct
# 2025.) The list is instead read and written through the SFL Objective-C classes that
# Finder itself uses, which LaunchServices vends from CoreServices: SFLGenericList and
# SFLItem. They are PRIVATE — verified working on Tahoe, but re-check after a major
# macOS upgrade. The verify pass at the end turns any regression into a warning rather
# than a silent no-op.
#
# Private classes have no headers, and their init selectors can't be expressed in
# Swift, so this block is Objective-C compiled on the fly (needs the Command Line
# Tools, which the README checklist installs first).
#
# Additive: existing entries are left alone and nothing is ever pruned. Paths compare
# after symlink resolution, since /tmp resolves to /private/tmp.
if command -v clang >/dev/null 2>&1; then
  sidebar_dir="$(mktemp -d)"
  cat > "$sidebar_dir/sidebar.m" <<'OBJC'
#import <Foundation/Foundation.h>
#import <CoreServices/CoreServices.h>

@interface SFLBookmark : NSObject
- (BOOL)resolve;
- (NSURL *)url;
@end

@interface SFLItem : NSObject
- (instancetype)initWithName:(NSString *)name URL:(NSURL *)url properties:(NSDictionary *)props;
- (SFLBookmark *)bookmark;
@end

@interface SFLGenericList : NSObject
- (instancetype)initWithIdentifier:(NSString *)identifier;
- (NSArray<SFLItem *> *)snapshotItems;
- (BOOL)addItem:(SFLItem *)item error:(NSError **)error;
@end

// Both an existing favourite and a target normalise through this, so /tmp and
// /private/tmp compare equal.
static NSString *Normalise(NSURL *url) {
    return url.URLByResolvingSymlinksInPath.URLByStandardizingPath.path;
}

static NSSet<NSString *> *Favourites(SFLGenericList *list) {
    NSMutableSet *paths = [NSMutableSet set];
    for (SFLItem *item in [list snapshotItems]) {
        SFLBookmark *bookmark = [item bookmark];
        if (![bookmark resolve]) continue;  // e.g. an offline network volume
        NSURL *url = [bookmark url];
        if (url) [paths addObject:Normalise(url)];
    }
    return paths;
}

int main(void) { @autoreleasepool {
    // Force LaunchServices to register the SFL classes before we look them up.
    LSSharedFileListCreate(NULL, kLSSharedFileListFavoriteItems, NULL);

    SFLGenericList *list = [[NSClassFromString(@"SFLGenericList") alloc]
        initWithIdentifier:@"com.apple.LSSharedFileList.FavoriteItems"];
    if (!list) { fprintf(stderr, "could not open the favourites list\n"); return 1; }

    NSMutableSet *present = [Favourites(list) mutableCopy];
    NSMutableArray<NSURL *> *added = [NSMutableArray array];

    for (NSString *target in @[@"~/Desktop", @"~/Developer", @"~", @"/tmp"]) {
        NSString *path = target.stringByExpandingTildeInPath;
        BOOL isDir = NO;
        if (![NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDir] || !isDir) {
            printf("  Skipping Finder sidebar entry (no such folder): %s\n", path.UTF8String);
            continue;
        }
        NSURL *url = [NSURL fileURLWithPath:path isDirectory:YES];
        if ([present containsObject:Normalise(url)]) continue;
        [present addObject:Normalise(url)];  // in case a path is listed twice

        SFLItem *item = [[NSClassFromString(@"SFLItem") alloc]
            initWithName:url.lastPathComponent URL:url properties:nil];
        NSError *error = nil;
        if (![list addItem:item error:&error]) {
            fprintf(stderr, "could not add %s: %s\n", path.UTF8String,
                    error.localizedDescription.UTF8String ?: "unknown error");
            return 1;
        }
        [added addObject:url];
        printf("  Added to Finder sidebar: %s\n", path.UTF8String);
    }

    // An add can report success without landing, so confirm against a fresh snapshot.
    NSSet<NSString *> *after = Favourites(list);
    for (NSURL *url in added) {
        if (![after containsObject:Normalise(url)]) {
            fprintf(stderr, "added %s but it is not in the list\n", url.path.UTF8String);
            return 1;
        }
    }
    return 0;
}}
OBJC
  if clang -fobjc-arc -framework Foundation -framework CoreServices \
       -o "$sidebar_dir/sidebar" "$sidebar_dir/sidebar.m" 2>/dev/null; then
    "$sidebar_dir/sidebar" || echo "  WARNING: could not update the Finder sidebar."
  else
    echo "  WARNING: could not build the Finder sidebar helper."
  fi
  rm -rf "$sidebar_dir"
else
  echo "  Skipping Finder sidebar (no clang); add by hand: ~/Desktop, ~/Developer, ~, /tmp"
fi

# Security & Privacy: require password immediately after sleep / screen saver.
# Modern macOS ignores the legacy `defaults write com.apple.screensaver askForPassword`,
# so use the supported, version-agnostic sysadminctl. NOTE: this prompts for the account password.
sysadminctl -screenLock immediate -password -

# Lock Screen: turn the display off sooner on battery (15 min; on power stays 30 min).
# These are the same values shown under System Settings > Lock Screen ("Turn display off ...").
sudo pmset -b displaysleep 15 || true
sudo pmset -c displaysleep 30 || true

# Lock Screen: show an "if found" message on the login/lock screen.
# System Settings' "Show message when locked" writes this key; a non-empty value both
# enables the toggle and supplies the text. Root-owned plist, so needs sudo.
sudo defaults write /Library/Preferences/com.apple.loginwindow LoginwindowText \
  "If found, please contact gaurav@codermana.com" || true

# Control Center: show battery percentage in the menu bar.
# Tahoe/Big Sur+ moved this out of the legacy menu extra into Control Center,
# a per-host key applied by restarting ControlCenter (see killall below).
defaults -currentHost write com.apple.controlcenter BatteryShowPercentage -bool true

# Control Center: show Bluetooth and Volume (Sound) in the menu bar.
# Two mechanisms are written for cross-version support:
#
#  1. Per-host module int.
#     Legacy values: 8 = Always Show, 18 = Show When Active, 2 = Don't Show.
#     On macOS 26 Tahoe, Apple's new Menu Bar pane uses these differently:
#     Bluetooth checked = 2; Sound "Always Show" = 18. Keep the old values only
#     for pre-Tahoe macOS.
#  2. macOS 26 Tahoe: visibility is also driven by
#     `NSStatusItem VisibleCC <Module>` = 1 in the MAIN domain, with an optional
#     `NSStatusItem Preferred Position <Module>` for left/right ordering.
#
# The other OS ignores the keys it doesn't use, so writing both is safe.
# Tahoe values were captured live after enabling both by hand; if a future macOS
# ignores them, set by hand (System Settings > Control Center) and re-capture:
#   defaults read com.apple.controlcenter | grep -iE 'VisibleCC|Preferred Position'
macos_major="$(sw_vers -productVersion | cut -d. -f1)"
if [ "${macos_major:-0}" -ge 26 ] 2>/dev/null; then
  defaults -currentHost write com.apple.controlcenter Bluetooth -int 2
  defaults -currentHost write com.apple.controlcenter Sound     -int 18
else
  defaults -currentHost write com.apple.controlcenter Bluetooth -int 8
  defaults -currentHost write com.apple.controlcenter Sound     -int 8
fi
# Tahoe (macOS 26):
defaults write com.apple.controlcenter "NSStatusItem VisibleCC Bluetooth" -int 1
defaults write com.apple.controlcenter "NSStatusItem VisibleCC Sound"     -int 1
defaults write com.apple.controlcenter "NSStatusItem VisibleCC Display"   -int 1
defaults write com.apple.controlcenter "NSStatusItem Preferred Position Bluetooth" -int 469
defaults write com.apple.controlcenter "NSStatusItem Preferred Position Display"   -int 396
defaults write com.apple.controlcenter "NSStatusItem Preferred Position Sound"     -int 431

# Displays: always show in the menu bar. On Tahoe this is 18; on older macOS,
# 18 meant "Show When Active", so use the legacy Always Show value there.
if [ "${macos_major:-0}" -ge 26 ] 2>/dev/null; then
  defaults -currentHost write com.apple.controlcenter Display -int 18
else
  defaults -currentHost write com.apple.controlcenter Display -int 8
fi

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
killall Dock SystemUIServer ControlCenter Finder 2>/dev/null || true
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

echo "\033[1;31mConfiguring Karabiner-Elements...\033[0m"
mkdir -p ~/.config/karabiner/
# Back up any config Karabiner's onboarding may have written, then restore ours.
[ -f ~/.config/karabiner/karabiner.json ] && \
  cp ~/.config/karabiner/karabiner.json ~/.config/karabiner/karabiner.json.bak
cp ~/Script-BackUp/macOS/karabiner.json ~/.config/karabiner/

# Copying the JSON is not enough: on Karabiner-Elements 14+ the config is inert
# until (1) the DriverKit virtual-HID system extension is activated & approved
# and (2) Input Monitoring is granted to its core service. Without Input
# Monitoring the core service can't enumerate devices, so the Devices pane is
# empty and the per-device remaps never bind. Both are SIP/TCC-protected (not
# scriptable), so trigger the prompts, open the pane, and tell the user what to click.
KE_APP="/Applications/Karabiner-Elements.app"
KE_DRIVER="/Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager"
if [ -d "$KE_APP" ]; then
  # 1) Activate the DriverKit virtual-HID system extension (user must still
  #    approve it once in System Settings > Privacy & Security if prompted).
  [ -x "$KE_DRIVER" ] && "$KE_DRIVER" activate || true
  # 2) Launch Karabiner so its core service starts, reads our config, and
  #    requests Input Monitoring (this is what triggers the TCC prompt).
  open -a "$KE_APP" || true
  # 3) Jump the user straight to the Input Monitoring pane to grant it.
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent" || true
  echo "  IMPORTANT: Karabiner needs one-time manual approval to see your keyboard:"
  echo "    - Approve the Karabiner system extension if System Settings prompts."
  echo "    - Enable Input Monitoring for 'Karabiner-Elements' / 'Karabiner-Core-Service'."
  echo "    - In Karabiner > Devices, tick 'Modify events' for your external keyboard."
  echo "    - A REBOOT may be needed before the device appears and remaps apply."
else
  echo "  Skipping Karabiner setup (not installed) — config copied for later."
fi
