#!/bin/bash
exec "${BASH_SOURCE%/*}/gpg2.sh" --list-keys $@
