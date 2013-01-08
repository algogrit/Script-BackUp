# Copy all bash scripts, except .bash_history
cp -r ~/bash_scripts .
cp ~/.bash* .
rm .bash_history

# Copy gitconfig
cp ~/.gitconfig .

# Copy Leiningen global profile
cp ~/.lein/profiles.clj ./.lein

# List of Brew installations
brew list > list_of_brews

