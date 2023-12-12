#!/bin/bash
#
#
# TODO
#   @Params:
#   node-ip
#   node-username
#   node-password
#   node type: controller or worker
#     worker only, for now
#
#   set-static-ip: changes current IP (received from dhcp, prob) to a static parameterized ip
#
# worker or controller setup.sh receives 'kubeadm token create --print-join-command --ttl=0' as argument

# FIXME
#   remove static ip configuration from init_setup.sh
#   static ip configuration will be a standalone script
#
# Display help message
help_fn() {

  echo -e "Insert a help message here!\n"

}

auth_fn(){

  # access param with $1 $2...
  ssh_dst=$1
  key_file=~/.ssh/id_rsa
  if [ ! -f "$key_file" ]; then
    ssh-keygen -b 2048 -t rsa -f $key_file -q -N ""
  fi
  ssh-copy-id $ssh_dst

}

dst_host=""
while getopts ":h:d:a:f" option; do
  case $option in
    h) # help message
      help_fn
      exit;;
    d) #destination --> <user>@<ip> format
      dst_host=$OPTARG
    a) # authentication
      # TODO:
      #   Needs to read <username>@<ip_address>
      #     <username> should be root
      #   Must validate this input
      if [["${dst_host}" == ""]] then
        echo -e "ERROR: arg -d is necessary for authentication.\n"
        echo -e "Set arg -d <user>@<host_ip>"
        exit 1
      fi
      auth_fn "$dst_host"
      # ssh-copy-id $OPTARG
    f) # full setup proccess. $OPTARG == 0 means no static ip configuration
      static_ip=$OPTARG
      sudo ./init_setup.sh ${static_ip}
      exit;;
    \?) # invalid opt
      echo "Error: Invalid option"
      exit;;
  esac
done
