#! /usr/bin/env bash

alias cp="cp -v"
alias rm="rm -v"

# Defining Resuable functions

function _line_by_line {
  while read single_arg; do
    $1 $single_arg
  done
}

function _install_languages {
  cd /tmp
  ACTUAL_WD=$OLDPWD

  cat "$HOME/Script-BackUp/OS X/$1.versions" | grep -v system | grep set | cut -d ' ' -f 2 | _line_by_line "$2 install"
  cat "$HOME/Script-BackUp/OS X/$1.versions" | grep -v system | grep set | cut -d ' ' -f 2 | _line_by_line "$2 global"
  cat "$HOME/Script-BackUp/OS X/$1.versions" | grep -v system | grep -v set | _line_by_line "$2 install"

  cd "$ACTUAL_WD"
}

echo "\033[1;31mStarting the restore process...\033[0m"

echo "\033[1;31mCreating directories...\033[0m"
mkdir -p ~/bin ~/Custom-Git-Commands ~/.lein ~/.jenv/bin ~/.elm

echo "\033[1;31mTapping brews...\033[0m"
_line_by_line "brew tap" < "$HOME/Script-BackUp/OS X/brew_taps.list"

echo "\033[1;31mInstalling all brew casks...\033[0m"
brew install brew-cask
cat ~/Script-BackUp/OS\ X/brew_casks.list | xargs brew cask install || exit 1

echo "\033[1;31mInstalling all brews...\033[0m"
cat ~/Script-BackUp/OS\ X/brews.list | xargs brew install || brew upgrade || exit 1

echo "\033[1;31mInstalling Sack/Sag\033[0m"
cd /tmp && git clone https://github.com/sampson-chen/sack.git && cd sack && chmod +x install_sack.sh && ./install_sack.sh
cd ~/Script-BackUp/OS\ X

echo "\033[1;31mSetting up Spacemacs\033[0m"
git clone https://github.com/syl20bnr/spacemacs ~/.emacs.d

echo "\033[1;31mSetting up managers...\033[0m"

echo "Vundle"
git clone https://github.com/gmarik/vundle.git ~/.vim/bundle/vundle

echo "Nodenv"
git clone https://github.com/nodenv/nodenv.git ~/.nodenv
git clone git://github.com/nodenv/node-build.git ~/.nodenv/plugins/node-build

echo "\033[1;31mRestoring Bash Scripts...\033[0m"
if [ ! -d ~/bash_scripts ]; then
  cp -r ~/Script-BackUp/OS\ X/bash_scripts ~/bash_scripts
fi

echo "\033[1;31mRestoring bash scripts...\033[0m"
cp ~/Script-BackUp/OS\ X/.bash* ~/
touch ~/bash_scripts/aliases/.personal_secret

echo "\033[1;31mRestoring ssh config...\033[0m"
mkdir -p ~/.ssh
cp ~/Script-BackUp/OS\ X/.ssh/config ~/.ssh

echo "\033[1;31mRestoring paths...\033[0m"
sudo cp ~/Script-BackUp/OS\ X/root/etc/paths /etc/paths
sudo cp ~/Script-BackUp/OS\ X/root/etc/hosts /etc/hosts
sudo cp ~/Script-BackUp/OS\ X/root/etc/shells /etc/shells

echo "\033[1;31mChanging Shell...\033[0m"
chsh -s /usr/local/bin/bash

echo "\033[1;31mRestoring other configs...\033[0m"
cp ~/Script-BackUp/OS\ X/.gitconfig ~/
cp ~/Script-BackUp/OS\ X/.gitignore ~/
cp ~/Script-BackUp/OS\ X/.tigrc ~/
cp ~/Script-BackUp/OS\ X/.vimrc ~/
cp ~/Script-BackUp/OS\ X/.tmux.conf ~/
cp ~/Script-BackUp/OS\ X/.sackrc ~/
cp ~/Script-BackUp/OS\ X/.irbrc ~/
cp ~/Script-BackUp/OS\ X/.gemrc ~/
cp ~/Script-BackUp/OS\ X/.powconfig ~/
cp ~/Script-BackUp/OS\ X/.lein/* ~/.lein

echo "\033[1;31mInstall vundle packages...\033[0m"
vim +BundleInstall +qall

echo "\033[1;31mRestoring Custom git commands...\033[0m"
cp ~/Script-BackUp/OS\ X/Custom-Git-Commands/* ~/Custom-Git-Commands/

echo "\033[1;31mSetting Up Sublime...\033[0m"
cp ~/Script-BackUp/OS\ X/Sublime/*.sublime-settings ~/Library/Application\ Support/Sublime\ Text\ 3/Packages/User/

echo "\033[1;31mInstalling ~/bin utilities...\033[0m"
wget -O ~/bin/flash https://raw.githubusercontent.com/hypriot/flash/master/$(uname -s)/flash
chmod +x ~/bin/flash
cp ~/Script-BackUp/OS\ X/bin/* ~/bin

echo "\033[1;31mSetup Airport Utility...\033[0m"
ln -sf /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport ~/bin

echo "\033[1;31mInstalling language versions...\033[0m"
_install_languages ruby rbenv
_install_languages python pyenv
_install_languages node nodenv
_install_languages go goenv

unalias cp
unalias rm
