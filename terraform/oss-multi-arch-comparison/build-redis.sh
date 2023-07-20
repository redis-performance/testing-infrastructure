#!/bin/bash
sudo apt update -y
sudo apt install build-essential tcl pkg-config -y
gcc --version
rm -rf redis-stable.tar.gz
rm -rf redis-stable
curl -O http://download.redis.io/redis-stable.tar.gz
tar xzvf redis-stable.tar.gz
cd redis-stable 
make -j 
sudo make install
taskset -c 0 redis-server --save '' --requirepass performance.redis --port 16379 --daemonize yes --protected-mode no
redis-cli -p 16379 -a performance.redis ping
