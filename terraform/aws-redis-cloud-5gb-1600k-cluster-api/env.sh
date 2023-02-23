#!/bin/sh

# env.sh

# Change the contents of this output to get the environment variables
# of interest. The output must be valid JSON, with strings for both
# keys and values.
cat <<EOF
{
  "rediscloud_payment_4digits": "$REDIS_CLOUD_PAYMENT_4DIGITS",
  "rediscloud_default_password": "$REDIS_CLOUD_DEFAULT_PASSWORD"
}
EOF