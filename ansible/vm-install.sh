#!/bin/bash

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
  echo "$0 <vm> <distro> <codename>"
  exit 1
fi

echo "installing vm: $1 with $2/$3"
echo ""

echo "########## clearing old ssh host keys #########"
./remove-known-host.sh "$1"
echo ""

echo "######## running the install playbook ########"
exec ansible-playbook -e "vmname=$1" -e "vmdistro=$2" -e "vmdistcodename=$3" vm-install.yml
