#!/bin/bash
#
# TODO: Initial version
#   Prepares a worker node to join the cluster
#

echo "Worker node setup starting..."


# FIXME:
#   We should be careful with any repeated MAC address and PRODUCT_UUID in the cluster.
#   Maybe creating a list with all the MAC addresses in the cluster (?)

swapoff -a
# FIXME:
#   Swap must be permanently disabled in '/etc/fstab'
#   Use sed (or awk) to comment line with swap
sed -i.bak -r 's/(.+ swap .+)/#\1/' /etc/fstab

echo "swap disabled"
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
echo "\t TCP for NodePort Services"
echo "\t TCP/UDP for Kubelet API" # Could be TCP only
