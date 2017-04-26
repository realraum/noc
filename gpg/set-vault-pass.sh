#!/bin/bash

keyids=$("${BASH_SOURCE%/*}/gpg2.sh" --list-keys --with-colons --fast-list-mode 2>/dev/null | awk -F: '/^pub/{printf "%s\n", $5}')
if [ -z "$keyids" ]; then
  echo "ERROR: no keys to encrypt to, is the keyring empty?"
  exit 1
fi

receipients=""
for keyid in $keyids; do
  receipients="$receipients -r $keyid"
done


"${BASH_SOURCE%/*}/gpg2.sh" --yes --trust-model always --encrypt -a -o "${BASH_SOURCE%/*}/vault-pass.gpg.$$" $receipients
if [ $? -ne 0 ]; then
  rm -f "${BASH_SOURCE%/*}/vault-pass.gpg.$$"
  exit 1
fi
mv "${BASH_SOURCE%/*}/vault-pass.gpg.$$" "${BASH_SOURCE%/*}/vault-pass.gpg"
