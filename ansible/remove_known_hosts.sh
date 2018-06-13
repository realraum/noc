#!/bin/sh
set -eu

if [ $# -eq 0 ]; then
    echo "Usage: $0 vmname [vmname ...]" >&2
    exit 1
fi

cd "$(dirname "$0")"

for vmname in "$@"; do
    ansible-playbook -e vmname="${vmname}" remove_known_hosts.yml
done
