#!/bin/bash

# Hello, World!
#   init_setup is a simple script for configuring time sync (via timedatectl) and setting static ip configurations

# TODO:
# First version
# - Maybe spliting fuctionalitis into different files, e.g:
#    - init_setup.sh --> takes care of basic steps for configuring the new worker node (locale + network setup)
#    - worker_setup.sh --> kubernetes configuration for the new worker node. It includes eventual firewal settings.

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

if ! [ $(id -u) = 0 ]; then
   echo -e "${RED}Error: This script needs root privileges. Run it as root/sudo${NC}"
   exit 1
fi


echo -e "${GREEN}Starting full setup configuration${NC}\n"

#TODO:
#   Time Sync (NTP)
echo "- - - - - Starting Time Sync (NTP) - - - - -"

# TODO:
#   Static timezone. Worth it to parametrize?
timedatectl set-timezone America/Sao_Paulo
cp timesyncd.conf /etc/systemd/.
# FIXME:
#   'set-ntp true' might not work
#   We have to ensure 'set-ntp true' before testing server sync
timedatectl set-ntp true
systemctl restart systemd-timesyncd.service
echo "Wait until server sync"
is_sync="no"
set_timeout=100
count=0

until [[ "$is_sync" == "yes" ]]; do
  echo "Chekcing server sync..."
  sleep 5
  is_sync=$(timedatectl | grep "System clock synchronized" | awk '{print $4}')
  count=$((count + 1))
  if [[ $count == $set_timeout ]]; then
    echo "Server sync timeout!"
    echo "Try checking 'systemctl status systemd-timesyncd'"
    echo "Exiting"
    exit 1
  fi
done

# systemctl status systemd-timesyncd
echo "- - - - - Time Sync (NTP) Finished - - - - -"

#TODO: 
#   Set new static IP

if [[ ! -z "$1" && "$1" != 0 ]]; then 
  local_ip=$1
  nic=$(ip -br link | grep -v LOOPBACK | awk '{ print $1 }')
  network_config_file="00-installer-config.yaml"
  
  $(cp 00-installer-config.yaml /etc/netplan/.)
  $(cp ${network_config_file} /etc/netplan/${network_config_file})
  $(sed -i "s/<nic>/${nic}/g" /etc/netplan/${network_config_file})
  $(sed -i "s/<local_ip>/${local_ip}/g" /etc/netplan/${network_config_file})
  $(netplan apply)

  echo "-----###-----###-----###-----###-----###-----###-----###"
  echo "Static IP configured. --> Check /etc/netplan/${network_config_file}"
  ip a
  echo "-----###-----###-----###-----###-----###-----###-----###"
  #echo ${mac}
else
  echo -e "${GREEN}Skipping static ip configuration${NC}\n"
fi


echo -e "${GREEN}- - - - - init setup DONE - - - - -${NC}\n"
#sudo apt update
## FIXME:
##   Parametrize worker setup run.
#sudo chmod 777 worker_setup.sh
#sudo ./worker_setup.sh
