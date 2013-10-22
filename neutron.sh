#!/bin/bash

# network.sh

# Authors: Kevin Jackson (kevin@linuxservices.co.uk)
#          Cody Bunch (bunchc@gmail.com)

# Source in common env vars
. /vagrant/common.sh

# The routeable IP of the node is on our eth1 interface
MY_IP=$(ifconfig eth1 | awk '/inet addr/ {split ($2,A,":"); print A[2]}')
ETH3_IP=$(ifconfig eth3 | awk '/inet addr/ {split ($2,A,":"); print A[2]}')

sysctl net.ipv4.ip_forward=1

sudo apt-get update
#sudo apt-get -y upgrade

sudo apt-get -y --force-yes install vim linux-headers-`uname -r`

sudo apt-get -y --force-yes install vlan bridge-utils dnsmasq-base dnsmasq-utils

sudo apt-get -y --force-yes install openvswitch-switch openvswitch-datapath-dkms

sudo apt-get -y --force-yes install neutron-dhcp-agent neutron-l3-agent neutron-plugin-openvswitch neutron-plugin-openvswitch-agent 

sudo /etc/init.d/openvswitch-switch start

# OpenVSwitch Configuration
#br-int will be used for VM integration
sudo ovs-vsctl add-br br-int

#br-ex is used to make to VM accessible from the internet
sudo ovs-vsctl add-br br-ex
sudo ovs-vsctl add-port br-ex eth3

# Edit the /etc/network/interfaces file for eth3?
sudo ifconfig eth3 0.0.0.0 up
sudo ip link set eth3 promisc on
sudo ifconfig br-ex $ETH3_IP netmask 255.255.255.0

# Configuration

# /etc/neutron/api-paste.ini
rm -f /etc/neutron/api-paste.ini
echo "
[composite:neutron]
use = egg:Paste#urlmap
/: neutronversions
/v2.0: neutronapi_v2_0

[composite:neutronapi_v2_0]
use = call:neutron.auth:pipeline_factory
noauth = extensions neutronapiapp_v2_0
keystone = authtoken keystonecontext extensions neutronapiapp_v2_0

[filter:keystonecontext]
paste.filter_factory = neutron.auth:NeutronKeystoneContext.factory

[filter:authtoken]
paste.filter_factory = keystoneclient.middleware.auth_token:filter_factory
auth_host = ${CONTROLLER_HOST}
auth_port = 35357
auth_protocol = http
admin_tenant_name = service
admin_user = neutron
admin_password = neutron

[filter:extensions]
paste.filter_factory = neutron.api.extensions:plugin_aware_extension_middleware_factory

[app:neutronversions]
paste.app_factory = neutron.api.versions:Versions.factory

[app:neutronapiapp_v2_0]
paste.app_factory = neutron.api.v2.router:APIRouter.factory
" | tee -a /etc/neutron/api-paste.ini

# /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini
echo "
[DATABASE]
sql_connection=mysql://neutron:openstack@${CONTROLLER_HOST}/neutron
[OVS]
tenant_network_type=gre
tunnel_id_ranges=1:1000
integration_bridge=br-int
tunnel_bridge=br-tun
local_ip=${MY_IP}
enable_tunneling=True
root_helper = sudo /usr/bin/neutron-rootwrap /etc/neutron/rootwrap.conf
[SECURITYGROUP]
# Firewall driver for realizing neutron security group function
firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
" | tee -a /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini

# /etc/neutron/dhcp_agent.ini 
#echo "root_helper = sudo neutron-rootwrap /etc/neutron/rootwrap.conf" >> /etc/neutron/dhcp_agent.ini
echo "
root_helper = sudo
use_namespaces = True
" | tee -a /etc/neutron/dhcp_agent.ini

echo "
Defaults !requiretty
neutron ALL=(ALL:ALL) NOPASSWD:ALL" | tee -a /etc/sudoers


# Configure Neutron
sudo sed -i "s/# rabbit_host = localhost/rabbit_host = ${CONTROLLER_HOST}/g" /etc/neutron/neutron.conf
sudo sed -i 's/# auth_strategy = keystone/auth_strategy = keystone/g' /etc/neutron/neutron.conf
sudo sed -i "s/auth_host = 127.0.0.1/auth_host = ${CONTROLLER_HOST}/g" /etc/neutron/neutron.conf
sudo sed -i 's/admin_tenant_name = %SERVICE_TENANT_NAME%/admin_tenant_name = service/g' /etc/neutron/neutron.conf
sudo sed -i 's/admin_user = %SERVICE_USER%/admin_user = neutron/g' /etc/neutron/neutron.conf
sudo sed -i 's/admin_password = %SERVICE_PASSWORD%/admin_password = neutron/g' /etc/neutron/neutron.conf
sudo sed -i 's/^root_helper.*/root_helper = sudo/g' /etc/neutron/neutron.conf
sudo sed -i 's/# allow_overlapping_ips = False/allow_overlapping_ips = True/g' /etc/neutron/neutron.conf
sudo sed -i "s,^sql_connection.*,sql_connection = mysql://neutron:openstack@${CONTROLLER_HOST}/neutron," /etc/neutron/neutron.conf

# Restart Neutron Services
service neutron-plugin-openvswitch-agent restart



# /etc/neutron/l3_agent.ini
echo "
auth_url = http://${CONTROLLER_HOST}:35357/v2.0
auth_region = RegionOne
admin_tenant_name = service
admin_user = neutron
admin_password = neutron
metadata_ip = ${CONTROLLER_HOST}
metadata_port = 8775
use_namespaces = True" | tee -a /etc/neutron/l3_agent.ini

# Metadata Agent
echo "[DEFAULT]
auth_url = http://${CONTROLLER_HOST}:35357/v2.0
auth_region = RegionOne
admin_tenant_name = service
admin_user = neutron
admin_password = neutron
metadata_proxy_shared_secret = foo
nova_metadata_ip = ${CONTROLLER_HOST}
nova_metadata_port = 8775
" | tee -a /etc/neutron/metadata_agent.ini

sudo service neutron-plugin-openvswitch-agent restart
sudo service neutron-dhcp-agent restart
sudo service neutron-l3-agent restart
sudo service neutron-metadata-agent restart
