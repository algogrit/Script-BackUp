# export BASH_STARTUP_DEBUG=0
[ -f ~/bash_scripts/.bash_startup_helpers ] && . ~/bash_scripts/.bash_startup_helpers
bash_startup_log "~/.bashrc Loaded"
bash_startup_source ~/bash_scripts/.bash_load
