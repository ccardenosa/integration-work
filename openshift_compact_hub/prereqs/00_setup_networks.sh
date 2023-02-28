#!/bin/bash

: ${HUB_NETWORK:="hubnetwork-dev"}
: ${HUB_CLUSTER_NAME:="rhel9-ocp"}

hub_net_ipv4=172.16.55.0/24
hub_gw_ipv4=172.16.55.254
ip_range="172.16.55.100,172.16.55.200,255.255.255.0,4h"
opt_dns_1=172.16.55.254
opt_dns_2=10.11.5.160
opt_dns_3=10.2.70.215
ocp_apiserver=172.16.55.13
ocp_apps=172.16.55.14
opt_domain_name=telco5gran.eng.rdu2.redhat.cxm
dnsmasq_drop_in_conf=/etc/dnsmasq.d/00-hubnetwork.conf

function run_cmd {
  echo -e "\e[1;33mRunning: \033[1;37m$1\e[0m"
  eval $1
}

echo "Add GW IPv4 to ${HUB_NETWORK}"
run_cmd "/usr/sbin/ip a add ${hub_gw_ipv4}/24 dev ${HUB_NETWORK}"

echo "Add MASQUERADE rule to NAT table for ${hub_net_ipv4} network"
run_cmd "/usr/sbin/iptables -t nat -A POSTROUTING -j MASQUERADE -s ${hub_net_ipv4}"

echo "Generate dnsmasq config"
cat << EOF > ${dnsmasq_drop_in_conf}
interface=${HUB_NETWORK}

log-dhcp

server=${opt_dns_3}

port=53
dhcp-leasefile=/var/lib/dnsmasq/dnsmasq-hubnetwork-dev.leases

# Test
#dhcp-host=52:54:00:08:77:c1,ecascaz-vm,172.16.55.10

dhcp-range=${ip_range}
dhcp-option=option:router,${hub_gw_ipv4}
dhcp-option=option:dns-server,${opt_dns_1},${opt_dns_2}
dhcp-option=option:domain-name,${opt_domain_name}

##################################################################
# DNS section
##################################################################
# HUB:
host-record=api.${HUB_CLUSTER_NAME}.${opt_domain_name},${ocp_apiserver}
# Wild card records
address=/apps.${HUB_CLUSTER_NAME}.${opt_domain_name}/${ocp_apps}

# SNOs:
EOF

function select_mac {
  case $1 in
    "cnfdf23")
      sno_mac_addr="B4:96:91:C7:FF:6C"
      sno_ipv4_addr=172.16.55.20
      ;;
    "cnfdf24")
      sno_mac_addr="b4:96:91:c8:01:08"
      sno_ipv4_addr=172.16.55.21
      ;;
    *)
      echo "Invalid node $1"
      exit 1
  esac
}

#SNOs:
sno_clusters=(cnfdf23 cnfdf24)
for cl in ${sno_clusters[@]}; do
  select_mac ${cl}
  echo >> ${dnsmasq_drop_in_conf}
  echo "# SNO ${cl} settings:" >> ${dnsmasq_drop_in_conf}
  echo "dhcp-host=${sno_mac_addr},${cl}.${opt_domain_name},${sno_ipv4_addr}" >> ${dnsmasq_drop_in_conf}
  echo "host-record=api.${cl}.${opt_domain_name},${sno_ipv4_addr}" >> ${dnsmasq_drop_in_conf}
  echo "# Wild card records" >> ${dnsmasq_drop_in_conf}
  echo "address=/apps.${cl}.${opt_domain_name}/${sno_ipv4_addr}" >> ${dnsmasq_drop_in_conf}
done

echo "Start up dnsmasq service..."
run_cmd "systemctl reload-or-restart dnsmasq.service"
run_cmd "systemctl status dnsmasq.service"

run_cmd "sed -i '/#/a nameserver ${hub_gw_ipv4}' /etc/resolv.conf"
run_cmd "sed -i '/#/a search ${opt_domain_name}' /etc/resolv.conf"
