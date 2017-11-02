#!/bin/bash
gpg2 --decrypt --batch < "${BASH_SOURCE%/*}/vault-pass.gpg" 2> /dev/null
