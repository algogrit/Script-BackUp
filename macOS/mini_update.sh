#! /usr/bin/env sh

# Show any remote only commits
git ru
git status
git up

# Updating brew prior to any brew operations
brew update
brew cleanup

echo "\033[1;31mOutdated brews...\033[0m"
brew outdated

echo "\033[1;31mUpdating vundle with git...\033[0m"
cd ~/.vim/bundle/vundle && git ru > /dev/null && git st && git up

echo "\033[1;31m/etc/hosts...\033[0m"
echo "Current: `cat /etc/hosts | grep -m 1 'Date:' | awk '{print $3 " " $4 " " $5}'`"
echo "Latest: `curl https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts > /tmp/hosts.txt 2> /dev/null ; cat /tmp/hosts.txt | grep 'Date:' | awk '{print $3 " " $4 " " $5}'`"
