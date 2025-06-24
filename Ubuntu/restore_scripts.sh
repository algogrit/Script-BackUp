#!/usr/bin/env bash

alias cp="cp -v"
alias rm="rm -v"

echo "\033[1;31mStarting the restore process...\033[0m"

echo "\033[1;31mCreating directories...\033[0m"
mkdir -p ~/bin ~/Custom-Git-Commands ~/git-hooks ~/.lein ~/.jenv/bin ~/.nodenv/bin ~/.elm ~/.vim/autoload

sudo apt-get install curl

echo "\033[1;31mRestoring Bash Scripts...\033[0m"
if [ ! -d ~/bash_scripts ]; then
  cp -r ~/Script-BackUp/Ubuntu/bash_scripts ~/bash_scripts
fi

mkdir -p ~/bash_scripts/third_party
wget -O ~/bash_scripts/third_party/z.sh https://raw.githubusercontent.com/rupa/z/refs/heads/master/z.sh

cp ~/Script-BackUp/Ubuntu/.bash* ~/
touch ~/bash_scripts/aliases/.personal_secret

echo "\033[1;31mRestoring git customizations...\033[0m"
cp ~/Script-BackUp/Ubuntu/Custom-Git-Commands/* ~/Custom-Git-Commands/

echo "\033[1;31mSetting up common repositories...\033[0m"
mkdir -p ~/Developer/Algogrit
git clone git@github.com:algogrit/gauravagarwalr.com.git ~/Developer/Algogrit/algogrit.com
git clone git@github.com:algogrit/blog.gauravagarwalr.com.git ~/Developer/Algogrit/blog
git clone git@github.com:gauravagarwalr/value-investing-with-analysis.git ~/Developer/Algogrit/value-investing-with-analysis
git clone git@bitbucket.org:algogrit/project-resources.git ~/Developer/Algogrit/project-resources
git clone git@bitbucket.org:algogrit/interview-challenges.git ~/Developer/Algogrit/interviews

mkdir -p ~/Developer/Consultant/AgarwalConsulting
git clone git@github.com:AgarwalConsulting/landing-page.git ~/Developer/Consultant/AgarwalConsulting/agarwalconsulting.io

mkdir -p ~/Developer/Consultant/CnI
git clone git@bitbucket.org:algogrit/contracts.git ~/Developer/Consultant/CnI/contracts
git clone git@bitbucket.org:algogrit/invoices.git ~/Developer/Consultant/CnI/invoices
git clone git@bitbucket.org:algogrit/quotation.git ~/Developer/Consultant/CnI/quotation

mkdir -p ~/Developer/Presentations
git clone git@github.com:algogrit/presentation-template.git ~/Developer/Presentations/presentation-template
echo talks > ~/Developer/Presentations/project-resources.branch
git clone --single-branch --branch talks git@bitbucket.org:algogrit/project-resources.git ~/Developer/Presentations/talk-ideas

git clone --single-branch --branch master-task-list git@bitbucket.org:algogrit/project-resources.git ~/Developer/Tasks
git clone git@github.com:algogrit/Training.git ~/Developer/Training
cd ~/Developer/Training
git submodule update --recursive --remote

cd ~/Script-BackUp/Ubuntu

echo "\033[1;31mSetting up VSCode...\033[0m"
cp ~/Script-BackUp/Ubuntu/VSCode/settings.json ~/.config/Code/User/
cp ~/Script-BackUp/Ubuntu/VSCode/keybindings.json ~/.config/Code/User/
cat ~/Script-BackUp/Ubuntu/VSCode/extensions.list | xargs -n 1 code --install-extension

echo "\033[1;31mInstalling ~/bin utilities...\033[0m"
wget -O ~/bin/flash https://raw.githubusercontent.com/hypriot/flash/master/flash
chmod +x ~/bin/flash

echo "\033[1;31mRestoring other configs...\033[0m"
cp ~/Script-BackUp/Ubuntu/.gitconfig ~/
cp ~/Script-BackUp/Ubuntu/.gitignore ~/
cp ~/Script-BackUp/Ubuntu/.tmux.conf ~/

# Other Installations
echo "\033[1;31mSetting up managers...\033[0m"

echo "\033[1;31mVim plugin manager...\033[0m"
curl -fLo ~/.vim/autoload/plug.vim https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

echo "\033[1;31mInstall vundle packages...\033[0m"
git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/vundle
vim +PlugInstall +qall

echo "\033[1;31mInstalling rbenv...\033[0m"
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
