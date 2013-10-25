. /vagrant/common.sh
export DEBIAN_FRONTEND=noninteractive

MY_IP=$(ifconfig eth1 | awk '/inet addr/ {split ($2,A,":"); print A[2]}')
ETH3_IP=$(ifconfig eth3 | awk '/inet addr/ {split ($2,A,":"); print A[2]}')

# OpenStack Controller Private IP for use with generating Cinder target IP
OSC_PRIV_IP=${CONTROLLER_HOST_PRIV}

# Must define your environment
MYSQL_HOST=${CONTROLLER_HOST}
GLANCE_HOST=${CONTROLLER_HOST}


sudo apt-get install -y curl gcc memcached rsync sqlite3 xfsprogs git-core libffi-dev python-setuptools
sudo apt-get install -y python-coverage python-dev python-nose python-simplejson python-xattr python-eventlet python-greenlet python-pastedeploy python-netifaces python-pip python-dnspython python-mock


echo "n
p
1


t
83
w
"| sudo fdisk /dev/sdb

sudo mkfs.xfs /dev/sdb1
echo "/dev/sdb1 /mnt/sdb1 xfs noatime,nodiratime,nobarrier,logbufs=8 0 0" | sudo tee -a /etc/fstab
sudo mkdir /mnt/sdb1
sudo mount /mnt/sdb1
sudo mkdir /mnt/sdb1/1 /mnt/sdb1/2 /mnt/sdb1/3 /mnt/sdb1/4
sudo chown vagrant:vagrant /mnt/sdb1/*
sudo mkdir /srv
for x in {1..4};do sudo ln -s /mnt/sdb1/$x /srv/$x;done
mkdir -p /etc/swift/object-server /etc/swift/container-server /etc/swift/account-server /srv/1/node/sdb1 /srv/2/node/sdb2 /srv/3/node/sdb3 /srv/4/node/sdb4 /var/run/swift
chown -R vagrant:vagrant /etc/swift /srv/[1-4]/ /var/run/swift
rm -rf /etc/rsyncd.conf
echo "uid = vagrant
gid = vagrant
log file = /var/log/rsyncd.log
pid file = /var/run/rsyncd.pid
address = 127.0.0.1

[account6012]
max connections = 25
path = /srv/1/node/
read only = false
lock file = /var/lock/account6012.lock

[account6022]
max connections = 25
path = /srv/2/node/
read only = false
lock file = /var/lock/account6022.lock

[account6032]
max connections = 25
path = /srv/3/node/
read only = false
lock file = /var/lock/account6032.lock

[account6042]
max connections = 25
path = /srv/4/node/
read only = false
lock file = /var/lock/account6042.lock

[container6011]
max connections = 25
path = /srv/1/node/
read only = false
lock file = /var/lock/container6011.lock

[container6021]
max connections = 25
path = /srv/2/node/
read only = false
lock file = /var/lock/container6021.lock

[container6031]
max connections = 25
path = /srv/3/node/
read only = false
lock file = /var/lock/container6031.lock

[container6041]
max connections = 25
path = /srv/4/node/
read only = false
lock file = /var/lock/container6041.lock

[object6010]
max connections = 25
path = /srv/1/node/
read only = false
lock file = /var/lock/object6010.lock

[object6020]
max connections = 25
path = /srv/2/node/
read only = false
lock file = /var/lock/object6020.lock

[object6030]
max connections = 25
path = /srv/3/node/
read only = false
lock file = /var/lock/object6030.lock

[object6040]
max connections = 25
path = /srv/4/node/
read only = false
lock file = /var/lock/object6040.lock" | sudo tee -a /etc/rsyncd.conf

sudo sed -i "s/RSYNC_ENABLE=false/RSYNC_ENABLE=true/g" /etc/default/rsync
sudo service rsync restart


echo "
mkdir -p /var/cache/swift /var/cache/swift2 /var/cache/swift3 /var/cache/swift4
chown vagrant:vagrant /var/cache/swift*
mkdir -p /var/run/swift
chown vagrant:vagrant /var/run/swift" | sudo tee -a /etc/rc.local

echo "# Uncomment the following to have a log containing all logs together
#local1,local2,local3,local4,local5.*   /var/log/swift/all.log

# Uncomment the following to have hourly proxy logs for stats processing
#$template HourlyProxyLog,"/var/log/swift/hourly/%$YEAR%%$MONTH%%$DAY%%$HOUR%"
#local1.*;local1.!notice ?HourlyProxyLog

local1.*;local1.!notice /var/log/swift/proxy.log
local1.notice           /var/log/swift/proxy.error
local1.*                ~

local2.*;local2.!notice /var/log/swift/storage1.log
local2.notice           /var/log/swift/storage1.error
local2.*                ~

local3.*;local3.!notice /var/log/swift/storage2.log
local3.notice           /var/log/swift/storage2.error
local3.*                ~

local4.*;local4.!notice /var/log/swift/storage3.log
local4.notice           /var/log/swift/storage3.error
local4.*                ~

local5.*;local5.!notice /var/log/swift/storage4.log
local5.notice           /var/log/swift/storage4.error
local5.*      " | sudo tee -a /etc/rsyslog.d/10-swift.conf

sudo sed -i "s/$PrivDropToGroup syslog/$PrivDropToGroup adm/g" /etc/rsyslog.conf
sudo mkdir -p /var/log/swift/hourly
sudo chown -R syslog.adm /var/log/swift
sudo chmod -R g+w /var/log/swift
sudo service rsyslog restart

git clone https://github.com/openstack/python-swiftclient.git
cd python-swiftclient; sudo python setup.py develop; cd ..
git clone https://github.com/openstack/swift.git
cd swift; sudo python setup.py develop; cd ..
sudo pip install -r swift/test-requirements.txt

sudo rm -rf /etc/swift/proxy-server.conf
echo "
[DEFAULT]
bind_port = 8080
workers = 1
user = <your-user-name>
log_facility = LOG_LOCAL1
eventlet_debug = true

[pipeline:main]
# Yes, proxy-logging appears twice. This is not a mistake.
pipeline = healthcheck proxy-logging cache tempauth proxy-logging proxy-server

[app:proxy-server]
use = egg:swift#proxy
allow_account_management = true
account_autocreate = true

[filter:tempauth]
use = egg:swift#tempauth
user_admin_admin = admin .admin .reseller_admin
user_test_tester = testing .admin
user_test2_tester2 = testing2 .admin
user_test_tester3 = testing3

[filter:healthcheck]
use = egg:swift#healthcheck

[filter:cache]
use = egg:swift#memcache

[filter:proxy-logging]
use = egg:swift#proxy_logging" | sudo tee -a /etc/swift/proxy-server.conf

sudo rm -rf /etc/swift/swift.conf
echo "[swift-hash]
# random unique strings that can never change (DO NOT LOSE)
swift_hash_path_prefix = changeme
swift_hash_path_suffix = changeme" | sudo tee -a /etc/swift/swift.conf

sudo rm -rf /etc/swift/account-server/1.conf
echo "
[DEFAULT]
devices = /srv/1/node
mount_check = false
disable_fallocate = true
bind_port = 6012
workers = 1
user = vagrant
log_facility = LOG_LOCAL2
recon_cache_path = /var/cache/swift
eventlet_debug = true

[pipeline:main]
pipeline = recon account-server

[app:account-server]
use = egg:swift#account

[filter:recon]
use = egg:swift#recon

[account-replicator]
vm_test_mode = yes

[account-auditor]

[account-reaper]" | sudo tee -a /etc/swift/account-server/1.conf

sudo rm -rf /etc/swift/account-server/2.conf
echo "
[DEFAULT]
devices = /srv/2/node
mount_check = false
disable_fallocate = true
bind_port = 6022
workers = 1
user = vagrant
log_facility = LOG_LOCAL3
recon_cache_path = /var/cache/swift2
eventlet_debug = true

[pipeline:main]
pipeline = recon account-server

[app:account-server]
use = egg:swift#account

[filter:recon]
use = egg:swift#recon

[account-replicator]
vm_test_mode = yes

[account-auditor]

[account-reaper]" | sudo tee -a /etc/swift/account-server/2.conf

sudo rm -rf /etc/swift/account-server/3.conf
echo "
[DEFAULT]
devices = /srv/3/node
mount_check = false
disable_fallocate = true
bind_port = 6032
workers = 1
user = vagrant
log_facility = LOG_LOCAL4
recon_cache_path = /var/cache/swift3
eventlet_debug = true

[pipeline:main]
pipeline = recon account-server

[app:account-server]
use = egg:swift#account

[filter:recon]
use = egg:swift#recon

[account-replicator]
vm_test_mode = yes

[account-auditor]

[account-reaper]" | sudo tee -a /etc/swift/account-server/3.conf


sudo rm -rf /etc/swift/account-server/4.conf
echo "
[DEFAULT]
devices = /srv/4/node
mount_check = false
disable_fallocate = true
bind_port = 6042
workers = 1
user = vagrant
log_facility = LOG_LOCAL5
recon_cache_path = /var/cache/swift4
eventlet_debug = true

[pipeline:main]
pipeline = recon account-server

[app:account-server]
use = egg:swift#account

[filter:recon]
use = egg:swift#recon

[account-replicator]
vm_test_mode = yes

[account-auditor]

[account-reaper]" | sudo tee -a /etc/swift/account-server/4.conf

sudo rm -rf /etc/swift/container-server/1.conf
echo "[DEFAULT]
devices = /srv/1/node
mount_check = false
disable_fallocate = true
bind_port = 6011
workers = 1
user = vagrant
log_facility = LOG_LOCAL2
recon_cache_path = /var/cache/swift
eventlet_debug = true

[pipeline:main]
pipeline = recon container-server

[app:container-server]
use = egg:swift#container

[filter:recon]
use = egg:swift#recon

[container-replicator]
vm_test_mode = yes

[container-updater]

[container-auditor]

[container-sync]" | sudo tee -a /etc/swift/container-server/1.conf

sudo rm -rf /etc/swift/container-server/2.conf
echo "[DEFAULT]
devices = /srv/2/node
mount_check = false
disable_fallocate = true
bind_port = 6021
workers = 1
user = vagrant
log_facility = LOG_LOCAL3
recon_cache_path = /var/cache/swift2
eventlet_debug = true

[pipeline:main]
pipeline = recon container-server

[app:container-server]
use = egg:swift#container

[filter:recon]
use = egg:swift#recon

[container-replicator]
vm_test_mode = yes

[container-updater]

[container-auditor]

[container-sync]" | sudo tee -a /etc/swift/container-server/2.conf

sudo rm -rf /etc/swift/container-server/3.conf
echo "[DEFAULT]
devices = /srv/3/node
mount_check = false
disable_fallocate = true
bind_port = 6031
workers = 1
user = vagrant
log_facility = LOG_LOCAL4
recon_cache_path = /var/cache/swift3
eventlet_debug = true

[pipeline:main]
pipeline = recon container-server

[app:container-server]
use = egg:swift#container

[filter:recon]
use = egg:swift#recon

[container-replicator]
vm_test_mode = yes

[container-updater]

[container-auditor]

[container-sync]" | sudo tee -a /etc/swift/container-server/3.conf

sudo rm -rf /etc/swift/container-server/4.conf
echo "[DEFAULT]
devices = /srv/4/node
mount_check = false
disable_fallocate = true
bind_port = 6041
workers = 1
user = vagrant
log_facility = LOG_LOCAL5
recon_cache_path = /var/cache/swift4
eventlet_debug = true

[pipeline:main]
pipeline = recon container-server

[app:container-server]
use = egg:swift#container

[filter:recon]
use = egg:swift#recon

[container-replicator]
vm_test_mode = yes

[container-updater]

[container-auditor]

[container-sync]" | sudo tee -a /etc/swift/container-server/4.conf

sudo rm -rf /etc/swift/object-server/1.conf
echo "[DEFAULT]
devices = /srv/1/node
mount_check = false
disable_fallocate = true
bind_port = 6010
workers = 1
user = vagrant
log_facility = LOG_LOCAL2
recon_cache_path = /var/cache/swift
eventlet_debug = true

[pipeline:main]
pipeline = recon object-server

[app:object-server]
use = egg:swift#object

[filter:recon]
use = egg:swift#recon

[object-replicator]
vm_test_mode = yes

[object-updater]

[object-auditor]" | sudo tee -a /etc/swift/object-server/1.conf

sudo rm -rf /etc/swift/object-server/2.conf
echo "[DEFAULT]
devices = /srv/2/node
mount_check = false
disable_fallocate = true
bind_port = 6020
workers = 1
user = vagrant
log_facility = LOG_LOCAL3
recon_cache_path = /var/cache/swift2
eventlet_debug = true

[pipeline:main]
pipeline = recon object-server

[app:object-server]
use = egg:swift#object

[filter:recon]
use = egg:swift#recon

[object-replicator]
vm_test_mode = yes

[object-updater]

[object-auditor]" | sudo tee -a /etc/swift/object-server/2.conf

sudo rm -rf /etc/swift/object-server/3.conf
echo "[DEFAULT]
devices = /srv/3/node
mount_check = false
disable_fallocate = true
bind_port = 6030
workers = 1
user = vagrant
log_facility = LOG_LOCAL4
recon_cache_path = /var/cache/swift3
eventlet_debug = true

[pipeline:main]
pipeline = recon object-server

[app:object-server]
use = egg:swift#object

[filter:recon]
use = egg:swift#recon

[object-replicator]
vm_test_mode = yes

[object-updater]

[object-auditor]" | sudo tee -a /etc/swift/object-server/3.conf

sudo rm -rf /etc/swift/object-server/4.conf
echo "[DEFAULT]
devices = /srv/4/node
mount_check = false
disable_fallocate = true
bind_port = 6040
workers = 1
user = vagrant
log_facility = LOG_LOCAL5
recon_cache_path = /var/cache/swift4
eventlet_debug = true

[pipeline:main]
pipeline = recon object-server

[app:object-server]
use = egg:swift#object

[filter:recon]
use = egg:swift#recon

[object-replicator]
vm_test_mode = yes

[object-updater]

[object-auditor]" | sudo tee -a /etc/swift/object-server/4.conf

sudo mkdir ~/bin
echo "#!/bin/bash

swift-init all stop
find /var/log/swift -type f -exec rm -f {} \;
sudo umount /mnt/sdb1
sudo mkfs.xfs -f /dev/sdb1
sudo mount /mnt/sdb1
sudo mkdir /mnt/sdb1/1 /mnt/sdb1/2 /mnt/sdb1/3 /mnt/sdb1/4
sudo chown <your-user-name>:<your-group-name> /mnt/sdb1/*
mkdir -p /srv/1/node/sdb1 /srv/2/node/sdb2 /srv/3/node/sdb3 /srv/4/node/sdb4
sudo rm -f /var/log/debug /var/log/messages /var/log/rsyncd.log /var/log/syslog
find /var/cache/swift* -type f -name *.recon -exec rm -f {} \;
sudo service rsyslog restart
sudo service memcached restart" | sudo tee -a ~/bin/resetswift

echo "#!/bin/bash

cd /etc/swift

rm -f *.builder *.ring.gz backups/*.builder backups/*.ring.gz

swift-ring-builder object.builder create 10 3 1
swift-ring-builder object.builder add r1z1-127.0.0.1:6010/sdb1 1
swift-ring-builder object.builder add r1z2-127.0.0.1:6020/sdb2 1
swift-ring-builder object.builder add r1z3-127.0.0.1:6030/sdb3 1
swift-ring-builder object.builder add r1z4-127.0.0.1:6040/sdb4 1
swift-ring-builder object.builder rebalance
swift-ring-builder container.builder create 10 3 1
swift-ring-builder container.builder add r1z1-127.0.0.1:6011/sdb1 1
swift-ring-builder container.builder add r1z2-127.0.0.1:6021/sdb2 1
swift-ring-builder container.builder add r1z3-127.0.0.1:6031/sdb3 1
swift-ring-builder container.builder add r1z4-127.0.0.1:6041/sdb4 1
swift-ring-builder container.builder rebalance
swift-ring-builder account.builder create 10 3 1
swift-ring-builder account.builder add r1z1-127.0.0.1:6012/sdb1 1
swift-ring-builder account.builder add r1z2-127.0.0.1:6022/sdb2 1
swift-ring-builder account.builder add r1z3-127.0.0.1:6032/sdb3 1
swift-ring-builder account.builder add r1z4-127.0.0.1:6042/sdb4 1
swift-ring-builder account.builder rebalance" | sudo tee -a ~/bin/remakerings

echo "#!/bin/bash

swift-init main start" | sudo tee -a ~/bin/startmain

echo "#!/bin/bash

swift-init rest start" | sudo tee -a ~/bin/startrest
chmod +x ~/bin/*

echo "export SWIFT_TEST_CONFIG_FILE=/etc/swift/test.conf
export PATH=${PATH}:~/bin" | sudo tee -a ~/.bashrc

~/.bashrc
~/bin/remakerings
cp ~/swift/test/sample.conf /etc/swift/test.conf
~/swift/.unittests
startmain
