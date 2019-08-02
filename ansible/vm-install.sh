#!/bin/bash

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
  echo "$0 <hostname> <distro> <codename>"
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

rm -f ".cache/facts/$name"

echo "######## running the install playbook ########"
exec ansible-playbook -e "hostname=$name" -e "install_distro=$distro" -e "install_codename=$codename" $@ $(basename "$0" .sh).yml
