#!/bin/sh
set -eu

if [ $# -eq 0 ]; then
    echo "Usage: $0 hostname [hostname ...]" >&2
    exit 1
fi

cd "$(dirname "$0")"

for hostname in "$@"; do
    ansible-playbook -e hostname="${hostname}" remove_known_hosts.yml
done
