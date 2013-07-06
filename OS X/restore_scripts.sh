alias cp="cp -v"
alias rm="rm -v"

echo "\033[1;31mBacking up to git stash before restoring...\033[0m"

./update_scripts.sh
git add .
git stash

echo "\033[1;31mStarting the restore process...\033[0m"

echo "Sorry I don't do much :-//"

echo "\033[1;31mRestoring git stash after restoring...\033[0m"
git stash pop

unalias cp
unalias rm
