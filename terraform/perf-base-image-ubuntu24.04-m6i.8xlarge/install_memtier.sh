#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
sudo DEBIAN_FRONTEND=noninteractive apt update -y
sudo DEBIAN_FRONTEND=noninteractive apt install build-essential autoconf automake libevent-dev pkg-config zlib1g-dev libssl-dev clang-format -y
# install libssl1 due to search
sudo git clone https://github.com/redis/memtier_benchmark --branch master --depth 1
sudo bash -c "cd memtier_benchmark && sudo autoreconf -ivf && sudo ./configure && sudo make -j && sudo make install"
# check
echo "Printing memtier_benchmark info"
memtier_benchmark --version
