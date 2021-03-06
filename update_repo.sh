#! /usr/bin/env sh

set -e

# Log and push
git add -A
git commit -m "Updated Scripts in $(uname -s) on $HOSTNAME"

git pull --rebase
git push

git pristine
