#!/bin/bash

if [ -z "$1" ] || [ -z "$2" ] ; then
  echo "$0 <host(s)> <role>"
  exit 1
fi
hosts="$1"
shift
role="$1"
shift

echo "######## applying the role '$role' to host(s) '$hosts' ########"
exec ansible-playbook -e "myhosts=$hosts" -e "myrole=$role" $@ generic.yaml
