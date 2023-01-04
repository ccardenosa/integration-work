#!/bin/bash

source $(dirname $0)/../.env

echo "------------------------------------"
echo -e "\e[1;31mCleaning up previous installation...\e[0m"
echo "------------------------------------"

function run_cmd {
  echo -e "\e[1;33mRunning: \033[1;37m$1\e[0m"
  eval $1
}

function delete_hub_cluster {
  if [[ -f /etc/systemd/system/kcli-cluster-plan.service ]];then
    echo
    echo "Removing kcli-cluster-plan service..."
    echo "-------------------------------------"
    echo
    run_cmd "systemctl status kcli-cluster-plan.service"
    run_cmd "systemctl stop kcli-cluster-plan.service"
    run_cmd "systemctl disable kcli-cluster-plan.service"
    run_cmd "rm -f /etc/systemd/system/kcli-cluster-plan.service"
  fi
  if [[ "$(kcli list cluster|grep $OCP_CLUSTER_NAME)" != "" ]];then
    echo
    echo "Removing virtual Hub cluster..."
    echo "-------------------------------"
    echo
    run_cmd "kcli list vm"
    run_cmd "kcli delete cluster ${OCP_CLUSTER_NAME} -y"
  fi
}

function uninstall_local_http_server {
  if [[ -d /opt/httpd ]];then
    echo
    echo "Uninstall Local HTTP Server..."
    echo "----------------------"
    echo
    run_cmd "ansible-playbook $(dirname $0)/prereqs/playbooks/05_httpd_local_server.yml --tags remove-http-server"
    run_cmd "rm -fr /opt/httpd"
  fi
}

function remove_assest_dir {
  if [[ -d /opt/assets ]];then
    echo
    echo "Removing assest dir..."
    echo "----------------------"
    echo
    run_cmd "rm -fr /opt/assets"
  fi
}

function delete_libvirt_bridge_network {
  if [[ "$(kcli list networks |grep $HUB_CLUSTER_NETWOTK_NAME)" != "" ]];then
    echo "Deleting libvirt '$HUB_CLUSTER_NETWOTK_NAME' network..."
    run_cmd "kcli list networks"
    run_cmd "kcli delete network ${HUB_CLUSTER_NETWOTK_NAME} -y"
  fi
}

function delete_net_bridge {
  if [[ -z $HUB_CLUSTER_NETWOTK_NAME ]];then
    HUB_CLUSTER_NETWOTK_NAME="hubnetwork"
  fi

  if [[ -z $HUB_CLUSTER_NETWOTK_BRIDGE_DEVNAME ]];then
    HUB_CLUSTER_NETWOTK_BRIDGE_DEVNAME="eno12399"
  fi

  conname_br="${HUB_CLUSTER_NETWOTK_NAME}-br"
  conname_dev="${HUB_CLUSTER_NETWOTK_NAME}-dev"

  if [[ -x /sys/class/net/${conname_dev} ]]; then
    echo
    echo "Deleting '$HUB_CLUSTER_NETWOTK_NAME' net bridge..."
    echo "------------------------------------------------"
    echo
    run_cmd "nmcli con show"
    run_cmd "nmcli con delete ${conname_br}"
    run_cmd "nmcli con delete ${conname_dev}"
  fi
}

function delete_mirror-registry {

#[2022-11-16 11:26:58] Ansible Execution Environment Image: quay.io/quay/mirror-registry-ee:latest
#[2022-11-16 11:26:58] Pause Image: registry.access.redhat.com/ubi8/pause:8.6-21
#[2022-11-16 11:26:58] Quay Image: registry.redhat.io/quay/quay-rhel8:v3.7.10
#[2022-11-16 11:26:58] Redis Image: registry.redhat.io/rhel8/redis-6:1-88.1666660352
#[2022-11-16 11:26:58] Postgres Image: registry.redhat.io/rhel8/postgresql-10:1-202.1666660384

  if [[ -x /usr/bin/mirror-registry ]]; then
    echo
    echo "Deleting 'mirror-registry' installation..."
    echo "------------------------------------------------"
    echo
    run_cmd "mirror-registry uninstall"
    run_cmd "rm -fr /etc/quay-install /usr/bin/mirror-registry /usr/bin/execution-environment.tar"
    imgs=("mirror-registry-ee pause quay-rhel8 redis postgresql")
    for img in ${imgs[@]}; do
      run_cmd "podman image list $img --noheading | awk '{print \$1\":\"\$2}' | xargs -I % podman image rm %"
    done
  fi
}

delete_mirror-registry
delete_hub_cluster
delete_libvirt_bridge_network
delete_net_bridge
uninstall_local_http_server
remove_assest_dir
