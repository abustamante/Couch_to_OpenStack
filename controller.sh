source /vagrant/.controller
source /vagrant/.proxy
export DEBIAN_FRONTEND=noninteractive

# Setup Proxy
export APT_PROXY=${PROXY_HOST}
export APT_PROXY_PORT=3142
#
# If you have a proxy outside of your VirtualBox environment, use it
if [[ ! -z "$APT_PROXY" ]]
then
	echo 'Acquire::http { Proxy "http://'${APT_PROXY}:${APT_PROXY_PORT}'"; };' | sudo tee /etc/apt/apt.conf.d/01apt-cacher-ng-proxy
fi

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update

# Grizzly Goodness
sudo apt-get -y install ubuntu-cloud-keyring
echo "deb  http://ubuntu-cloud.archive.canonical.com/ubuntu precise-updates/havana main" | sudo tee -a /etc/apt/sources.list.d/havana.list
echo "grub-pc	grub-pc/install_devices	multiselect	/dev/sda" | sudo debconf-set-selections
sudo apt-get update && sudo apt-get dist-upgrade -y

MY_IP=$(ifconfig eth1 | awk '/inet addr/ {split ($2,A,":"); print A[2]}')
MY_PRIV_IP=$(ifconfig eth2 | awk '/inet addr/ {split ($2,A,":"); print A[2]}')

# Define environment variables to contain the OpenStack Controller Public and Private IP for later use with Cinder
export OSCONTROLLER=$MY_IP
export OSCONTROLLER_P=$MY_PRIV_IP

# MySQL
export MYSQL_HOST=$MY_IP
export MYSQL_ROOT_PASS=openstack
export MYSQL_DB_PASS=openstack

echo "mysql-server-5.5 mysql-server/root_password password $MYSQL_ROOT_PASS" | sudo debconf-set-selections
echo "mysql-server-5.5 mysql-server/root_password_again password $MYSQL_ROOT_PASS" | sudo debconf-set-selections
echo "mysql-server-5.5 mysql-server/root_password seen true" | sudo debconf-set-selections
echo "mysql-server-5.5 mysql-server/root_password_again seen true" | sudo debconf-set-selections

###############################
# MySQL Install
###############################

sudo apt-get -y install vim mysql-server python-mysqldb

sudo sed -i "s/^bind\-address.*/bind-address = 0.0.0.0/g" /etc/mysql/my.cnf
sudo sed -i "s/^#max_connections.*/max_connections = 512/g" /etc/mysql/my.cnf

# Skip Name Resolve
echo "[mysqld]
skip-name-resolve" > /etc/mysql/conf.d/skip-name-resolve.cnf

sudo restart mysql

# Ensure root can do its job
mysql -u root --password=${MYSQL_ROOT_PASS} -h localhost -e "GRANT ALL ON *.* to root@\"localhost\" IDENTIFIED BY \"${MYSQL_ROOT_PASS}\" WITH GRANT OPTION;"
mysql -u root --password=${MYSQL_ROOT_PASS} -h localhost -e "GRANT ALL ON *.* to root@\"${MYSQL_HOST}\" IDENTIFIED BY \"${MYSQL_ROOT_PASS}\" WITH GRANT OPTION;"
mysql -u root --password=${MYSQL_ROOT_PASS} -h localhost -e "GRANT ALL ON *.* to root@\"%\" IDENTIFIED BY \"${MYSQL_ROOT_PASS}\" WITH GRANT OPTION;"

mysqladmin -uroot -p${MYSQL_ROOT_PASS} flush-privileges


###############################
# Keystone Install
###############################
sudo apt-get -y install keystone python-keystone python-keystoneclient

MYSQL_ROOT_PASS=openstack
MYSQL_KEYSTONE_PASS=openstack
mysql -uroot -p$MYSQL_ROOT_PASS -e 'CREATE DATABASE keystone;'
mysql -uroot -p$MYSQL_ROOT_PASS -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%';"
mysql -uroot -p$MYSQL_ROOT_PASS -e "SET PASSWORD FOR 'keystone'@'%' = PASSWORD('$MYSQL_KEYSTONE_PASS');"

sudo sed -i "s#^connection.*#connection = mysql://keystone:${MYSQL_KEYSTONE_PASS}@${MYSQL_HOST}/keystone#" /etc/keystone/keystone.conf

sudo sed -i 's/^# admin_token.*/admin_token = ADMIN/' /etc/keystone/keystone.conf

sudo stop keystone
sudo start keystone

sudo keystone-manage db_sync

export ENDPOINT=${MY_IP}
export SERVICE_TOKEN=ADMIN
export SERVICE_ENDPOINT=http://${ENDPOINT}:35357/v2.0

# admin role
keystone role-create --name admin

# Member role
keystone role-create --name Member

keystone tenant-create --name cookbook --description "Default Cookbook Tenant" --enabled true

