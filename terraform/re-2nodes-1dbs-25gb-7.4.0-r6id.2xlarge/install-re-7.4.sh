#!/bin/bash

# exit the script if any command fails.
set -e

V=7.4.2
FULL=$V-216
FILENAME=/tmp/re.tar
OS="focal"

wget -O $FILENAME https://s3.amazonaws.com/redis-enterprise-software-downloads/${V}/redislabs-${FULL}-${OS}-amd64.tar

cd /tmp
tar vxf /tmp/re.tar
echo "DNSStubListener=no" | sudo tee -a /etc/systemd/resolved.conf
sudo mv /etc/resolv.conf /etc/resolv.conf.orig
sudo ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf
sudo service systemd-resolved restart
sudo /tmp/install.sh -y

# Cleanup
rm -f $FILENAME
