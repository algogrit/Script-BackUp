# Remove all except update_scripts.sh
cp update_scripts.sh /tmp
echo "Removing files..."
ls -A | xargs rm -rv
echo "Copying fresh files..."
cp /tmp/update_scripts.sh .

# Copy all bash scripts, except .bash_history
cp -r ~/bash_scripts .
cp ~/.bash* .
rm .bash_history

# Copy gitconfig
cp ~/.gitconfig .

# Copy RVM global gemsets file
mkdir .rvm && mkdir .rvm/gemsets
cp ~/.rvm/gemsets/global.gems .rvm/gemsets

# Copy vimrc
cp ~/.vimrc .

# Copy vimpagerrc
cp ~/.vimpagerrc .

# Copy Custom Git Commands
cp -r ~/Custom-Git-Commands .

# Copy Leiningen global profile
cp -r ~/.lein .

# Copt tmux configuration
cp ~/.tmux.conf .

# Copt tmux configuration
cp -r ~/.tmuxinator .

# List of Brew installations
brew list > list_of_brews
