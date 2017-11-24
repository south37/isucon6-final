BRANCH_COMMAND="git branch | grep '*' | awk '{ print $2 }'"
COMMAND="hostname && git pull origin \$(${BRANCH_COMMAND}) && /home/isucon/scripts/rotate_and_cp.sh && git add . && git commit -m 'Add log' && git push origin \$(${BRANCH_COMMAND})"

for i in ${NGINX_HOSTS[@]}; do
  echo ""
  echo $i
  ssh "isucon@${i}" "${COMMAND}"
done

git pull origin
