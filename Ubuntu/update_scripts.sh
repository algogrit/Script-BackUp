#!/usr/bin/env sh

alias cp="cp -v"
alias rm="rm -v"

echo "\033[1;31mBacking up non-system files...\033[0m"
cp update_scripts.sh /tmp
cp restore_scripts.sh /tmp
cp README.md /tmp

echo "\033[1;31mRemoving files...\033[0m"
rm -vr *

echo "\033[1;31mRestoring non-system files...\033[0m"
cp /tmp/update_scripts.sh .
cp /tmp/restore_scripts.sh .
cp /tmp/README.md .

# Copy all bash scripts, except .bash_history
cp -r ~/bash_scripts .
cp ~/.bash* .
rm .bash_history

# Copy gitconfig
cp ~/.gitconfig .
cp ~/.gitignore .

# Copy tmux configuration
cp ~/.tmux.conf .

# Copy Custom Git Commands
mkdir -p ~/Custom-Git-Commands
cp -r ~/Custom-Git-Commands .

echo "📦 Backing up APT and snap packages..."
apt-mark showmanual > apt-packages.list

# Snap packages
snap list > snaps.list

unalias cp
unalias rm

# Remove silently
rm bash_scripts/aliases/.*_secret
rm -rf bash_scripts/third_party
