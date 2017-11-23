#!/bin/bash

HOST1="54.238.174.46"
HOST2="13.114.230.223"
HOST3="54.250.245.52"
HOST4="54.199.141.147"
HOST5="54.238.182.113"

TARGET="master"

if [ "$#" = 1 ]; then
  echo "deploy $1..."
  TARGET="$1"
fi

LOAD_COMMAND="git checkout master && git pull origin master && git fetch origin ${TARGET} && git checkout ${TARGET} && git pull origin ${TARGET} && git merge master"

NGINX_COMMAND="hostname && ${LOAD_COMMAND} && /home/isucon/scripts/deploy_nginx.sh"
NGINX_HOSTS="${HOST2}"
echo "Deploy nginx..."
echo "COMMAND: ${NGINX_COMMAND}"
for i in ${NGINX_HOSTS[@]}; do
  echo ""
  echo $i
  ssh "isucon@${i}" "${NGINX_COMMAND}"
done
echo "Deployed nginx!"
echo ""

WEB_COMMAND="hostname && ${LOAD_COMMAND} && /home/isucon/scripts/deploy_service.sh && /home/isucon/scripts/deploy_app.sh"
WEB_HOSTS="${HOST1} ${HOST2} ${HOST4} ${HOST5}"
echo "Deploy app..."
echo "COMMAND: ${WEB_COMMAND}"
for i in ${WEB_HOSTS[@]}; do
  echo ""
  echo $i
  ssh "isucon@${i}" "${WEB_COMMAND}"
done
echo "Deployed app!"
