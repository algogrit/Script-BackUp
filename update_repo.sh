# Log and push
git add .
git commit -m "Updated Scripts in $(uname -s) on $(date)"
git remote update
git pull
git push

