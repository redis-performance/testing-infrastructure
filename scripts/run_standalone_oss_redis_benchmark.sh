#!/bin/bash

# exit immediately on error
set -e
HOSTNAME=${HOSTNAME:-"127.0.0.1"}
PORT=${PORT:-6379}
TLS_PORT=${TLS_PORT:-6080}
CLIENTS=${CLIENTS:-50}
REQUESTS=${REQUESTS:-100000}
DATA_SIZE=${DATA_SIZE:-3}
KEYSPACELEN=${KEYSPACELEN:-1}
PIPELINE=${PIPELINE:-1}
CLUSTER=${CLUSTER:-""}
CSV=${CSV:-"--csv"}
RUNS_PER_VARIATION=${RUNS_PER_VARIATION:-1}


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

# How many benchmark threads - match num of cores, or default to 8
THREADS=${THREADS:-$(grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 8)}

OUTPUT_NAME_SUFIX=${OUTPUT_NAME_SUFIX:-""}

# All available default tests
TEST_TYPES_ALL="\
  set \
  get \
  incr \
  lpush \
  rpush \
  lpop \
  rpop \
  sadd \
  hset \
  spop \
  zadd \
  zpopmin \
  lrange \
  mset"

# What tests to run
TEST_TYPES=${TEST_TYPES:-$TEST_TYPES_ALL}

# Ensure redis-benchmark is available
EXE_FILE_NAME=${EXE_FILE_NAME:-$(which redis-benchmark)}
CLI_EXE_FILE_NAME=${CLI_EXE_FILE_NAME:-$(which redis-cli)}

if [[ -z "${EXE_FILE_NAME}" ]]; then
  echo "redis-benchmark not available. It is not specified explicitly and not found in \$PATH"
  exit 1
fi

if [[ -z "${CLI_EXE_FILE_NAME}" ]]; then
  echo "redis-cli not available. It is not specified explicitly and not found in \$PATH"
  exit 1
fi

for RUN in $(seq 1 ${RUNS_PER_VARIATION}); do
  for TEST_NAME in $TEST_TYPES; do
    FILENAME=${OUTPUT_NAME_SUFIX}_run_${RUN}_test_${TEST_NAME}.txt
    echo "Running test: $TEST_NAME"
    echo "  Saving results to file: ${FILENAME}"
    echo "  Used benchmark command : ${EXE_FILE_NAME} --threads ${THREADS} -e -p ${PORT} -h ${HOSTNAME} -r ${KEYSPACELEN} -c ${CLIENTS} -n ${REQUESTS} -d ${DATA_SIZE} ${CLUSTER} -P ${PIPELINE} -t ${TEST_NAME}"
    TEE_CMD="tee -a ${FILENAME}"
    # if [[ "${RUN}" != "1" ]]; then
    #   TEE_CMD="tee -a >(tail -n 1 > ${FILENAME})"
    # fi

    ${EXE_FILE_NAME} \
      --threads ${THREADS} \
      -e \
      -p ${PORT} \
      -h ${HOSTNAME} \
      -r ${KEYSPACELEN} \
      -c ${CLIENTS} \
      -n ${REQUESTS} \
      -d ${DATA_SIZE} \
      ${CLUSTER} \
      ${CSV} \
      -P ${PIPELINE} \
      -t ${TEST_NAME} \
      2>&1 | ${TEE_CMD}
  done

done
