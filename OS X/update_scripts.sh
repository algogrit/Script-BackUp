#! /usr/bin/env bash
alias cp="cp -v"
alias rm="rm -v"

echo "\033[1;31mBacking up non-system files...\033[0m"
cp update_scripts.sh /tmp
cp restore_scripts.sh /tmp
cp README /tmp

echo "\033[1;31mRemoving files...\033[0m"
rm -vr *

echo "\033[1;31mRestoring non-system files...\033[0m"
cp /tmp/update_scripts.sh .
cp /tmp/restore_scripts.sh .
cp /tmp/README .

echo "\033[1;31mList installations...\033[0m"

# List of Brew installations
brew list > brews.list

# List of Brew taps
brew tap > brew_taps.list

# List of Custom installations
echo "Listing /Applications.." > applications.list
ls /Applications | cut -d '.' -f 1 | uniq | sed '/^$/d' >> applications.list
echo "\nListing User Applications.." >> applications.list
ls ~/Applications | cut -d '.' -f 1 | uniq | sed '/^$/d' >> applications.list

# List of all executables in $PATH
ruby -e '`echo $PATH`.strip.split(":").each {|path| puts `ls #{path}`}' > executables.list

echo "\033[1;31mCopying fresh files...\033[0m"
# Copy all bash scripts, except .bash_history
cp -r ~/bash_scripts .
cp ~/.bash* .

# Copy gitconfig
cp ~/.gitconfig .

# Copy vimrc
cp ~/.vimrc .

# Copy irbrc
cp ~/.irbrc .

# Copy vimpagerrc
cp ~/.vimpagerrc .

# Copy .powconfig
cp ~/.powconfig .

# Copy Custom Git Commands
cp -r ~/Custom-Git-Commands .

# Copy Leiningen global profile
cp -r ~/.lein .

# Copy tmux configuration
cp ~/.tmux.conf .

# Copy tmux configuration
cp -r ~/.tmuxinator .

# Copy List of Sublime Packages
mkdir -p Sublime
cp ~/Library/Application\ Support/Sublime\ Text\ 3/Packages/User/Package\ Control.sublime-settings Sublime/packages.list

echo "\033[1;31mRemoving bash turd files...\033[0m"
rm .bash_history

unalias cp
unalias rm

# Remove silently
rm bash_scripts/aliases/.*_secret

echo "\033[1;31mCOMPLETED!\033[0m"
