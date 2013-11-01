. /vagrant/common.sh

# The routeable IP of the node is on our eth1 interface
MY_IP=$(ifconfig eth1 | awk '/inet addr/ {split ($2,A,":"); print A[2]}')
ETH2_IP=$(ifconfig eth2 | awk '/inet addr/ {split ($2,A,":"); print A[2]}')

sudo apt-get install -y python-keystone python-keystoneclient swift swift-account swift-container swift-object xfsprogs

sudo mkfs -t xfs -L swift -f /dev/sdb
sudo mkdir -p /srv/node/r0

echo "
LABEL=swift        /srv/node/r0        auto        defaults    0    0" | sudo tee -a /etc/fstab

sudo mount -a
sudo chown swift:swift /srv/node/r0

sudo rm -rf /etc/rsyncd.conf
echo "
uid = swift
gid = swift
log file = /var/log/rsyncd.log
pid file = /var/run/rsyncd.pid
address = ${ETH2_IP}

[account]
max connections = 2
path = /srv/node/
read only = false
lock file = /var/lock/account.lock

[container]
max connections = 2
path = /srv/node/
read only = false
lock file = /var/lock/container.lock

[object]
max connections = 2
path = /srv/node/
read only = false
lock file = /var/lock/object.lock
" |sudo tee -a /etc/rsyncd.conf

sudo sed -i 's/RSYNC_ENABLE=false/RSYNC_ENABLE=true/g' /etc/default/rsync
sudo service rsync start

sudo rm -rf /etc/swift/account-server.conf
echo "
[DEFAULT]
bind_ip = ${ETH2_IP}
workers = 2

[pipeline:main]
pipeline = recon account-server

[filter:recon]
use = egg:swift #recon
recon_cache_path = /var/cache/swift

[app:account-server]
use = egg:swift#account

[account-replicator]

[account-auditor]

[account-reaper]
" | sudo tee -a /etc/swift/account-server.conf

sudo rm -rf /etc/swift/object-server.conf
echo "
[DEFAULT]
bind_ip = ${ETH2_IP}
workers = 2

[pipeline:main]
pipeline = recon object-server

[filter:recon]
use = egg:swift#recon
recon_cache_path = /var/cache/swift

[app:object-server]
use = egg:swift#object

[object-replicator]
[object-updater]
[object-auditor]
" | sudo tee -a /etc/swift/object-server.conf

sudo rm -rf /etc/swift/container-server.conf
echo "[DEFAULT]
bind_ip = ${ETH2_IP}
workers = 2

[pipeline:main]
pipeline = recon container-server

[filter:recon]
use = egg:swift#recon
recon_cache_path = /var/cache/swift

[app:container-server]
use = egg:swift#container

[container-replicator]
[container-updater]
[container-auditor]
" | sudo tee -a /etc/swift/container-server.conf

echo "
[swift-hash]
swift_hash_path_suffix = kee6ohPoiev0peeHfaeNg6Uo" | sudo tee -a /etc/swift/swift.conf


sudo mkdir -p /var/cache/swift && sudo chown swift:swift /var/cache/swift

echo "
*/5 * * * * swift /usr/bin/swift-recon-cron /etc/swift/object-server.conf" | sudo tee -a /etc/cron.d/swift-recon

sudo cp /vagrant/*.gz /etc/swift/
sudo swift-init main start


