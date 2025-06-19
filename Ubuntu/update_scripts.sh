#!/usr/bin/env sh

alias cp="cp -v"
alias rm="rm -v"

echo "\033[1;31mBacking up non-system files...\033[0m"
cp update_scripts.sh /tmp
cp restore_scripts.sh /tmp
cp README.md /tmp

echo "\033[1;31mRemoving files...\033[0m"
rm -vr *

# Copy all bash scripts, except .bash_history
cp -r ~/bash_scripts .
cp ~/.bash* .
rm .bash_history

# Copy gitconfig
cp ~/.gitconfig .

# Copy Custom Git Commands
mkdir -p ~/Custom-Git-Commands
cp -r ~/Custom-Git-Commands .

# Snap packages
snap list > package_list
