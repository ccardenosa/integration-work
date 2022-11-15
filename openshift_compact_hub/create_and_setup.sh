#!/bin/bash

source $(dirname $0)/../.env

if [[ "$CLEANUP_ENV" == "yes" ]]; then
  read -p "You are about to delete your current installation. Are you sure? [y/N]: " proceed_and_delete
  if [[ "$proceed_and_delete" == "y" ]]; then
    $(dirname $0)/cleanup.sh
  fi
fi

function run_cmd {
  echo -e "\e[1;33mRunning: \033[1;37m$1\e[0m"
  eval $1
}

echo
echo "------------------------------------"
echo -e "\e[1;32mStarting enviroment installation...\e[0m"
echo "------------------------------------"
echo
contxt=$(dirname $0)/prereqs/playbooks
for f in $(ls $contxt/*yml); do
  cmd="ansible-playbook $f"
  run_cmd "$cmd"
done

echo
echo "------------------------------------"
echo -e "\e[1;32mDeploy OCP cluster...\e[0m"
echo "------------------------------------"
echo
cmd="ansible-playbook $(dirname $0)/deploy/playbooks/deploy_cluster.yaml"
run_cmd "$cmd"
