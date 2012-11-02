# Copy all bash scripts, except .bash_history
cp -r ~/bash_scripts .
cp ~/.bash* .
rm .bash_history

# List of Brew installations
brew list > list_of_brews

# Log and push
git commit -am "Updated Mac Scripts on $(date)"
git remote update
git pull
git push

