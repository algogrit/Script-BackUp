echo "~/bash_settings/.bash Loaded"

# Sourcing RVM
[[ -s "$HOME/.rvm/scripts/rvm" ]] &&. "$HOME/.rvm/scripts/rvm"

# Sourcing NVM - Node Version Manager
. ~/.nvm/nvm.sh

# Adding bin to the PATH
export PATH=~/bin:$PATH
