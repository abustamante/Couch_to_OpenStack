#!/bin/bash

MY_IP=$(ifconfig eth1 | awk '/inet addr/ {split ($2,A,":"); print A[2]}')

# Install apt-cacher
export DEBIAN_FRONTEND=noninteractive
apt-get update && sudo apt-get install apt-cacher-ng -y

# Setup our repo's
sudo apt-get install python-software-properties -y
sudo add-apt-repository ppa:ubuntu-cloud-archive/grizzly-staging
sudo apt-get update
sudo apt-get install iftop iptraf vim curl wget lighttpd -y

echo 'Acquire::http { Proxy "http://${MY_IP}:3142"; };' | sudo tee /etc/apt/apt.conf.d/01apt-cacher-ng-proxy

#Pass Proxy IP to Common.sh and other nodes
cat > /vagrant/.proxy <<EOF
export PROXY_HOST=${MY_IP}
EOF
