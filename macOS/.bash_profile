# The following lines were added by Docker Desktop to add commands to your PATH.
export PATH="$PATH:/Users/gaurav/.docker/bin"
# End of Docker Desktop section.

# export BASH_STARTUP_DEBUG=0
[ -f ~/bash_scripts/.bash_startup_helpers ] && . ~/bash_scripts/.bash_startup_helpers
bash_startup_log "~/.bash_profile Loaded"
bash_startup_source ~/bash_scripts/.bash_load
