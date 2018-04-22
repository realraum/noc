#!/bin/bash

if [ -z "$1" ]; then
  echo "$0 <host>"
  exit 1
fi

SHORT="r3-${1%%.*}"
SSH_HOST=$(ssh -G "$SHORT" | grep "^hostname " | awk '{ print($2) }' )

for name in $SHORT $SSH_HOST; do
  ssh-keygen -f "$HOME/.ssh/known_hosts" -R "[$name]:22000"
done

exit 0
