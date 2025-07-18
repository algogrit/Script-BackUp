#!/usr/bin/env bash

alias cp="cp -v"
alias rm="rm -v"

# Disable homebrew auto update
export PATH=/opt/homebrew/bin:$PATH
export HOMEBREW_NO_AUTO_UPDATE=1

# Defining Resuable functions

function _install_languages {
  cd /tmp
  ACTUAL_WD=$OLDPWD

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

echo "\033[1;31mStarting the restore process...\033[0m"

echo "\033[1;31mCreating directories...\033[0m"
mkdir -p ~/bin ~/Custom-Git-Commands ~/git-hooks ~/.lein ~/.jenv/bin ~/.nodenv/bin ~/.elm ~/.vim/autoload

echo "\033[1;31mTapping brews...\033[0m"
cat $HOME/Script-BackUp/macOS/brew_taps.list | xargs -n 1 brew tap

echo "\033[1;31mInstalling all brew casks...\033[0m"
## Special Installs
brew install --cask --no-quarantine wine-crossover
## Normal Installs
cat brew_casks.list | sort -r | xargs -n 1 brew install --cask &
cat brew_casks.list | xargs -n 1 brew install --cask

echo "\033[1;31mInstalling all brews...\033[0m"
cat ~/Script-BackUp/macOS/brews.list | xargs brew install || brew upgrade

echo "\033[1;31mInstalling all mac App Store apps...\033[0m"
cat "$HOME/Script-BackUp/macOS/mas.list" | cut -d ' ' -f 1 | xargs -n 1 mas install || exit 1

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

echo "\033[1;31mChanging Shell...\033[0m"
chsh -s /opt/homebrew/bin/bash

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
cp ~/Script-BackUp/macOS/.powconfig ~/
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

echo "\033[1;31mInstalling ~/bin utilities...\033[0m"
wget -O ~/bin/flash https://raw.githubusercontent.com/hypriot/flash/master/flash
chmod +x ~/bin/flash
cp ~/Script-BackUp/macOS/bin/* ~/bin

echo "\033[1;31mSetup Airport Utility...\033[0m"
ln -sf /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport ~/bin

echo "\033[1;31mHave you reloaded shell? (Y/n)\033[0m"
read _reloaded_shell

if [[ "$(echo "$_reloaded_shell" | tr '[:upper:]' '[:lower:]')" == "n" ]]; then
  echo "Exiting. Please reload the shell and try again."
  exit 1
fi

echo "\033[1;31mInstalling language versions...\033[0m"
RBENV_ROOT=/usr/local/var/rbenv _install_languages ruby rbenv
LDFLAGS="-L/usr/local/opt/zlib/lib" CPPFLAGS="-I/usr/local/opt/zlib/include" _install_languages python pyenv
_install_languages node nodenv
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
