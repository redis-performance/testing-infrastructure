#!/bin/bash
source defaults.sh

mkdir -p artifacts
rm ${RE}

wget https://s3.amazonaws.com/redis-enterprise-software-downloads/6.2.8/redislabs-${RE_VERSION}-bionic-amd64.tar -q --show-progress -O ${RE}