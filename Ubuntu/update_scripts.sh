# Copy all bash scripts, except .bash_history
cp -r ~/bash_settings .
cp ~/.bash* .
rm .bash_history

# Aptitude Package Listings
aptitude search '~i' > package_list

# Log and push
git add .
git commit -am "Updated Ubuntu Scripts on $(date)"
git remote update
git pull
git push

