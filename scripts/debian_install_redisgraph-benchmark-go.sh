#!/bin/bash

# exit immediately on error
set -e

wget https://s3.amazonaws.com/benchmarks.redislabs/redisgraph/redisgraph-benchmark-go/unstable/redisgraph-benchmark-go_linux_amd64
chmod +x redisgraph-benchmark-go_linux_amd64
sudo mv redisgraph-benchmark-go_linux_amd64 /usr/local/bin/redisgraph-benchmark-go