TENANT_ID=$(keystone tenant-list | awk '/\ cookbook\ / {print $2}')

export PASSWORD=openstack
keystone user-create --name admin --tenant_id $TENANT_ID --pass $PASSWORD --email root@localhost --enabled true

TENANT_ID=$(keystone tenant-list | awk '/\ cookbook\ / {print $2}')

ROLE_ID=$(keystone role-list | awk '/\ admin\ / {print $2}')

USER_ID=$(keystone user-list | awk '/\ admin\ / {print $2}')

keystone user-role-add --user $USER_ID --role $ROLE_ID --tenant_id $TENANT_ID

# Create the user
PASSWORD=openstack
keystone user-create --name demo --tenant_id $TENANT_ID --pass $PASSWORD --email demo@localhost --enabled true

TENANT_ID=$(keystone tenant-list | awk '/\ cookbook\ / {print $2}')

ROLE_ID=$(keystone role-list | awk '/\ Member\ / {print $2}')

USER_ID=$(keystone user-list | awk '/\ demo\ / {print $2}')

# Assign the Member role to the demo user in cookbook
keystone user-role-add --user $USER_ID --role $ROLE_ID --tenant_id $TENANT_ID

# OpenStack Compute EC2 API Endpoint
keystone service-create --name ec2 --type ec2 --description 'EC2 Service'

# OpenStack Swift Object Storage Endpoint
keystone service-create --name swift --type object-store --description 'OpenStack Object Storage Service'

# Keystone Identity Service Endpoint
keystone service-create --name keystone --type identity --description 'OpenStack Identity Service'

# Glance Image Service Endpoint
keystone service-create --name glance --type image --description 'OpenStack Image Service'

# Keystone OpenStack Identity Service
KEYSTONE_SERVICE_ID=$(keystone service-list | awk '/\ keystone\ / {print $2}')

PUBLIC="http://$ENDPOINT:5000/v2.0"
ADMIN="http://$ENDPOINT:35357/v2.0"
INTERNAL=$PUBLIC

keystone endpoint-create --region regionOne --service_id $KEYSTONE_SERVICE_ID --publicurl $PUBLIC --adminurl $ADMIN --internalurl $INTERNAL

# Glance Image Service
GLANCE_SERVICE_ID=$(keystone service-list | awk '/\ glance\ / {print $2}')

PUBLIC="http://$ENDPOINT:9292"
ADMIN=$PUBLIC
INTERNAL=$PUBLIC

keystone endpoint-create --region regionOne --service_id $GLANCE_SERVICE_ID --publicurl $PUBLIC --adminurl $ADMIN --internalurl $INTERNAL

# Swift Object Storage Service
SWIFT_SERVICE_ID=$(keystone service-list | awk '/\ object-store\ / {print $2}')
SWIFT_ENDPOINT=$(echo $OSCONTROLLER | sed 's/\.[0-9]*$/.220/') #Change last octet of OpenStack Controller IP to the Swift IP.  If you changed the Swift IP's last octet, then change the .220 in this sed command

PUBLIC="http://$SWIFT_ENDPOINT:8080/v1/%(tenant_id)s" 
ADMIN="http://$SWIFT_ENDPOINT:8080/"
INTERNAL=$PUBLIC

keystone endpoint-create --region regionOne --service_id $SWIFT_SERVICE_ID --publicurl $PUBLIC --adminurl $ADMIN --internalurl $INTERNAL


# Service Tenant
keystone tenant-create --name service --description "Service Tenant" --enabled true

SERVICE_TENANT_ID=$(keystone tenant-list | awk '/\ service\ / {print $2}')
keystone user-create --name keystone --pass keystone --tenant_id $SERVICE_TENANT_ID --email keystone@localhost --enabled true

keystone user-create --name glance --pass glance --tenant_id $SERVICE_TENANT_ID --email glance@localhost --enabled true

keystone user-create --name swift --pass swift --tenant_id $SERVICE_TENANT_ID --email swift@localhost --enabled true

# Set user ids
ADMIN_ROLE_ID=$(keystone role-list | awk '/\ admin\ / {print $2}')
KEYSTONE_USER_ID=$(keystone user-list | awk '/\ keystone\ / {print $2}')
GLANCE_USER_ID=$(keystone user-list | awk '/\ glance\ / {print $2}')
SWIFT_USER_ID=$(keystone user-list | awk '/\ swift \ / {print $2}')

# Assign the keystone user the admin role in service tenant
keystone user-role-add --user $KEYSTONE_USER_ID --role $ADMIN_ROLE_ID --tenant_id $SERVICE_TENANT_ID

# Assign the glance user the admin role in service tenant
keystone user-role-add --user $GLANCE_USER_ID --role $ADMIN_ROLE_ID --tenant_id $SERVICE_TENANT_ID

# Assign the swift user the admin role in service tenant
keystone user-role-add --user $SWIFT_USER_ID --role $ADMIN_ROLE_ID --tenant_id $SERVICE_TENANT_ID

