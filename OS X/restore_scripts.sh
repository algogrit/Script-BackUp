#! /usr/bin/env bash
alias cp="cp -v"
alias rm="rm -v"

echo "\033[1;31mBacking up to git stash before restoring...\033[0m"

./update_scripts.sh
git add -A
git stash

echo "\033[1;31mStarting the restore process...\033[0m"


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
git clone https://github.com/gmarik/vundle.git ~/.vim/bundle/vundle

echo "Nodenv"
git clone https://github.com/wfarr/nodenv.git ~/.nodenv

echo "Goenv"
git clone https://github.com/wfarr/goenv.git ~/.goenv

echo "\033[1;31mRestoring Bash Scripts...\033m[0m"
if [ ! -d ~/bash_scripts ]; then
  cp -r ~/Script-BackUp/OS\ X/bash_scripts ~/bash_scripts
fi

echo "\033[1;31mRestoring bash scripts...\033m[0m"
cp ~/Script-BackUp/OS\ X/.bash* ~/

echo "\033[1;31mRestoring paths...\033m[0m"
sudo cp ~/Script-BackUp/OS\ X/root/etc/paths /etc/paths

echo "\033[1;31mRestoring other configs...\033m[0m"
cp ~/Script-BackUp/OS\ X/.gitconfig ~/
cp ~/Script-BackUp/OS\ X/.vimrc ~/
cp ~/Script-BackUp/OS\ X/.tmux.conf ~/
cp ~/Script-BackUp/OS\ X/.vimpagerrc ~/
cp ~/Script-BackUp/OS\ X/.sackrc ~/
cp ~/Script-BackUp/OS\ X/.irbrc ~/
cp ~/Script-BackUp/OS\ X/.taskrc ~/
cp ~/Script-BackUp/OS\ X/.powconfig ~/

echo "\033[1;31mInstall vundle packages...\033m[0m"
vim +BundleInstall +qall

echo "\033[1;31mCreating directory for GOPATH...\033m[0m"
mkdir ~/.go

echo "\033[1;31mRestoring Custom git commands...\033m[0m"
mkdir -p ~/Custom-Git-Commands
cp ~/Script-BackUp/OS\ X/Custom-Git-Commands/* ~/Custom-Git-Commands/

echo "\033[1;31mLinking Sublime...\033m[0m"
ln -s "/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl" ~/bin/subl


echo "\033[1;31mPopping git stash after restoring...\033[0m"
git stash pop

unalias cp
unalias rm
