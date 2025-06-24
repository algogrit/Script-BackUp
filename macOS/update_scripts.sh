#!/usr/bin/env sh

set -e

alias cp="cp -v"
alias rm="rm -v"

echo "\033[1;31mBacking up non-system files...\033[0m"
cp mini_update.sh /tmp
cp update_scripts.sh /tmp
cp restore_scripts.sh /tmp
cp read_android_packages.sh /tmp
cp android_packages.list /tmp
cp README.md /tmp
cp notes.txt /tmp
rm -rf /tmp/tool-sync
cp -r tool-sync /tmp

echo "\033[1;31mSetting permission prior to deletion...("'!'")\033[0m"
chmod 666 root/etc/irbrc

echo "\033[1;31mRemoving files...\033[0m"
rm -vr *

echo "\033[1;31mRestoring non-system files...\033[0m"
cp /tmp/mini_update.sh .
cp /tmp/update_scripts.sh .
cp /tmp/restore_scripts.sh .
cp /tmp/read_android_packages.sh .
cp /tmp/android_packages.list .
cp /tmp/README.md .
cp /tmp/notes.txt .
cp -r /tmp/tool-sync .

echo "\033[1;31mUpdating brew...\033[0m"

# Updating brew prior to any brew operations
brew update
brew cleanup

echo "\033[1;31mList brew related stuff...\033[0m"
# List of Brew installations
brew list --formula > brews.list

# List of Brew taps
brew tap > brew_taps.list
brew tap | xargs brew tap-info > brew_taps.info

# List of Brew Cask Installations
brew list --cask > brew_casks.list

# List of mac App Store installed apps
mas list > mas.list

# List of Custom installations
echo "\033[1;31mListing /Applications...\033[0m" | tee applications.list
ls /Applications | cut -d '.' -f 1 | uniq | sed '/^$/d' >> applications.list
echo "\033[1;31mListing User Applications...\033[0m" | tee -a applications.list
ls ~/Applications | cut -d '.' -f 1 | uniq | sed '/^$/d' >> applications.list

echo "\033[1;31mUpdating version managers...\033[0m"
bash -c "cd ~/vcpkg; git pull"

echo "\033[1;31mCopying over version manager configs...\033[0m"
rbenv versions > ruby.versions
nodenv versions > node.versions
pyenv versions | grep -v "-" > python.versions
goenv versions > go.versions
jenv versions > java.versions

mkdir -p version-manager-config
cp /usr/local/var/rbenv/version version-manager-config/rbenv-version
cp ~/.nodenv/version version-manager-config/nodenv-version
cp ~/.pyenv/version version-manager-config/pyenv-version
cp ~/.goenv/version version-manager-config/goenv-version
cp ~/.jenv/version version-manager-config/jenv-version

rbenv rehash
nodenv rehash
pyenv rehash
goenv rehash
jenv rehash

echo "\033[1;31mCopying fresh files...\033[0m"
# Copy all bash scripts, except .bash_history
cp -r ~/bash_scripts .
cp ~/.bash* .

# Copy gitconfig
cp ~/.gitconfig .
cp ~/.gitignore .

# Copy ag ignore config
cp ~/.ignore .

# Copy tigrc
cp ~/.tigrc .

# Copy vimrc
cp ~/.vimrc .

# Copy ruby related files
cp ~/.irbrc .
cp ~/.gemrc .

# Copy Sack/Sag config
cp ~/.sackrc .

# Copy .powconfig
cp ~/.powconfig .

# Copy Git Customizations
cp -r ~/Custom-Git-Commands .
cp -r ~/git-hooks .

# Copy Leiningen global profile
cp -r ~/.lein .
rm -f .lein/repl-history

# Copy tmux configuration
cp ~/.tmux.conf .

# Copy VSCode settings
mkdir -p VSCode
cp ~/Library/Application\ Support/Code/User/settings.json VSCode
cp ~/Library/Application\ Support/Code/User/keybindings.json VSCode
code --list-extensions > VSCode/extensions.list

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

# Copy bin executables
mkdir -p bin
cp ~/bin/howdoi bin/
cp ~/bin/jq-replace bin/

echo "\033[1;31mRemoving bash unnecessary files...\033[0m"
rm .bash_history

echo "\033[1;31mSyncing tools...\033[0m"
./tool-sync/obs/sync.sh

echo "\033[1;31mListing all executables in \$PATH...\033[0m"
ruby -e '`echo $PATH`.strip.split(":").uniq.each {|path| puts `ls #{path}`}' | sort | uniq > executables.list
ruby -e '`echo $PATH`.strip.split(":").uniq.each {|path| puts `ls #{path}`}' | sort | uniq | xargs -n 1 which -a | xargs -n 1 md5 > executables_digest.list 2> /dev/null | echo "completed listing execs with digest"

echo "\033[1;31mBrew info...\033[0m"
brew doctor --verbose 2>&1 | tee brew.info
brew info 2>&1 | tee -a brew.info

echo "\033[1;31mOutdated brews...\033[0m"
brew outdated

ACTUAL_WD=$PWD

# echo "\033[1;31mUpdating vundle with git...\033[0m"
# cd ~/.vim/bundle/vundle && git ru > /dev/null && git st && git up

# echo "\033[1;31mUpdating flutter with git...\033[0m"
# cd ~/Developer/experimental/sdk/flutter && git ru > /dev/null && git st && git up
# flutter --version > ~/Script-BackUp/OS\ X/flutter.version
# flutter doctor -v > ~/Script-BackUp/OS\ X/flutter.info

cd "$ACTUAL_WD"

unalias cp
unalias rm

# Remove silently
rm bash_scripts/aliases/.*_secret

echo "\033[1;31m/etc/hosts...\033[0m"
echo "Current: `cat /etc/hosts | grep Updated | awk '{print $4}'`"
echo "Latest: `curl https://winhelp2002.mvps.org/hosts.txt > /tmp/hosts.txt 2> /dev/null ; cat /tmp/hosts.txt | grep Updated | awk '{print $4}'`"

echo "\033[1;31mCOMPLETED!\033[0m"