###############################
# Glance Install
###############################

# Install Service

sudo apt-get -y install glance

# Create database
MYSQL_ROOT_PASS=openstack
MYSQL_GLANCE_PASS=openstack
mysql -uroot -p$MYSQL_ROOT_PASS -e 'CREATE DATABASE glance;'
mysql -uroot -p$MYSQL_ROOT_PASS -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%';"
mysql -uroot -p$MYSQL_ROOT_PASS -e "SET PASSWORD FOR 'glance'@'%' = PASSWORD('$MYSQL_GLANCE_PASS');"

# glance-api-paste.ini
echo "service_protocol = http
service_host = ${MY_IP}
service_port = 5000
auth_host = ${MY_IP}
auth_port = 35357
auth_protocol = http
auth_uri = http://${MY_IP}:5000/
admin_tenant_name = service
admin_user = glance
admin_password = glance
" | sudo tee -a /etc/glance/glance-api-paste.ini

# glance-api.conf
echo "[keystone_authtoken]
service_protocol = http
service_host = ${MY_IP}
service_port = 5000
auth_host = ${MY_IP}
auth_port = 35357
auth_protocol = http
auth_uri = http://${MY_IP}:5000/
admin_tenant_name = service
admin_user = glance
admin_password = glance
[paste_deploy]
config_file = /etc/glance/glance-api-paste.ini
flavor = keystone
" | sudo tee -a /etc/glance/glance-api.conf

# glance-registry-paste.ini
echo "service_protocol = http
service_host = ${MY_IP}
service_port = 5000
auth_host = ${MY_IP}
auth_port = 35357
auth_protocol = http
auth_uri = http://${MY_IP}:5000/
admin_tenant_name = service
admin_user = glance
admin_password = glance
" | sudo tee -a /etc/glance/glance-registry-paste.ini

# glance-registry.conf
echo "[keystone_authtoken]
service_protocol = http
service_host = ${MY_IP}
service_port = 5000
auth_host = ${MY_IP}
auth_port = 35357
auth_protocol = http
auth_uri = http://${MY_IP}:5000/
admin_tenant_name = service
admin_user = glance
admin_password = glance
[paste_deploy]
config_file = /etc/glance/glance-registry-paste.ini
flavor = keystone
" | sudo tee -a /etc/glance/glance-registry.conf

sudo sed -i "s,^sql_connection.*,sql_connection = mysql://glance:${MYSQL_GLANCE_PASS}@${MYSQL_HOST}/glance," /etc/glance/glance-registry.conf
sudo sed -i "s,^sql_connection.*,sql_connection = mysql://glance:${MYSQL_GLANCE_PASS}@${MYSQL_HOST}/glance," /etc/glance/glance-api.conf

sudo stop glance-registry
sudo start glance-registry
sudo stop glance-api
sudo start glance-api

sudo glance-manage db_sync

# Get some images and upload
export OS_TENANT_NAME=cookbook
export OS_USERNAME=admin
export OS_PASSWORD=openstack
export OS_AUTH_URL=http://${MY_IP}:5000/v2.0/
export OS_NO_CACHE=1

sudo apt-get -y install wget

# Get the images
# First check host
CIRROS="cirros-0.3.0-x86_64-disk.img"
UBUNTU="precise-server-cloudimg-amd64-disk1.img"

if [[ ! -f /vagrant/${CIRROS} ]]
then
        # Download then store on local host for next time
	wget --quiet https://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-x86_64-disk.img 
else
	cp /vagrant/${CIRROS} .
fi

if [[ ! -f /vagrant/${UBUNTU} ]]
then
        # Download then store on local host for next time
	wget --quiet http://uec-images.ubuntu.com/precise/current/precise-server-cloudimg-amd64-disk1.img       
else
	cp /vagrant/${UBUNTU} .
fi

glance image-create --name='Ubuntu 12.04 x86_64 Server' --disk-format=qcow2 --container-format=bare --public < precise-server-cloudimg-amd64-disk1.img
glance image-create --name='Cirros 0.3' --disk-format=qcow2 --container-format=bare --public < cirros-0.3.0-x86_64-disk.img

###############################
# Everyone loves Horizon dashboard
###############################
sudo apt-get -y install openstack-dashboard
###############################
# OpenStack Deployment Complete
###############################

# Create a .stackrc file
cat > /vagrant/.stackrc <<EOF
export OS_TENANT_NAME=cookbook
export OS_USERNAME=admin
export OS_PASSWORD=openstack
export OS_AUTH_URL=http://${MY_IP}:5000/v2.0/
EOF

#Pass Controller IP to Common.sh and other nodes
cat > /vagrant/.controller <<EOF
export CONTROLLER_HOST=${MY_IP}
export CONTROLLER_HOST_PRIV=${MY_PRIV_IP}
EOF

