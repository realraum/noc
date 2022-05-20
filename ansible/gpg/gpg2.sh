#!/bin/bash

BIN=$(which gpg2)
if [ $? -ne 0 ]; then
  BIN=$(which gpg)
fi

exec $BIN --keyring "${BASH_SOURCE%/*}/vault-keyring.gpg" --secret-keyring /dev/null --no-options --no-default-keyring --trust-model always --keyid-format 0xlong $@
