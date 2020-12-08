#!/bin/bash

# exit immediately on error
set -e

wget https://s3.amazonaws.com/benchmarks.redislabs/oss/benchmark.artifacts/ubuntu-18.04/redis-benchmark
chmod +x redis-benchmark
sudo mv redis-benchmark /usr/local/bin/