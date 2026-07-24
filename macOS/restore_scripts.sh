#!/usr/bin/env bash

alias cp="cp -v"
alias rm="rm -v"

# Detect the Homebrew prefix: /opt/homebrew on Apple Silicon, /usr/local on Intel.
if [ -x /opt/homebrew/bin/brew ]; then
  BREW_PREFIX=/opt/homebrew
elif [ -x /usr/local/bin/brew ]; then
  BREW_PREFIX=/usr/local
else
  BREW_PREFIX="$(brew --prefix 2>/dev/null || echo /opt/homebrew)"
fi

# Disable homebrew auto update
export PATH="$BREW_PREFIX/bin:$PATH"
export HOMEBREW_NO_AUTO_UPDATE=1
# Don't prompt for confirmation before installing (ask mode is brew's default now);
# installs are piped via xargs with no TTY, so the prompt would otherwise hang.
export HOMEBREW_NO_ASK=1

# Defining Resuable functions

function _install_languages {
  cd /tmp
  ACTUAL_WD=$OLDPWD

  ## TODO: Handle nuances in fnm
  # Install just the global version
  cat "$HOME/Script-BackUp/macOS/$1.versions" | grep -v system | grep set | cut -d ' ' -f 2 | xargs -n 1 $2 install
  # Set the global version
  cat "$HOME/Script-BackUp/macOS/$1.versions" | grep -v system | grep set | cut -d ' ' -f 2 | xargs -n 1 $2 global
  # Install the other versions (TODO: make it optional)
  cat "$HOME/Script-BackUp/macOS/$1.versions" | grep -v system | grep -v set | xargs -n 1 $2 install

  cd "$ACTUAL_WD"
}

# Here we go.. ask for the administrator password upfront and run a
# keep-alive to update existing `sudo` time stamp until script has finished
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Rosetta 2 (Apple Silicon only). Some casks (e.g. zoho-workdrive) require it.
# `oahd` is the Rosetta daemon; if it's running, Rosetta is already installed.
if [ "$(uname -m)" = "arm64" ] && ! /usr/bin/pgrep -q oahd; then
  echo "\033[1;31mInstalling Rosetta 2...\033[0m"
  sudo softwareupdate --install-rosetta --agree-to-license || true
fi

echo "\033[1;31mStarting the restore process...\033[0m"

echo "\033[1;31mCreating directories...\033[0m"
mkdir -p ~/bin ~/Custom-Git-Commands ~/git-hooks ~/.lein ~/.jenv/bin ~/.elm ~/.vim/autoload

echo "\033[1;31mTapping brews...\033[0m"
cat $HOME/Script-BackUp/macOS/brew_taps.list | xargs -n 1 brew tap

echo "\033[1;31mInstalling all brew casks...\033[0m"
cat brew_casks.list | sort -r | xargs -n 1 brew install --cask &
cat brew_casks.list | xargs -n 1 brew install --cask

# Zoho WorkDrive TrueSync: no Homebrew cask exists (the `zoho-workdrive` cask is the
# different full-sync "Sync" app, installed as "Zoho WorkDrive.app"). Best-effort install
# of the on-demand TrueSync virtual-drive app; safe to fail (login item self-skips if absent).
TRUESYNC_APP="/Applications/Zoho WorkDrive TrueSync.app"
TRUESYNC_PKG_URL=""   # pin the current .pkg URL from https://www.zoho.com/workdrive/truesync.html
if [ ! -d "$TRUESYNC_APP" ]; then
  if [ -n "$TRUESYNC_PKG_URL" ] && curl -fsSL "$TRUESYNC_PKG_URL" -o /tmp/truesync.pkg; then
    sudo installer -pkg /tmp/truesync.pkg -target / || echo "  TrueSync install failed; install manually."
    rm -f /tmp/truesync.pkg
  else
    echo "  Zoho WorkDrive TrueSync not installed — download manually: https://www.zoho.com/workdrive/truesync.html"
  fi
fi

echo "\033[1;31mInstalling all brews...\033[0m"
cat ~/Script-BackUp/macOS/brews.list | xargs brew install
brew upgrade

