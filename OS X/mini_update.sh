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

echo "\033[1;31mUpdating flutter with git...\033[0m"
cd ~/Developer/experimental/sdk/flutter && git ru > /dev/null && git st && git up
flutter --version > ~/Script-BackUp/OS\ X/flutter.version
flutter doctor -v > ~/Script-BackUp/OS\ X/flutter.info
