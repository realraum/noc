#!/bin/bash

if [ -z "$1" ]; then
  echo "Please specify at least one key ID!"
  echo ""
  echo "You can find out the key ID using the command: gpg/list-keys.sh"
  echo ""
  echo " Here is an example output:"
  echo ""
  echo "   pub   rsa4096/0x1234567812345678 2017-01-01 [SC] [expires: 2019-01-01]"
  echo "         Key fingerprint = 1234 5678 1234 5678 1234  5678 1234 5678 1234 5678"
  echo "   uid                   [ unknown] Firstname Lastname <lastname@example.com>"
  echo "   sub   rsa4096/0x8765432187654321 2017-01-01 [E] [expires: 2019-01-01]"
  echo ""
  echo " The key ID is the hexadecimal number next to rsa4096/ in the line"
  echo " starting with pub (not sub). In this case the key ID is: 0x1234567812345678"
  echo ""
  exit 1
fi

"${BASH_SOURCE%/*}/gpg2.sh" --delete-keys $@
if [ $? -ne 0 ]; then
  echo -e "\nERROR: removing key(s) failed. Please revert any changes of the file gpg/vault-keyring.gpg."
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
