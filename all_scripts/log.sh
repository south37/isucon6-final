#!/bin/bash

. "$(pwd)/all_scripts/hosts.txt"

COMMAND="hostname && /home/isucon/scripts/log_ruby.sh"
for i in ${HOSTS[@]}; do
  echo ""
  echo $i
  ssh "isucon@${i}" "${COMMAND}"
done
echo ""
