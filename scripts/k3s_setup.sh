#!/bin/bash

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

#precreate data directories for pvs and config their selinux context
for directory in $data_directories
do
	#mkdir $directory && echo "Directory $directory created!" || echo "Directory $directory not created! check permissions or use sudo."
	#chcon -R -t svirt_sandbox_file_t $directory echo $directory && echo "Directory $directory context changed!" || echo "Directory $directory not changed!"
	echo "mkdir $directory"
done

#install helm to install helmcharts
dnf install helm

cd $current_dir/../charts/

#install volume charts first. All of these should have "infra" suffix
for chart in `ls | grep '\-infra'`
do
	echo "helm install $chart ./$chart"
done

#and then install rest of these
for chart in `ls | grep -v '\-infra'`
do
        echo "helm install $chart ./$chart"
done
