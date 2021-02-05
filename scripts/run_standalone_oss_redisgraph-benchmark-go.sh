#!/bin/bash

# exit immediately on error
set -e
HOSTNAME=${HOSTNAME:-"127.0.0.1"}
PORT=${PORT:-6379}
TLS_PORT=${TLS_PORT:-6080}
CLIENTS=${CLIENTS:-50}
REQUESTS=${REQUESTS:-100000}

# workaround for terraform env variables passing
for ARGUMENT in "$@"; do
  KEY=$(echo $ARGUMENT | cut -f1 -d=)
  VALUE=$(echo $ARGUMENT | cut -f2 -d=)
  case "$KEY" in
  HOSTNAME) HOSTNAME=${VALUE} ;;
  PORT) PORT=${VALUE} ;;
  *) ;;
  esac
done

OUTPUT_NAME_SUFIX=${OUTPUT_NAME_SUFIX:-"benchmark-results"}

# Ensure redisgraph-benchmark-go is available
EXE_FILE_NAME=${EXE_FILE_NAME:-$(which redisgraph-benchmark-go)}

if [[ -z "${EXE_FILE_NAME}" ]]; then
  echo "redisgraph-benchmark-go not available. It is not specified explicitly and not found in \$PATH"
  exit 1
fi

FILENAME=${OUTPUT_NAME_SUFIX}.json
echo "Running test: $TEST_NAME"
echo "  Saving results to file: ${FILENAME}"

${EXE_FILE_NAME} \
  -p ${PORT} \
  -h ${HOSTNAME} \
  -c ${CLIENTS} \
  -n ${REQUESTS} \
  -query "CREATE(n)" \
  -json-out-file ${FILENAME}
