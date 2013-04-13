# Remove all except update_scripts.sh
cp update_scripts.sh /tmp
ls -A | xargs rm -rv
cp /tmp/update_scripts.sh .

# Copy all bash scripts, except .bash_history
cp -r ~/bash_scripts .
cp ~/.bash* .
rm .bash_history

# Copy gitconfig
cp ~/.gitconfig .

# Copy Custom Git Commands
cp -r ~/Custom-Git-Commands .

# Copy Leiningen global profile
cp -r ~/.lein .

# List of Brew installations
brew list > list_of_brews
