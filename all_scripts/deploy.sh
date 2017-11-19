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

TARGET="master"

if [ "$#" = 1 ]; then
  echo "deploy $1..."
  TARGET="$1"
fi

NGINX_COMMAND="hostname && git fetch origin ${TARGET} && git checkout ${TARGET} && git pull origin ${TARGET} && /home/isucon/scripts/deploy_nginx.sh"
NGINX_HOSTS="2"
echo "Deploy nginx..."
echo "COMMAND: ${NGINX_COMMAND}"
for i in ${NGINX_HOSTS[@]}; do
  echo ""
  HOST=$(echo "HOST${i}")
  HOSTNAME=$(echo "HOSTNAME${i}")
  echo "${HOSTNAME}: ${HOST}"
  ssh "isucon@${HOST}" "${NGINX_COMMAND}"
done
echo "Deployed nginx!"
echo ""

WEB_COMMAND="hostname && git fetch origin ${TARGET} && git checkout ${TARGET} && git pull origin ${TARGET} && /home/isucon/scripts/deploy_app.sh"
WEB_HOSTS="${HOST1} ${HOST2} ${HOST4} ${HOST5}"
echo "Deploy app..."
echo "COMMAND: ${WEB_COMMAND}"
for i in ${WEB_HOSTS[@]}; do
  echo ""
  HOST=$(echo "HOST${i}")
  HOSTNAME=$(echo "HOSTNAME${i}")
  echo "${HOSTNAME}: ${HOST}"
  ssh "isucon@${HOST}" "${WEB_COMMAND}"
done
echo "Deployed app!"
