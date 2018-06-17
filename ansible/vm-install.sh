#!/bin/bash

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
  echo "$0 <vm> <distro> <codename>"
  exit 1
fi

name=$1
shift
distro=$1
shift
codename=$1
shift

echo "installing vm: $name with $distro/$codename"
echo ""

echo "######## running the install playbook ########"
exec ansible-playbook -e "vmname=$name" -e "vmdistro=$distro" -e "vmdistcodename=$codename" $@ vm-install.yml
