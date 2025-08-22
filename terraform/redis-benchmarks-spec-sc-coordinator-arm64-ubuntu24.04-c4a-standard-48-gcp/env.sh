#!/usr/bin/env bash

# env.sh

# Change the contents of this output to get the environment variables
# of interest. The output must be valid JSON, with strings for both
# keys and values.
if command -v python3 >/dev/null 2>&1; then
python3 - <<'PY'
import json, os
get = lambda k, d='': os.environ.get(k, d)

data = {
  # Event stream
  'event_stream_host': get('EVENT_STREAM_HOST', ''),
  'event_stream_port': get('EVENT_STREAM_PORT', ''),
  'event_stream_user': get('EVENT_STREAM_USER', ''),
  'event_stream_pass': get('EVENT_STREAM_PASS', ''),

  # Datasink (RedisTimeSeries)
  'datasink_redistimeseries_host': get('DATASINK_RTS_HOST', ''),
  'datasink_redistimeseries_port': get('DATASINK_RTS_PORT', ''),
  'datasink_redistimeseries_pass': get('DATASINK_RTS_PASS', ''),
}
print(json.dumps(data))
PY
else
  echo '{}'
fi
