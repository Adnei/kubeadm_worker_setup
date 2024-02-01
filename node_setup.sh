#!/bin/bash

# Hello, World!
#   worker_setup is a script for preparing nodes to join a kubernetes cluster as working nodes.
#   It turns off swap, updates firewall rules, etc... all that of stuff required for a worker node.
#   It requires a cluster join command, which can be obtained through "kubeadm token create --print-join-command --ttl=0'" command in your controller

# TODO: Initial version
#   Prepares a worker node to join the cluster
#   Create a controller_setup, derivating from worker_setup
#
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
echo "Node setup starting..."

if ! [ $(id -u) = 0 ]; then
   echo -e "Run it as root.\nExiting"
   exit 1
fi


if [ -z "$1" ]
  then
    echo "No argument supplied."
    echo -e "Cluster join or cluster_creation command required as argument.\nExiting"
    exit 1
fi

cluster_command=$1

# FIXME:
#   We should be careful with any repeated MAC address and PRODUCT_UUID in the cluster.
#   Maybe creating a list with all the MAC addresses in the cluster (?)

swapoff -a
# FIXME:
#   Swap must be permanently disabled in '/etc/fstab'
#   Use sed (or awk) to comment line with swap
sed -i.bak -r 's/(.+ swap .+)/#\1/' /etc/fstab

swap_value=$(free | grep Swap | awk '{print $2}')
if [[ "${swap_value}" == 0 ]]; then
  echo -e "${GREEN}###################### swap disabled ######################${NC}\n"
else 
  echo -e "${RED}ERROR\nSwap allocated memory greater than 0.\nFix swap before installing Kubernetes!!!${NC}"
  exit 1
fi
# TODO:
#   Multiple Network Adapter Support.
#   To create IP routes so the Kubernetes Cluster addresses go via the appropriate  addresses go via the appropriate adapter.

########################################################################################
# --> Kubernetes Ports: 
#        --> https://kubernetes.io/docs/reference/networking/ports-and-protocols/
# Allow TCP for the services (NodePort Services)
ufw allow 30000:32767/tcp

# Allow TCP for the Kubelet API
ufw allow 10250 # This opens up for TCP and UDP.. guess it's not a problem
########################################################################################

echo "Ports for worker node open:"
echo -e "\tTCP for NodePort Services"
echo -e "\tTCP/UDP for Kubelet API" # Could be TCP only
echo -e "${GREEN}###################### Firewall Rules Updated ######################${NC}\n"

# From https://kubernetes.io/docs/setup/production-environment/container-runtimes/
echo -e "IPv4 Forwarding and IPtables with bridged traffic\n\n"

cat <<EOF | sudo tee /etc/modules-load.d/crio.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

echo -e "\n\n"

br_netfilter=$(lsmod | grep br_netfilter | awk 'NR==1{print $1}')
overlay=$(lsmod | grep overlay | awk 'NR==1{print $1}')

if [[ ! -z "$br_netfilter" && ! -z "$overlay" ]]; then
  echo -e "${GREEN}###################### br_netfilter and overlay modules loaded ######################${NC}\n"
else
  echo -e "${RED}ERROR\n br_netfilter and overlay modules NOT loaded${NC}\n"
  exit 1
fi

iptables_bridge=$(sysctl net.bridge.bridge-nf-call-iptables | awk '{print $3}')
ip6tables_bridge=$(sysctl net.bridge.bridge-nf-call-ip6tables | awk '{print $3}')
ipv4_forward=$(sysctl net.ipv4.ip_forward | awk '{print $3}')

if [[ "${iptables_bridge}" != 1 || "${ip6tables_bridge}" != 1 || "${ipv4_forward}" != 1 ]]; then
  echo -e "${RED}ERROR\nIPv4 and/or iptables bridge FAILED!${NC}"
  echo "Try checking 'sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward'"
  echo "All of the system variables must be set as 1"
  exit
else
  echo -e "${GREEN}###################### IPv4 Forwarding and iptables bridge successfully configured ######################${NC}"
fi

echo -e "\n\n"

# TODO:
#   cgroup drivers
#   https://kubernetes.io/docs/setup/production-environment/container-runtimes/#cgroup-drivers
#
# TODO/FIXME:
#   cgroupfs is not supported up to now!!!
#   We consider systemd as the init system
#   This script should verify the init system and apply the suitable cgroup driver
#
sed -i "s|<net-int>|$2|g" 
./common.sh
apt-mark hold kubelet kubeadm kubectl

echo -e "Joining or creating cluster...\n"
eval $cluster_command
