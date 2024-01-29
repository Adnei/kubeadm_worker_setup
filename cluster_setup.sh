		sudo ./node_setup.sh 'sudo kubeadm init --pod-network-cidr=198.162.0.0/24'
		sudo ufw disable # beware of this.
		mkdir -p $HOME/.kube
		sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
		sudo chown $(id -u):$(id -g) $HOME/.kube/config
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
		git fetch
		git switch dev
		helm install scaphandre helm/scaphandre
		cd
		cd kubeadm_worker_setup/
		# setting up the node exporter
		cd node_exporter/
		kubectl create -f daemonset.yaml
		kubectl create -f node_exporter_service.yaml
		cd
