#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
sudo DEBIAN_FRONTEND=noninteractive apt update -y
sudo DEBIAN_FRONTEND=noninteractive apt install zip git libssl-dev make gcc pkg-config python3-pip -y
# install libssl1 due to search
sudo git clone https://github.com/redis/redis --depth 1
sudo bash -c "cd redis && sudo make BUILD_TLS=yes -j && sudo make BUILD_TLS=yes install"
# check
echo "Printing redis-server info"
redis-server --version
