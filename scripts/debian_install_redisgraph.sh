#!/bin/bash

# exit immediately on error
set -e
COMMIT=${COMMIT:-""}

# How many benchmark threads - match num of cores, or default to 8
JOBS=${JOBS:-$(grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 8)}

# sudo apt update -y
sudo apt install git -y
sudo apt install build-essential cmake m4 automake peg libtool autoconf -y

rm -rf RedisGraph

if [[ "$COMMIT" == "" ]]; then
  echo "Using current HEAD"
  git clone --recurse-submodules -j8 https://github.com/RedisGraph/RedisGraph.git --depth 1
  cd RedisGraph
fi
if [[ "$COMMIT" != "" ]]; then
  echo "Using commit ${COMMIT}"
  git clone --recurse-submodules -j8 https://github.com/RedisGraph/RedisGraph.git 
  cd RedisGraph
  git checkout ${COMMIT}
fi

# first build graphblas
make -C src ../deps/GraphBLAS/build/libgraphblas.a JOBS=${JOBS} 
# then build other deps and redisgraph
make -j ${JOBS}

# clean
cd ..
