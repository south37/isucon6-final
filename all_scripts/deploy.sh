#!/bin/bash

HOST1="54.238.174.46"
HOST2="13.114.230.223"
HOST3="54.250.245.52/"
HOST4="54.199.141.147"
HOST5="54.238.182.113"

NGINX_HOSTS="${HOST2}"
for i in ${WEB_HOSTS[@]}; do echo $i; ssh -i ${HOME}/.ssh/id_rsa "isucon@${i}" 'hostname && git pull origin master && /home/isucon/scripts/deploy_nginx.sh'; done

WEB_HOSTS="${HOST1} ${HOST2} ${HOST4} ${HOST5}"
for i in ${WEB_HOSTS[@]}; do echo $i; ssh -i ${HOME}/.ssh/id_rsa "isucon@${i}" 'hostname && git pull origin master && /home/isucon/scripts/deploy_app.sh'; done
