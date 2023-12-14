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
echo "Worker node setup starting..."

if ! [ $(id -u) = 0 ]; then
   echo -e "Run it as root.\nExiting"
   exit 1
fi


if [ -z "$1" ]
  then
    echo "No argument supplied."
    echo -e "Cluster join command required as argument.\nExiting"
    exit 1
fi

cluster_join_command=$1

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

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
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

echo -e "Installing and configuring Containerd\n"
echo -e "Proceeding with Containerd v1.7.11. Please, check https://github.com/containerd/containerd/releases for other releases\n"

wget https://github.com/containerd/containerd/releases/download/v1.7.11/containerd-1.7.11-linux-amd64.tar.gz
tar Cxvf /usr/local containerd-1.7.11-linux-amd64.tar.gz

# FIXME
#   systemd only!!
#   Should parameterize versions
#   Maybe select the latest version as default instead of static versions

wget -O /usr/local/lib/systemd/system/containerd.service https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
systemctl daemon-reload
systemctl enable --now containerd

echo -e "Installing runc. Proceeding with version v1.1.10. Please, check https://github.com/opencontainers/runc/releases for other releases\n"
wget https://github.com/opencontainers/runc/releases/download/v1.1.10/runc.amd64
install -m 755 runc.amd64 /usr/local/sbin/runc

echo -e "Installing CNI plugins. Proceeding with CNI Plugins v1.4.0. Please, check https://github.com/containernetworking/plugins/releases for other releases\n"
wget https://github.com/containernetworking/plugins/releases/download/v1.4.0/cni-plugins-linux-amd64-v1.4.0.tgz
mkdir -p /opt/cni/bin
tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.4.0.tgz

echo -e "Setting cgroup drive to systemd\n"
containerd config default | sudo tee /etc/containerd/config.toml
sed -i 's/            SystemdCgroup = false/            SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd

echo -e "Installing kubeadm, kubelet and kubectl. Defaults to v1.28\n"
apt update
mkdir -m 755 /etc/apt/keyrings
apt install -y apt-transport-https ca-certificates curl gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
apt update
apt install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

echo -e "Joining cluster...\n"
eval $cluster_join_command
