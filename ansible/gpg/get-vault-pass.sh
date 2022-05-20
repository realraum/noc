#!/bin/bash

BIN=$(which gpg2)
if [ $? -ne 0 ]; then
  BIN=$(which gpg)
fi

$BIN --decrypt --batch < "${BASH_SOURCE%/*}/vault-pass.gpg" 2> /dev/null
