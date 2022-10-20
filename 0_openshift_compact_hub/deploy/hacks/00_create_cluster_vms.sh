#!/bin/bash

function assert_default_pool_exists {
  kcli list pool |grep 'default.*/var/lib/libvirt/images' > /dev/null
  if [ $? -ne 0 ];then
    echo "Creating default pool..."
    kcli create pool -p /var/lib/libvirt/images default
    setfacl -m u:$(id -un):rwx /var/lib/libvirt/images
  fi
  kcli list pool
}

VIRT_NIC="networkipv4v6"

assert_default_pool_exists

kcli create vm -P start=False -P memory=32000 \
                              -P numcpus=16 \
                              -P disks='[200,200,50,50,20,20,20]' \
                              -P nets=["{\"name\":\"${VIRT_NIC}\",\"nic\":\"ens3\",\"mac\":\"de:ad:be:ff:00:05\"}"] \
                              "${OCP_CLUSTER_NAME}"-master0

kcli create vm -P start=False -P memory=32000 \
                              -P numcpus=16 \
                              -P disks='[200,200,50,50,20,20,20]' \
                              -P nets=["{\"name\":\"${VIRT_NIC}\",\"nic\":\"ens3\",\"mac\":\"de:ad:be:ff:00:06\"}"] \
                              "${OCP_CLUSTER_NAME}"-master1

kcli create vm -P start=False -P memory=32000 \
                              -P numcpus=16 \
                              -P disks='[200,200,50,50,20,20,20]' \
                              -P nets=["{\"name\":\"${VIRT_NIC}\",\"nic\":\"ens3\",\"mac\":\"de:ad:be:ff:00:07\"}"] \
                              "${OCP_CLUSTER_NAME}"-master2
