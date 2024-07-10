#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
sudo DEBIAN_FRONTEND=noninteractive apt update  -y
sudo DEBIAN_FRONTEND=noninteractive apt install python3-pip gcc-12 g++-12 make pkg-config -y
sudo DEBIAN_FRONTEND=noninteractive git clone https://github.com/redis/redis --branch 7.4
#sudo DEBIAN_FRONTEND=noninteractive cd redis && make -j && sudo make install
