#!/bin/bash

USER=${SSH_USER:-"ubuntu"}
PEM=${PEM:-"~/redislabs/pems/perf-cto-us-east-2.pem"}
RE_VERSION=${RE_VERSION:-"6.2.8-53"}
RE=${RE:-"artifacts/redislabs-${RE_VERSION}-bionic-amd64.tar"}
CLUSTER_NAME=${CLUSTER_NAME:-"perf-cluster"}
U=${U:-"performance@redislabs.com"}
P=${P:-"performance"}
REJSON_VERSION=${REJSON_VERSION:-"2.0.6"}
REJSON_ARTIFACT=${REJSON_ARTIFACT:-"artifacts/rejson.Linux-ubuntu18.04-x86_64.$REJSON_VERSION.zip"}
PROXY_THREADS=${PROXY_THREADS:-6}
