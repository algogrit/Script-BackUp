#! /usr/bin/env bash
alias cp="cp -v"
alias rm="rm -v"

echo "\033[1;31mBacking up to git stash before restoring...\033[0m"

./update_scripts.sh
git add -A
git stash

echo "\033[1;31mStarting the restore process...\033[0m"

echo "\033[1;31mCreating directories...\033[0m"
mkdir -p ~/bin ~/.go ~/Custom-Git-Commands

echo "\033[1;31mTapping brews...\033[0m"
cat ~/Script-BackUp/OS\ X/brew_taps.list | xargs brew tap

echo "\033[1;31mInstalling all brews...\033[0m"
cat ~/Script-BackUp/OS\ X/brews.list | xargs brew install

echo "\033[1;31mInstalling all brew casks...\033[0m"
cat ~/Script-BackUp/OS\ X/brew_casks.list | xargs brew cask install

echo "\033[1;31mInstalling Sack/Sag\033[0m"
cd /tmp && git clone https://github.com/sampson-chen/sack.git && cd sack && chmod +x install_sack.sh && ./install_sack.sh

echo "\033[1;31mSetting up managers...\033[0m"

echo "Vundle"
git clone https://github.com/gmarik/vundle.git ~/.vim/bundle/Vundle.vim

echo "Goenv"
git clone https://github.com/wfarr/goenv.git ~/.goenv

echo "\033[1;31mRestoring Bash Scripts...\033[0m"
if [ ! -d ~/bash_scripts ]; then
  cp -r ~/Script-BackUp/OS\ X/bash_scripts ~/bash_scripts
fi

echo "\033[1;31mRestoring bash scripts...\033[0m"
cp ~/Script-BackUp/OS\ X/.bash* ~/

echo "\033[1;31mRestoring paths...\033[0m"
sudo cp ~/Script-BackUp/OS\ X/root/etc/paths /etc/paths

echo "\033[1;31mRestoring other configs...\033[0m"
cp ~/Script-BackUp/OS\ X/.gitconfig ~/
cp ~/Script-BackUp/OS\ X/.vimrc ~/
cp ~/Script-BackUp/OS\ X/.tmux.conf ~/
cp ~/Script-BackUp/OS\ X/.vimpagerrc ~/
cp ~/Script-BackUp/OS\ X/.sackrc ~/
cp ~/Script-BackUp/OS\ X/.irbrc ~/
cp ~/Script-BackUp/OS\ X/.taskrc ~/
cp ~/Script-BackUp/OS\ X/.powconfig ~/

echo "\033[1;31mInstall vundle packages...\033[0m"
vim +BundleInstall +qall

echo "\033[1;31mRestoring Custom git commands...\033[0m"
cp ~/Script-BackUp/OS\ X/Custom-Git-Commands/* ~/Custom-Git-Commands/

echo "\033[1;31mSetting Up Sublime...\033[0m"
cp Sublime/packages.list ~/Library/Application\ Support/Sublime\ Text\ 3/Packages/User/Package\ Control.sublime-settings
cp Sublime/Preferences.sublime-settings ~/Library/Application\ Support/Sublime\ Text\ 3/Packages/User/

echo "\033[1;31mSetup Airport Utility...\033[0m"
ln -s /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport ~/bin

echo "\033[1;31mPopping git stash after restoring...\033[0m"
git stash pop

unalias cp
unalias rm