echo "\033[1;31mInstalling all mac App Store apps...\033[0m"
cat "$HOME/Script-BackUp/macOS/mas.list" | awk '{print $1}' | xargs -n 1 mas install || exit 1

# Accept the Xcode license non-interactively (Xcode is installed via mas above).
if command -v xcodebuild >/dev/null 2>&1; then
  sudo xcodebuild -license accept 2>/dev/null || true
fi

echo "\033[1;31mAll Good? (Y/n)\033[0m"
read _all_good

if [[ $_all_good = "n" ]]; then
	exit 1
fi

echo "\033[1;31mInstalling Sack/Sag\033[0m"
cd /tmp && git clone https://github.com/sampson-chen/sack.git && cd sack && chmod +x install_sack.sh && ./install_sack.sh
cd ~/Script-BackUp/macOS

echo "\033[1;31mSetting up Spacemacs\033[0m"
git clone https://github.com/syl20bnr/spacemacs ~/.emacs.d

echo "\033[1;31mRestoring Bash Scripts...\033[0m"
if [ ! -d ~/bash_scripts ]; then
  cp -r ~/Script-BackUp/macOS/bash_scripts ~/bash_scripts
fi

echo "\033[1;31mRestoring bash scripts...\033[0m"
cp ~/Script-BackUp/macOS/.bash* ~/
touch ~/bash_scripts/aliases/.personal_secret

echo "\033[1;31mRestoring ssh config...\033[0m"
mkdir -p ~/.ssh
cp ~/Script-BackUp/macOS/.ssh/config ~/.ssh

echo "\033[1;31mRestoring paths...\033[0m"
sudo cp ~/Script-BackUp/macOS/root/etc/paths /etc/paths
sudo cp ~/Script-BackUp/macOS/root/etc/hosts /etc/hosts
sudo cp ~/Script-BackUp/macOS/root/etc/shells /etc/shells

# The committed /etc/shells only lists the Apple Silicon bash path; ensure the
# detected brew bash is present so chsh accepts it on Intel too.
if ! grep -qxF "$BREW_PREFIX/bin/bash" /etc/shells; then
  echo "$BREW_PREFIX/bin/bash" | sudo tee -a /etc/shells >/dev/null
fi

echo "\033[1;31mChanging Shell...\033[0m"
# chsh only checks /etc/shells, not that the binary exists. Guard against pointing
# the login shell at a bash that the brew step never installed (causes a Terminal lockout).
if [ -x "$BREW_PREFIX/bin/bash" ]; then
  chsh -s "$BREW_PREFIX/bin/bash"
else
  echo "  $BREW_PREFIX/bin/bash not found — leaving login shell unchanged to avoid lockout."
  echo "  Re-run 'chsh -s $BREW_PREFIX/bin/bash' after 'brew install bash' succeeds."
fi

