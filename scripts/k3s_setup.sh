#!/bin/bash

read -s -p "Enter password for postgres user(n8n): " POSTGRES_NON_ROOT_PASSWORD
read -s -p "Enter password for root postgres(n8n): " POSTGRES_PASSWORD
read -s -p "Enter password for root mysql(owncloud): " MYSQL_ROOT_PASSWORD
read -s -p "Enter password for non root mysql user(owncloud): " OWNCLOUD_DB_PASSWORD

export PATH="$PATH:/usr/local/bin"
dnf install tar -y
curl -fsSL -o /tmp/get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
chmod 700 /tmp/get_helm.sh
/tmp/get_helm.sh

#install k3s with flannel backend
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --flannel-backend vxlan" sh -s - && echo "k3s installed!" || (echo "Couldn't install k3s!" && exit 1)

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

filename=$0
current_dir=`realpath "$filename" | sed -E "s/\/\w+\.sh//g"`

data_directories="
/opt/changedetection-data
/opt/homeassistant-data
/opt/jackett-data
/opt/jellyfin-cache-data
/opt/jellyfin-media-data
/opt/jellyfin-config-data
/opt/n8n-data
/opt/n8n-db-data
/opt/owncloud-data
/opt/owncloud-cache-data
/opt/owncloud-db-data
/opt/sonarr-data
/opt/radarr-data
"

#install nginx ingress
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx   --namespace ingress-nginx   --create-namespace   --set controller.service.type=LoadBalancer

#install metallb
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.5/config/manifests/metallb-native.yaml
sleep 60
kubectl apply -f ../charts/loadbalancer-chart/metallb-pool.yaml

#precreate data directories for pvs and config their selinux context:
for directory in $data_directories
do
        mkdir $directory && echo "Directory $directory created!" || (echo "ERROR !Directory $directory not created! check permissions or use sudo." && exit 1)
        chcon -R -t svirt_sandbox_file_t $directory && echo "Directory $directory context changed!" || (echo "ERROR! Directory $directory not changed!" && exit 1)
done

cd $current_dir/../charts/


kubectl create secret generic n8n-credentials  \
    --from-literal=POSTGRES_NON_ROOT_USER=n8n \
    --from-literal=POSTGRES_NON_ROOT_PASSWORD=$POSTGRES_NON_ROOT_PASSWORD \
    --from-literal=POSTGRES_USER=root \
    --from-literal=POSTGRES_PASSWORD=$POSTGRES_PASSWORD \  && echo "n8n credentials loaded!"

kubectl create secret generic owncloud-credentials  \
    --from-literal=MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD \
    --from-literal=OWNCLOUD_DB_USERNAME=owncloud \
    --from-literal=OWNCLOUD_DB_PASSWORD=$OWNCLOUD_DB_PASSWORD && echo "Owncloud credentials loaded!"

helm install namespaces ./namespaces && echo "Namespaces installed!"

sleep 20

#install volume charts first. All of these should have "infra" suffix
for chart in `ls | grep '\-infra'`
do
        helm install $chart ./$chart ||  (echo "ERROR! Chart $chart couldn't be deployed!" && exit 1)
done

#and then install rest of these(except loadbalancer and previously created namespaces)
for chart in `ls | grep -v '\-infra' | grep -vi loadbalancer | grep -vi namespaces`
do
        helm install $chart ./$chart  ||  (echo "ERROR! Chart $chart couldn't be deployed!" && exit 1)
done

