#!/bin/bash

HOST1="54.238.174.46"
HOST2="13.114.230.223"
HOST3="54.250.245.52"
HOST4="54.199.141.147"
HOST5="54.238.182.113"

if [ "$#" -ne 1 ]; then
  echo "You must specify branch!"
  exit 1
fi

HOSTS="${HOST1} ${HOST2} ${HOST3} ${HOST4} ${HOST5}"
COMMAND="git checkout $1"
echo "Checkout branch..."
echo "COMMAND: ${COMMAND}"
i=1
for host in ${HOSTS[@]}; do echo "" && echo "HOST${i}: ${host}"; ssh "isucon@${host}" "${COMMAND}"; i=$((i+1)); done
