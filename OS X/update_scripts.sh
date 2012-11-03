# Copy all bash scripts, except .bash_history
cp -r ~/bash_scripts .
cp ~/.bash* .
rm .bash_history

# List of Brew installations
brew list > list_of_brews

