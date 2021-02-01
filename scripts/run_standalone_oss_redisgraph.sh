#!/bin/bash

# exit immediately on error
set -e
set -x
PORT=${PORT:-6379}
TLS_PORT=${TLS_PORT:-6080}
APPENDONLY=${APPENDONLY:-"no"}
SAVE=${SAVE:-'""'}
DAEMONIZE=${DAEMONIZE:-"yes"}
PROTECTED_MODE=${PROTECTED_MODE:-"no"}
MODULEPATH=${MODULEPATH:-"/home/ubuntu/RedisGraph/src/redisgraph.so"}

# Ensure redis-server is available
EXE_FILE_NAME=${EXE_FILE_NAME:-$(which redis-server)}

if [[ -z "${EXE_FILE_NAME}" ]]; then
  echo "redis-server not available. It is not specified explicitly and not found in \$PATH"
  exit 1
fi

${EXE_FILE_NAME} \
  --port ${PORT} \
  --protected-mode ${PROTECTED_MODE} \
  --save ${SAVE} \
  --daemonize ${DAEMONIZE} \
  --appendonly ${APPENDONLY} \
  --loadmodule ${MODULEPATH}

echo "Printing redis info"
redis-cli -p ${PORT} info
