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


RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# TODO:
#   Display help message
help_fn() {
  echo -e "Insert a help message here!\n"
}

dst_validate(){
  # FIXME (?) / TODO
  #   Maybe we should validate if <ip_address> is a valid ip... however, user may pass a host alias too
  IFS='@' read -ra array <<< "$1"
  echo "array size: ${#array[@]}"

  if [ ! "${#array[@]}" -eq 2 ]; then
    echo -e "{$RED}Error: -d flag expects a destination host in format <user>@<ip_address or host alias>${NC}"
    exit 1
  fi

  echo -e "Configuring ssh key-pair for: $1\n"
}

auth_fn(){
  # access param with $1 $2...
  ssh_dst=$1
  key_file=~/.ssh/id_rsa
  if [ ! -f "$key_file" ]; then
    ssh-keygen -b 2048 -t rsa -f $key_file -q -N ""
  fi
  ssh-copy-id $ssh_dst

  echo "Hello destination host: $ssh_dst"
}

dst_host=""
current_dir=$(basename "`pwd`")

while getopts ":hd:ai:w" option; do
  case $option in
    h) # help message
      help_fn
      exit;;
    d) #destination: <user>@<ip or host alias> format
      dst_host=$OPTARG
      dst_validate "$dst_host"
      if ssh $dst_host "[ -d ~/'${current_dir}' ]"; then
        echo -e "WARNING: Project already exists inside remote host '${dst_host}'..."
        echo -e "Updating project on remote host '${dst_host}'"
        ssh $dst_host "rm -rf ~/'${current_dir}'"
      fi
      ssh $dst_host "git clone https://github.com/Adnei/kubeadm_worker_setup.git"
      ssh $dst_host "chmod 755 ~/'${current_dir}'/*.sh"
      ;;
    a) # authentication: does NOT require $OPTARG
      if [ -z "${dst_host}" ]; then
        echo -e "ERROR: arg -d is required for authentication.\n"
        echo -e "Set arg -d <user>@<host_ip>"
        exit 1
      fi
      auth_fn "$dst_host"
      ;;
    i) # init setup proccess. $OPTARG == 0 means no static ip configuration
      static_ip=$OPTARG
      if [ -z "${dst_host}" ]; then
        echo -e "ERROR: arg -d is required for authentication.\n"
        echo -e "Set arg -d <user>@<host_ip> as the first argument"
        exit 1
      fi

      # FIXME
      #   init_setup.sh does NOT verify if ${static_ip} is a valid IP...

      # TODO
      #  SSH first, then run script
      #sudo ./init_setup.sh ${static_ip}
      ssh -t ${dst_host} "cd ~/'${current_dir}'; sudo ./init_setup.sh '${static_ip}'"
      ;;
    w) # worker node add
      if [ -z "${dst_host}" ]; then
        echo -e "ERROR: arg -d is required for authentication.\n"
        echo -e "Set arg -d <user>@<host_ip> as the first argument"
        exit 1
      fi
      # incase the command for joining the cluster is not provided as argument,
      #   the scripts tries to run the print join command, as if it was running on the controller
      #eval nextopt=\${OPTIND}
      nextopt=${!OPTIND}
      if [[ -n $nextopt && $nextopt != -* ]]; then
        OPTIND=$((OPTIND + 1))
        cluster_join_command=$nextopt
      else
        cluster_join_command=$(kubeadm token create --print-join-command --ttl=0)
      fi
      echo -e "${GREEN}Using join command:\n ${cluster_join_command}${NC}\n"

      # TODO
      #  SSH first, then run script
      # sudo ./worker_setup.sh $cluster_join_command
      ssh -t ${dst_host} "sudo ~/'${current_dir}'/worker_setup.sh '${cluster_join_command}'"
      ;;
    \?) # invalid opt
      echo "Error: Invalid option"
      exit;;
  esac
done
