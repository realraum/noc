#!/bin/bash
exec gpg2 --keyring "${BASH_SOURCE%/*}/vault-keyring.gpg" --secret-keyring /dev/null --no-default-keyring $@
