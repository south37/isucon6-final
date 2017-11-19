#!/bin/bash

HOST1="54.238.174.46"
HOST2="13.114.230.223"
HOST3="54.250.245.52"
HOST4="54.199.141.147"
HOST5="54.238.182.113"

WEB_HOSTS="${HOST1} ${HOST2} ${HOST4} ${HOST5}"
echo "Start Healthcheck..."
for i in ${WEB_HOSTS[@]}; do echo "" && echo $i; echo "http://${i}:8080/api/rooms" && (curl "http://${i}:8080/api/rooms" -LI -o /dev/null -w '%{http_code}\n' -s) && echo "http://${i}:3000/" && (curl "http://${i}:3000/"  -LI -o /dev/null -w '%{http_code}\n' -s); done
echo "Complete Healthcheck!"
