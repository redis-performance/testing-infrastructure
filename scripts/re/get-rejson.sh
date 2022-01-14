

#!/bin/bash
source defaults.sh

mkdir -p artifacts
rm ${REJSON_ARTIFACT}

wget https://redismodules.s3.amazonaws.com/rejson/rejson.Linux-ubuntu18.04-x86_64.$REJSON_VERSION.zip -q --show-progress -O ${REJSON_ARTIFACT}