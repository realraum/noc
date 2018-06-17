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

echo "installing $name with $distro/$codename"
echo ""

echo "######## running the install playbook ########"
exec ansible-playbook -e "hostname=$name" -e "distro=$distro" -e "distcodename=$codename" $@ $(basename "$0" .sh).yml
