#! /usr/bin/env sh
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

echo "\033[1;31mBrew info...\033[0m"
# Brew Info
brew update
brew cleanup
brew doctor | tee brew.info
brew info | tee -a brew.info

echo "\033[1;31mOutdated brews...\033[0m"
brew outdated

# List of Custom installations
echo "Listing /Applications.." > applications.list
ls /Applications | cut -d '.' -f 1 | uniq | sed '/^$/d' >> applications.list
echo "\nListing User Applications.." >> applications.list
ls ~/Applications | cut -d '.' -f 1 | uniq | sed '/^$/d' >> applications.list


rbenv versions > ruby.versions
nodenv versions > node.versions
pyenv versions > python.versions
goenv versions > go.versions

rbenv rehash
nodenv rehash
pyenv rehash
goenv rehash

# List of all executables in $PATH
ruby -e '`echo $PATH`.strip.split(":").uniq.each {|path| puts `ls #{path}`}' | sort | uniq > executables.list

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

# Copy Sack/Sag config
cp ~/.sackrc .

# Copy taskwarrior config
cp ~/.taskrc .

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
cp ~/Library/Application\ Support/Sublime\ Text\ 3/Packages/User/Preferences.sublime-settings Sublime/

# Copy files relative to root
mkdir -p root
mkdir -p root/etc
cp /etc/paths root/etc/
cp /etc/hosts root/etc/

echo "\033[1;31mRemoving bash turd files...\033[0m"
rm .bash_history

unalias cp
unalias rm

# Remove silently
rm bash_scripts/aliases/.*_secret

echo "\033[1;31mCOMPLETED!\033[0m"
