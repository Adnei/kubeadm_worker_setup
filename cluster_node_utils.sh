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

while getopts ":hd:ai:w:c" option; do
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
      ssh -t ${dst_host} "cd ~/'${current_dir}'; sudo ./node_setup.sh '${cluster_join_command}'"
       kubectl label node ${dst_user} node-role.kubernetes.io/worker=worker
      ## verify worker node
     ## if # (kubectl get nodes | grep ${dst_user}) | awk '{print $3}' != 'worker'
        ##  then
        ##        echo -e "Node added but role not set as worker"
        ## exit 1; 
      ;;
   c) # adds a controller and sets up a k8s based on a configuration file "conifig_init.yaml" placed in the same directory
	   if [ -z "${dst_host}" ]; then
        echo -e "ERROR: arg -d is required for authentication.\n"
        echo -e "Set arg -d <user>@<host_ip> as the first argument"
        exit 1
      fi
	  ssh ${dst_host}
           cluster_creation_command=$(sudo kubeadm init --pod-network-cidr=192.168.0.0/24);
           ## Info on what's going on (command that is being executed, etc) should be provided in some way
        sudo ./node_setup.sh "${cluster_creation_command}"
		kubectl label node ${dst_user} node-role.kubernetes.io/controller=controller
		sudo ufw disable # beware of this.
		#setting up files system for proper mounting
		cd 
		cd ..
		cd ..
		cd /var/lib/
		sudo mkdir grafana/
		cd
		cd ..
		cd ..
		sudo mkdir prometheus/
		#deploying Persistent Volumes
		cd
		cd kubeadm_worker_setup/
		kubectl apply -f persistent-volume-instantiation-1.yaml
		kubectl apply -f persistent-volume-instantiation-2.yaml
		cd
		cd kubeadm_worker_setup/
		#setting up calico CNI
		echo "-------------------------WARNING----------------------------"
		echo "IT'S EXTREMELY LIKELY YOU WILL NEED TO SETUP THE CALICO CNI AGAIN WITH THE PROPER CLUSTER	CIDR"
		echo "YOU COULD ALSO CHANGE THE FILE custom-resources.yaml BEFORE RUNNING THE SCRIPT"
		cd
		cd kubeadm_worker_setup/
		cd new_calico/
		kubectl create -f tigera-operator.yaml
		kubectl create -f custom-resources.yaml
		kubectl taint nodes --all node-role.kubernetes.io/control-plane-
		kubectl taint nodes --all node-role.kubernetes.io/master-
		cd
	cd kubeadm_worker_setup/
		#setting up prometheus
		cd prometheus_test/
		kubectl create namespace monitoring
		kubectl create -f clusterRole.yaml	# it is inferred that there are the prometheus_test/ folder with the files required for a prometheus setup (for more -> https://devopscube.com/setup-prometheus-monitoring-on-kubernetes/)
		kubectl create -f prometheus_config-map.yaml 
		kubectl create -f prometheus-deployment-PV.yaml
		kubectl create -f prometheus-service.yaml
		cd
		cd kubeadm_worker_setup/
		# setting up grafana
		cd grafana_tests/ # once again, it is presumed that those files will be provided in some way before running the script (for more -> https://devopscube.com/setup-grafana-kubernetes/)
		kubectl create -f grafana-datasource-config.yaml
		kubectl create -f grafana_dep_PERSIST.yaml
		kubectl create -f grafana_service.yaml
		# by default, user and password are admin/admin, the user will be prompted to change the admin password as soon as they access the grafana UI for the first time
		cd
		cd kubeadm_worker_setup/
		# setting up scaphandre
		# before setting up scaphandre, it is required to set up helm chart since this is where the scaphandre setup for k8s is located 
		curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
		sudo apt-get install apt-transport-https --yes
		echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
		sudo apt-get update
		sudo apt-get install helm
		# since helm has been installed, now it is possible to set up scaphandre from its repo
		git clone https://github.com/hubblo-org/scaphandre
		cd scaphandre
		helm install scaphandre helm/scaphandre
		cd
		cd kubeadm_worker_setup/
		# setting up the node exporter
		cd node_exporter/
		kubectl create -f daemonset.yaml
		kubectl create -f node_exporter_service.yaml
		cd
        ## if # (kubectl get nodes | grep ${dst_user}) | awk '{print $3}' != 'controller'
        ##  then
        ##        echo -e "Node added but role not set as controller" This would be a... interesting ... cenario, we're just making sure that everything went well here
        ## exit 1;
        ;;
    \?) # invalid opt
      echo "Error: Invalid option"
      exit;;
  esac
done
