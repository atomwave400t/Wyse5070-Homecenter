#!/bin/bash
#
#

#network interfaces config. Needed for 5070 to work properly with eth connected
network_config=`cat <<EOF
auto ol\n
iface lo inet loopback\n
\n
auto nic0\n
allow-hotplug nic0\n
iface nic0 inet dhpc\n
iface vmbr0 inet dhcp\n
\n
\n
auto vmbr0\n
iface vmbr0 inet dhcp\n
\tbridge-ports nic0\n
\tbridge-stp off\n
\tbridge-fd 0\n
\n
source /etc/network/interfaces.d/* \n
EOF
`

echo -e $network_config > /etc/network/interfaces && echo "Network config attached succesfully!" || echo "ERROR! Network config config couldn't be attached succesfully!"

#before each shutdown, the nic0 interface wol is set to: g-enabled, u-supporting unicast packets(useful, especialy with etherwake)
wol_service_config=`cat <<EOF
[Unit]\n
Description=Enable Wake-on-LAN\n
Before=shutdown.target\n
\n
[Service]\n
Type=oneshot\n
ExecStart=/sbin/ethtool -s nic0 wol ug\n
\n
[Install]\n
WantedBy=multi-user.target\n
EOF
`

echo -e $wol_service_config > /etc/systemd/system/wol.service && echo "Wol service file attached successfuly!" || echo "ERROR! Wol service file not attached! Check permissions or use sudo!"

systemctl daemon-reload && echo "Systemctl daemon reloaded succesfully!" || echo "ERROR! Systemctl daemon couldn't be reloaded successfully!"
systemctl enable wol && echo "Wol service enabled!" || echo "ERROR! Cannot enable Wol service!"
systemctl start wol && echo "Wol service started!" || echo "ERROR! Cannot start Wol service! Check service file!"
