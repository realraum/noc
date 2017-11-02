#!/bin/bash

if [ -z "$1" ]; then
  echo "no keyfile specified, reading from stdin ..."
fi

"${BASH_SOURCE%/*}/gpg2.sh" --import $@
if [ $? -ne 0 ]; then
  echo -e "\nERROR: import key(s) failed. Please revert any changes of the file gpg/vault-keyring.gpg."
  exit 1
fi

echo ""
"${BASH_SOURCE%/*}/get-vault-pass.sh" | "${BASH_SOURCE%/*}/set-vault-pass.sh"
if [ $? -ne 0 ]; then
  echo -e "\nERROR: reencrypting vault password file failed!"
  echo "   You might want to revert any changes on gpg/vault-pass.gpg and gpg/vault-keyring.gpg!!"
  exit 1
fi
echo "Successfully reencrypted vault password file!"
echo "  Don't forget to commit the changes in gpg/vault-pass.gpg and gpg/vault-keyring.gpg."