echo "\033[1;31mRestoring other configs...\033[0m"
cp ~/Script-BackUp/macOS/.ignore ~/
cp ~/Script-BackUp/macOS/.gitconfig ~/
cp ~/Script-BackUp/macOS/.gitignore ~/
cp ~/Script-BackUp/macOS/.gitattributes ~/
cp ~/Script-BackUp/macOS/.tigrc ~/
cp ~/Script-BackUp/macOS/.vimrc ~/
cp ~/Script-BackUp/macOS/.tmux.conf ~/
cp ~/Script-BackUp/macOS/.sackrc ~/
cp ~/Script-BackUp/macOS/.irbrc ~/
cp ~/Script-BackUp/macOS/.gemrc ~/
cp ~/Script-BackUp/macOS/.lein/* ~/.lein

echo "\033[1;31mSetting up managers...\033[0m"

echo "\033[1;31mVim plugin manager...\033[0m"
curl -fLo ~/.vim/autoload/plug.vim https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

echo "\033[1;31mInstall goenv...\033[0m"
git clone git@github.com:syndbg/goenv.git ~/.goenv

echo "\033[1;31mInstall vundle packages...\033[0m"
git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/vundle
vim +PlugInstall +qall

echo "\033[1;31mSetting up VCpkg...\033[0m"
git clone https://github.com/microsoft/vcpkg "$HOME/vcpkg"

echo "\033[1;31mRestoring git customizations...\033[0m"
cp ~/Script-BackUp/macOS/Custom-Git-Commands/* ~/Custom-Git-Commands/
cp ~/Script-BackUp/macOS/git-hooks/* ~/git-hooks/

echo "\033[1;31mSetting up exercism...\033[0m"
mkdir -p ~/Developer/exercism ~/.config/exercism/
exercism configure -w $HOME/Developer/exercism/

echo "\033[1;31mSetting up common repositories...\033[0m"
mkdir -p ~/Developer/Algogrit
git clone git@github.com:algogrit/gauravagarwalr.com.git ~/Developer/Algogrit/algogrit.com
git clone git@github.com:algogrit/blog.gauravagarwalr.com.git ~/Developer/Algogrit/blog
git clone git@github.com:gauravagarwalr/value-investing-with-analysis.git ~/Developer/Algogrit/value-investing-with-analysis
git clone git@bitbucket.org:algogrit/project-resources.git ~/Developer/Algogrit/project-resources
git clone git@bitbucket.org:algogrit/interview-challenges.git ~/Developer/Algogrit/interviews

mkdir -p ~/Developer/Consultant/AgarwalConsulting
git clone git@github.com:AgarwalConsulting/landing-page.git ~/Developer/Consultant/AgarwalConsulting/agarwalconsulting.io

mkdir -p ~/Developer/Consultant/CnI
git clone git@bitbucket.org:algogrit/contracts.git ~/Developer/Consultant/CnI/contracts
git clone git@bitbucket.org:algogrit/invoices.git ~/Developer/Consultant/CnI/invoices
git clone git@bitbucket.org:algogrit/quotation.git ~/Developer/Consultant/CnI/quotation

mkdir -p ~/Developer/Presentations
git clone git@github.com:algogrit/presentation-template.git ~/Developer/Presentations/presentation-template
echo talks > ~/Developer/Presentations/project-resources.branch
git clone --single-branch --branch talks git@bitbucket.org:algogrit/project-resources.git ~/Developer/Presentations/talk-ideas

git clone --single-branch --branch master-task-list git@bitbucket.org:algogrit/project-resources.git ~/Developer/Tasks
git clone git@github.com:algogrit/Training.git ~/Developer/Training
cd ~/Developer/Training
git submodule update --recursive --remote
cd ~/Script-BackUp/macOS

git clone git@bitbucket.org:algogrit/instruments.git ~/Downloads/Instruments
git clone git@bitbucket.org:algogrit/recipes.git ~/Downloads/Recipes

echo "\033[1;31mSetting up VSCode...\033[0m"
cp ~/Script-BackUp/macOS/VSCode/settings.json ~/Library/Application\ Support/Code/User/
cp ~/Script-BackUp/macOS/VSCode/keybindings.json ~/Library/Application\ Support/Code/User/
cat ~/Script-BackUp/macOS/VSCode/extensions.list | xargs -n 1 code --install-extension

echo "\033[1;31mRestoring Claude Code settings...\033[0m"
mkdir -p ~/.claude ~/.claude/plugins
cp ~/Script-BackUp/macOS/Claude/settings.json ~/.claude/ 2>/dev/null || true
cp ~/Script-BackUp/macOS/Claude/keybindings.json ~/.claude/ 2>/dev/null || true
cp ~/Script-BackUp/macOS/Claude/CLAUDE.md ~/.claude/ 2>/dev/null || true
cp -r ~/Script-BackUp/macOS/Claude/commands ~/.claude/ 2>/dev/null || true
cp -r ~/Script-BackUp/macOS/Claude/agents ~/.claude/ 2>/dev/null || true
cp -r ~/Script-BackUp/macOS/Claude/skills ~/.claude/ 2>/dev/null || true
cp -r ~/Script-BackUp/macOS/Claude/hooks ~/.claude/ 2>/dev/null || true
cp ~/Script-BackUp/macOS/Claude/plugins/known_marketplaces.json ~/.claude/plugins/ 2>/dev/null || true
cp ~/Script-BackUp/macOS/Claude/plugins/installed_plugins.json ~/.claude/plugins/ 2>/dev/null || true

echo "\033[1;31mRestoring Codex settings...\033[0m"
mkdir -p ~/.codex
cp ~/Script-BackUp/macOS/Codex/config.toml ~/.codex/ 2>/dev/null || true
cp ~/Script-BackUp/macOS/Codex/AGENTS.md ~/.codex/ 2>/dev/null || true
cp -r ~/Script-BackUp/macOS/Codex/rules ~/.codex/ 2>/dev/null || true
cp -r ~/Script-BackUp/macOS/Codex/prompts ~/.codex/ 2>/dev/null || true
cp -r ~/Script-BackUp/macOS/Codex/skills ~/.codex/ 2>/dev/null || true

echo "\033[1;31mRestoring ramayan config...\033[0m"
mkdir -p ~/.config/ramayan
cp ~/Script-BackUp/macOS/ramayan/config.toml ~/.config/ramayan/ 2>/dev/null || true

# Apply macOS System Settings tweaks + login items (also runnable standalone).
./apply_system_settings.sh

echo "\033[1;31mRestoring iTerm2 preferences...\033[0m"
echo "  (Quit iTerm2 before this step so it doesn't overwrite on exit.)"
# iTerm2: import prefs and enable its native custom-folder sync (iTerm2 must be quit)
if [ -f ~/Script-BackUp/macOS/iTerm2/com.googlecode.iterm2.plist ]; then
  defaults import com.googlecode.iterm2 ~/Script-BackUp/macOS/iTerm2/com.googlecode.iterm2.plist
  defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$HOME/Script-BackUp/macOS/iTerm2"
  defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
  defaults write com.googlecode.iterm2 NoSyncNeverRemindPrefsChangesLostForFile_selection -int 2
fi

echo "\033[1;31mInstalling ~/bin utilities...\033[0m"
wget -O ~/bin/flash https://raw.githubusercontent.com/hypriot/flash/master/flash
chmod +x ~/bin/flash
cp ~/Script-BackUp/macOS/bin/* ~/bin

# Workaround for annoying non-apple bluetooth keyboard disconnects...
cp ~/Script-BackUp/macOS/LaunchAgents/* ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.user.bluetooth.keepalive.plist

echo "\033[1;31mSetup Airport Utility...\033[0m"
ln -sf /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport ~/bin

echo "\033[1;31mHave you reloaded shell? (Y/n)\033[0m"
read _reloaded_shell

if [[ "$(echo "$_reloaded_shell" | tr '[:upper:]' '[:lower:]')" == "n" ]]; then
  echo "Exiting. Please reload the shell and try again."
  exit 1
fi

echo "\033[1;31mInstalling language versions...\033[0m"
RBENV_ROOT="$BREW_PREFIX/var/rbenv" _install_languages ruby rbenv
LDFLAGS="-L$BREW_PREFIX/opt/zlib/lib" CPPFLAGS="-I$BREW_PREFIX/opt/zlib/include" _install_languages python pyenv
_install_languages node fnm
_install_languages go goenv
jenv enable-plugin export
# jenv installing all the java versions
/usr/libexec/java_home -V2&> /tmp/jdk-list
cat /tmp/jdk-list | ag Library | cut -f 3 | xargs -n 1 jenv add

echo "\033[1;31mInstalling git-up...\033[0m"
RBENV_VERSION=3.4.4 gem install git-up

echo "\033[1;31mCreating other directories....\033[0m"
mkdir -p ~/.private/cloud/gcp

echo "\033[1;31mInstalling android deps usings sdkmanager...\033[0m"

jenv global 1.8
echo y | sdkmanager "tools"
echo y | sdkmanager "platform-tools"

echo "\033[1;31mReseting password restrictions...\033[0m"
pwpolicy -clearaccountpolicies
passwd
security set-keychain-password

echo "\033[1;31mSyncing tools...\033[0m"
./tool-sync/obs/sync.sh restore

echo "\033[1;31mFinishing up...\033[0m"

unalias cp
unalias rm
