#!/bin/bash
# The `docker run` the running container corresponds to (rbs-api, restart=always, port 35000, logs bind-mounted).
# GH_REDIS_SERVER_AUTH is the AUTH password of the RTS stream on benchmarks.redislabs.com:12010.
set -euo pipefail
: "${GH_REDIS_SERVER_AUTH:?set GH_REDIS_SERVER_AUTH}"
mkdir -p /home/ubuntu/rbs-api-logs
docker run -d --name rbs-api --restart always \
  -p 35000:35000 \
  -v /home/ubuntu/rbs-api-logs:/logs \
  -e PULL_REQUEST_TRIGGER_LABEL=action:run-benchmark \
  -e BENCHMARK_PR_DIFF_SCOPING=0 \
  -e GH_REDIS_SERVER_HOST=benchmarks.redislabs.com \
  -e GH_REDIS_SERVER_PORT=12010 \
  -e GH_REDIS_SERVER_USER=default \
  -e GH_REDIS_SERVER_AUTH \
  rbs-api:py311 --port 35000 --logname /logs/api.log
