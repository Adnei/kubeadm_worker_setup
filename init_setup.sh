#!/bin/bash

# TODO:
# First version
# - Maybe spliting fuctionalitis into different files, e.g:
#    - init_setup.sh --> takes care of basic steps for configuring the new worker node (locale + network setup)
#    - worker_setup.sh --> kubernetes configuration for the new worker node. It includes eventual firewal settings.


if ! [ $(id -u) = 0 ]; then
   echo "Run it as root"
   #exit 1
fi

local_ip=$1

echo "We got $# params"
echo ${local_ip}

#TODO: 
#   Fix Locale
#
#TODO: 
#   Set new static IP
nic=$(ip -br link | grep -v LOOPBACK | awk '{ print $1 }')
network_config_file="00-installer-config.yaml"

$(cp 00-installer-config.yaml /etc/netplan/.)
$(cp ${network_config_file} /etc/netplan/${network_config_file})
$(sed -i "s/<nic>/${nic}/g" /etc/netplan/${network_config_file})
$(sed -i "s/<local_ip>/${local_ip}/g" /etc/netplan/${network_config_file})
$(netplan apply)

echo "-----###-----###-----###-----###-----###-----###-----###"
echo "Static IP configured. --> Check /etc/netplan/${network_config_file}"
$(ip a)
echo "-----###-----###-----###-----###-----###-----###-----###"
#echo ${mac}
