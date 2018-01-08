#! /usr/bin/env sh

# Updating brew prior to any brew operations
brew update
brew cleanup

echo "\033[1;31mOutdated brews...\033[0m"
brew outdated
