#!/usr/bin/env sh

alias cp="cp -v"
alias rm="rm -v"

echo "\033[1;31mBacking up non-system files...\033[0m"
cp update_scripts.sh /tmp
cp restore_scripts.sh /tmp
cp README.md /tmp
rm -rf /tmp/tool-sync
cp -r tool-sync /tmp

echo "\033[1;31mRemoving files...\033[0m"
rm -vr *

echo "\033[1;31mRestoring non-system files...\033[0m"
cp /tmp/update_scripts.sh .
cp /tmp/restore_scripts.sh .
cp /tmp/README.md .
cp -r /tmp/tool-sync .

# Copy all bash scripts, except .bash_history
cp -r ~/bash_scripts .
cp ~/.bash* .
rm .bash_history

# Copy gitconfig
cp ~/.gitconfig .
cp ~/.gitignore .
cp ~/.gitattributes .

# Copy vimrc
cp ~/.vimrc .

# Copy tmux configuration
cp ~/.tmux.conf .

# Copy VSCode settings
mkdir -p VSCode
cp ~/.config/Code/User/settings.json VSCode
cp ~/.config/Code/User/keybindings.json VSCode
code --list-extensions > VSCode/extensions.list

# Copy Custom Git Commands
cp -r ~/git-hooks .
cp -r ~/Custom-Git-Commands .

echo "📦 Backing up APT and snap packages..."
apt-mark showmanual > apt-packages.list

# Snap packages
snap list > snaps.list

echo "\033[1;31mUpdating version managers...\033[0m"
bash -c "cd ~/.rbenv; git pull"
bash -c "cd ~/.rbenv/plugins/ruby-build; git pull"

echo "\033[1;31mCopying over version manager configs...\033[0m"
rbenv versions > ruby.versions

mkdir -p version-manager-config
cp ~/.rbenv/version version-manager-config/rbenv-version

rbenv rehash

echo "\033[1;31mListing all executables in \$PATH...\033[0m"
ruby -e '`echo $PATH`.strip.split(":").uniq.each {|path| puts `ls #{path}`}' | sort | uniq > executables.list
ruby -e '`echo $PATH`.strip.split(":").uniq.each {|path| puts `ls #{path}`}' | sort | uniq | xargs -n 1 which -a | xargs -n 1 md5sum > executables_digest.list 2> /dev/null

echo "\033[1;31mSyncing tools...\033[0m"
./tool-sync/obs/sync.sh

echo "\033[1;31mGetting ollama models list...\033[0m"
ollama list > ollama.list

echo "\033[1;31mUpdating apt...\033[0m"
sudo apt update

echo "\033[1;31mUpgradable apt packages...\033[0m"
sudo apt list --upgradable

echo "\033[1;31mUpgradable snap packages...\033[0m"
snap refresh --list

unalias cp
unalias rm

# Remove silently
rm bash_scripts/aliases/.*_secret
rm -rf bash_scripts/third_party

echo "\033[1;31mRefreshing ollama models list...\033[0m"
ollama list | awk 'NR>1 {print $1}' | xargs -n 1 ollama pull
ollama list | awk '{print $1, $2, $3}' > ollama.list

echo "\033[1;31mCOMPLETED!\033[0m"
