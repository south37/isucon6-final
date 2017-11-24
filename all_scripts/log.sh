#!/bin/bash

. "$(pwd)/all_scripts/hosts.txt"

TAIL_LENGTH=10

# TODO(south37) Add tail options

COMMAND="hostname && ( /home/isucon/scripts/log_ruby.sh | tail -n ${TAIL_LENGTH} ) && ( /home/isucon/scripts/log_react.sh | tail -n ${TAIL_LENGTH} )"
for i in ${HOSTS[@]}; do
  echo ""
  echo $i
  ssh "isucon@${i}" "${COMMAND}"
done
echo ""
