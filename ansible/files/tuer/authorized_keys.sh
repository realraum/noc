#!/bin/sh
# Copyright © 2018 nicoo <nicoo@realraum.at>
# Distributed under the WTFPL v2
#
#         DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                     Version 2, December 2004
#
#  Copyright (C) 2004 Sam Hocevar <sam@hocevar.net>
#
#  Everyone is permitted to copy and distribute verbatim or modified
#  copies of this license document, and changing it is allowed as long
#  as the name is changed.
#
#             DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#    TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#   0. You just DO WHAT THE FUCK YOU WANT TO.

# This script processes the tuergit repository located at KEYS_DIR
# and outputs authorized_keys data for sshd.
# It is meant to be used as an AuthorizedKeysCommand

set -e

KEYS_DIR=${KEYS_DIR:-'/var/tuer/keys.git'}
KEYS_OPTIONS='no-port-forwarding'

cd "${KEYS_DIR}"
if git config hooks.keys_branch 2>/dev/null; then
    KEYS_BRANCH="$(git config hooks.keys_branch)"
else
    KEYS_BRANCH="master"
fi

git show "${KEYS_BRANCH}:ssh/" |
    while read user; do
        [ -n "$user" ] || continue
        git show "${KEYS_BRANCH}:ssh/${user}" |
            while read key; do
                echo "command=\"${user}\",${KEYS_OPTIONS}" "${key}"
            done
    done
