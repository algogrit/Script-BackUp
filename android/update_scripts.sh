#!/data/data/com.termux/files/usr/bin/env bash

pkg list-installed > pkg.list

echo "\033[1;31mRestoring Bash Scripts...\033[0m"
if [ ! -d ~/bash_scripts ]; then
  cp -r ~/bash_scripts ~/Script-BackUp/android/bash_scripts
fi

echo "\033[1;31mRestoring bash scripts...\033[0m"
cp ~/.bash* ~/Script-BackUp/android/
touch ~/bash_scripts/aliases/.personal_secret

echo "\033[1;31mRestoring ssh config...\033[0m"
mkdir -p ~/Script-BackUp/android/.ssh/
cp ~/.ssh/config ~/Script-BackUp/android/.ssh/

echo "\033[1;31mRestoring ag config...\033[0m"
cp ~/.ignore ~/Script-BackUp/android/

echo "\033[1;31mClean up...\033[0m"
rm ~/.bash_history
