#!/bin/bash

HOST1="54.238.174.46"
HOST2="13.114.230.223"
HOST3="54.250.245.52"
HOST4="54.199.141.147"
HOST5="54.238.182.113"

HOSTNAME1="HOST1"
HOSTNAME2="HOST2"
HOSTNAME3="HOST3"
HOSTNAME4="HOST4"
HOSTNAME5="HOST5"

HOSTS="1 2 3 4 5"
COMMAND="git status"
echo "Check branch status..."
echo "COMMAND: ${COMMAND}"
for i in ${HOSTS[@]}; do
  echo ""
  HOST=`eval "echo \$HOST$i"`
  HOSTNAME=`eval "echo \$HOSTNAME$i"`
  echo "${HOSTNAME}: ${HOST}"
  ssh "isucon@${HOST}" "${COMMAND}"
done
