#! /usr/bin/env sh

alias cp="cp -v"
alias rm="rm -v"

echo "\033[1;31mBacking up non-system files...\033[0m"
cp update_scripts.sh /tmp
cp restore_scripts.sh /tmp
cp read_android_packages.sh /tmp
cp android_packages.list /tmp
cp README /tmp

echo "\033[1;31mSetting permission prior to deletion...("'!'")\033[0m"
chmod 666 root/etc/irbrc

echo "\033[1;31mRemoving files...\033[0m"
rm -vr *

echo "\033[1;31mRestoring non-system files...\033[0m"
cp /tmp/update_scripts.sh .
cp /tmp/restore_scripts.sh .
cp /tmp/read_android_packages.sh .
cp /tmp/android_packages.list .
cp /tmp/README .

echo "\033[1;31mList installations...\033[0m"

# Updating brew prior to any brew operations
brew update
brew cleanup

# List of Brew installations
brew list > brews.list

# List of Brew taps
brew tap > brew_taps.list
brew tap | xargs brew tap-info > brew_taps.info

# List of Brew Cask Installations
brew cask list > brew_casks.list

# List of Custom installations
echo "Listing /Applications.." > applications.list
ls /Applications | cut -d '.' -f 1 | uniq | sed '/^$/d' >> applications.list
echo "\nListing User Applications.." >> applications.list
ls ~/Applications | cut -d '.' -f 1 | uniq | sed '/^$/d' >> applications.list

rbenv versions > ruby.versions
nodenv versions > node.versions
pyenv versions | grep -v "-" > python.versions

rbenv rehash
nodenv rehash
pyenv rehash

# List of all executables in $PATH
ruby -e '`echo $PATH`.strip.split(":").uniq.each {|path| puts `ls #{path}`}' | sort | uniq > executables.list

echo "\033[1;31mCopying fresh files...\033[0m"
# Copy all bash scripts, except .bash_history
cp -r ~/bash_scripts .
cp ~/.bash* .

# Copy gitconfig
cp ~/.gitconfig .
cp ~/.gitignore .

# Copy vimrc
cp ~/.vimrc .

# Copy ruby related files
cp ~/.irbrc .
cp ~/.gemrc .

# Copy Sack/Sag config
cp ~/.sackrc .

# Copy .powconfig
cp ~/.powconfig .

# Copy Custom Git Commands
cp -r ~/Custom-Git-Commands .

# Copy Leiningen global profile
cp -r ~/.lein .
rm -f .lein/repl-history

# Copy tmux configuration
cp ~/.tmux.conf .

# Copy List of Sublime Packages
mkdir -p Sublime
cp ~/Library/Application\ Support/Sublime\ Text\ 3/Packages/User/Package\ Control.sublime-settings Sublime/packages.list
cp ~/Library/Application\ Support/Sublime\ Text\ 3/Packages/User/Preferences.sublime-settings Sublime/

# Copy files relative to root
mkdir -p root
mkdir -p root/etc
cp /etc/paths root/etc/
cp /etc/hosts root/etc/
cp /etc/irbrc root/etc/
cp /etc/shells root/etc/

# Copy ssh config
mkdir -p .ssh
cp ~/.ssh/config .ssh/

# ENV config
_ENV_SENSITIVE_INFO="USER\|PASS\|SECRET"
echo "\033[1;31mIgnoring from ENV: \033[0m"
env | grep $_ENV_SENSITIVE_INFO
env | grep -v $_ENV_SENSITIVE_INFO | sort > env.config

echo "\033[1;31mRemoving bash unnecessary files...\033[0m"
rm .bash_history

unalias cp
unalias rm

# Remove silently
rm bash_scripts/aliases/.*_secret

echo "\033[1;31mBrew info...\033[0m"
brew doctor 2>&1 | tee brew.info
brew info 2>&1 | tee -a brew.info

echo "\033[1;31mBrew Cask Info...\033[0m"
brew cask cleanup
brew cask doctor 2>&1 | tee brew_casks.info

echo "\033[1;31mOutdated brews...\033[0m"
brew outdated

ACTUAL_WD=$PWD

echo "\033[1;31mUpdating nodenv with git...\033[0m"
cd ~/.nodenv && git ru > /dev/null && git st && git up

echo "\033[1;31mUpdating node-build with git...\033[0m"
cd ~/.nodenv/plugins/node-build && git ru > /dev/null && git st && git up

echo "\033[1;31mUpdating vundle with git...\033[0m"
cd ~/.vim/bundle/vundle && git ru > /dev/null && git st && git up

cd "$ACTUAL_WD"

echo "\033[1;31m/etc/hosts...\033[0m"
echo "Current: `cat /etc/hosts | grep Updated | awk '{print $4}'`"
echo "Latest: `curl http://winhelp2002.mvps.org/hosts.txt > /tmp/hosts.txt 2> /dev/null ; cat /tmp/hosts.txt | grep Updated | awk '{print $4}'`"


echo "\033[1;31mCOMPLETED!\033[0m"
