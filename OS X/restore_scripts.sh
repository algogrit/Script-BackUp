#! /usr/bin/env bash
alias cp="cp -v"
alias rm="rm -v"

echo "\033[1;31mBacking up to git stash before restoring...\033[0m"

./update_scripts.sh
git add -A
git stash

echo "\033[1;31mStarting the restore process...\033[0m"


echo "\033[1;31mTapping brews...\033[0m"
cat ~/Script-BackUp/OS\ X/list_of_brew_taps | xargs brew tap

echo "\033[1;31mInstalling all brews...\033[0m"
cat ~/Script-BackUp/OS\ X/list_of_brews | xargs brew install

echo "\033[1;31mRestoring Bash Scripts...\033m[0m"
if [ ! -d ~/bash_scripts ]; then
  cp -r ~/Script-BackUp/OS\ X/bash_scripts ~/bash_scripts
fi

echo "\033[1;31mRestoring bash scripts...\033m[0m"
cp ~/Script-BackUp/OS\ X/.bash* ~/

echo "\033[1;31mRestoring other configs...\033m[0m"
cp ~/Script-BackUp/OS\ X/.gitconfig ~/
cp ~/Script-BackUp/OS\ X/.vimrc ~/
cp ~/Script-BackUp/OS\ X/.tmux.conf ~/
cp ~/Script-BackUp/OS\ X/.vimpagerrc ~/
cp ~/Script-BackUp/OS\ X/.irbrc ~/
cp ~/Script-BackUp/OS\ X/.powconfig ~/

echo "\033[1;31mRestoring Custom git commands...\033m[0m"
mkdir -p ~/Custom-Git-Commands
cp ~/Script-BackUp/OS\ X/Custom-Git-Commands/* ~/Custom-Git-Commands/

echo "\033[1;31mLinking Sublime...\033m[0m"
ln -s "/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl" ~/bin/subl


echo "\033[1;31mPopping git stash after restoring...\033[0m"
git stash pop

unalias cp
unalias rm
