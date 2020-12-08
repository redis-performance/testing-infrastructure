#!/bin/bash

# exit immediately on error
set -e
COMMIT=${COMMIT:-""}

# How many benchmark threads - match num of cores, or default to 8
JOBS=${JOBS:-$(grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 8)}

sudo apt update -y
sudo apt install git -y
rm -rf redis

if [[ "$COMMIT" == "" ]]; then
  echo "Using current HEAD"
  git clone https://github.com/redis/redis --depth 1
  cd redis
fi
if [[ "$COMMIT" != "" ]]; then
  echo "Using commit ${COMMIT}"
  git clone https://github.com/redis/redis
  cd redis
  git checkout ${COMMIT}
fi

sudo apt install libssl-dev make gcc pkg-config -y
make distclean
make BUILD_TLS=yes -j ${JOBS}
sudo make BUILD_TLS=yes install
echo "Printing redis-server info"
redis-server --version

# clean
cd ..
rm -rf redis
