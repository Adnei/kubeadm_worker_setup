		cd kubeadm-scripts/scripts/
		./common.sh
		./master.sh
		cd ..
		cd ..
		sudo ufw disable # beware of this.
		#setting up files system for proper mounting
		sudo mkdir /var/lib/grafana/
		sudo mkdir /prometheus/
		#deploying Persistent Volumes
		kubectl apply -f persistent-volume-instantiation-1.yaml
		kubectl apply -f persistent-volume-instantiation-2.yaml
		kubectl taint nodes --all node-role.kubernetes.io/control-plane-
		cd prometheus_test/
		#setting up prometheus
		kubectl create namespace monitoring
		kubectl create -f clusterRole.yaml	# it is inferred that there are the prometheus_test/ folder with the files required for a prometheus setup (for more -> https://devopscube.com/setup-prometheus-monitoring-on-kubernetes/)
		kubectl create -f prometheus_config-map.yaml 
		kubectl create -f prometheus-deployment-PV.yaml
		kubectl apply -f prometheus-service.yaml
		cd ..
		cd grafana_tests/
		# setting up grafana, once again, it is presumed that those files will be provided in some way before running the script (for more -> https://devopscube.com/setup-grafana-kubernetes/)
		kubectl create -f grafana-datasource-config.yaml
		kubectl create -f grafana_dep_PERSIST.yaml
		kubectl create -f grafana_service.yaml
		# by default, user and password are admin/admin, the user will be prompted to change the admin password as soon as they access the grafana UI for the first time
		cd ..
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
		cd ..
		cd node_exporter/
		# setting up the node exporter
		kubectl create -f daemonset.yaml
		kubectl create -f node_exporter_service.yaml
		cd
