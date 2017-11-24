#!/bin/bash

. "$(pwd)/all_scripts/hosts.txt"

TAIL_LENGTH=10

TARGETS="ruby react"

while [ "$1" != "" ]; do
  case "$1" in
    '-n' )
        TAIL_LENGTH=$2
        shift 2
        ;;
    '-t' )
        TARGETS=$2
        shift 2
        ;;
    * )
        shift 1
        ;;
  esac
done

COMMAND="hostname"
for t in ${TARGETS[@]}; do
  COMMAND="${COMMAND} && ( /home/isucon/scripts/log_${t}.sh | tail -n ${TAIL_LENGTH} )"
done

for i in ${HOSTS[@]}; do
  echo ""
  echo $i
  ssh "isucon@${i}" "${COMMAND}"
done
echo ""
