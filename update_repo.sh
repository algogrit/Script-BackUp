#! /usr/bin/env sh

set -e

if [ -z "$HOSTNAME" ]; then
  HOSTNAME=$(hostname).local
fi

# Log and push
git add -A
git commit -m "Updated Scripts in $(uname -s) on $HOSTNAME"

git pull --rebase
git push

git pristine
