#!/bin/bash

if [ -z "$1" ]; then
  echo "$0 <host>"
  exit 1
fi

SHORT="$1"
SSH_HOST=$(ssh -G "$1" | grep "^hostname " | awk '{ print($2) }' )

for name in $SHORT $SSH_HOST; do
  ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$name"
done

exit 0
