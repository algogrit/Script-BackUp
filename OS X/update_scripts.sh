alias cp="cp -v"
alias rm="rm -v"

echo "\033[1;31mBacking up non-system files...\033[0m"
cp update_scripts.sh /tmp
cp restore_scripts.sh /tmp
cp README /tmp

echo "\033[1;31mRemoving files...\033[0m"
ls -A | xargs rm -vr

echo "\033[1;31mRestoring non-system files...\033[0m"
cp /tmp/update_scripts.sh .
cp /tmp/restore_scripts.sh .
cp /tmp/README .

echo "\033[1;31mCopying fresh files...\033[0m"
# Copy all bash scripts, except .bash_history
cp -r ~/bash_scripts .
cp ~/.bash* .

# Copy gitconfig
cp ~/.gitconfig .

# Copy RVM global gemsets file
mkdir .rvm && mkdir .rvm/gemsets
cp ~/.rvm/gemsets/global.gems .rvm/gemsets

# Copy vimrc
cp ~/.vimrc .

# Copy irbrc 
cp ~/.irbrc .

# Copy vimpagerrc
cp ~/.vimpagerrc .

# Copy Custom Git Commands
cp -r ~/Custom-Git-Commands .

# Copy Leiningen global profile
cp -r ~/.lein .

# Copy tmux configuration
cp ~/.tmux.conf .

# Copy tmux configuration
cp -r ~/.tmuxinator .

echo "\033[1;31mRemoving bash turd files...\033[0m"
rm .bash_history

echo "\033[1;31mList all installations...\033[0m"

# List of Brew installations
brew list > list_of_brews

# List of Custom installations
ls /Applications ~/Applications > list_of_applications

unalias cp
unalias rm

# Remove silently
rm bash_scripts/.pam_secret_aliases

echo "\033[1;31mCOMPLETED!\033[0m"
