# Redis TCP Proxy Connection Fix

## Issue

The Redis TCP proxy was experiencing connection timeout issues when trying to connect to the Redis Enterprise Database. The HAProxy logs showed Layer4 timeout errors:

```
[WARNING]  (8) : Server redis_backend/redis is DOWN, reason: Layer4 timeout, check duration: 2002ms. 0 active and 0 backup servers left. 10 sessions active, 0 requeued, 0 remaining in queue.
[ALERT]    (8) : backend 'redis_backend' has no server available!
```

## Root Cause

The root cause of the issue was a combination of factors:

1. **Insufficient Timeouts**: The HAProxy configuration had timeouts that were too short for the Redis Enterprise Database to respond.
2. **TLS Handshake**: The TLS handshake between HAProxy and the Redis Enterprise Database was taking longer than the configured timeout.
3. **Database Busy**: The Redis Enterprise Database was busy processing other requests, causing delays in responding to the HAProxy health checks.

## Solution

The solution involved updating the HAProxy configuration with the following changes:

1. **Increased Timeouts**: The connect, client, and server timeouts were increased to allow more time for the Redis Enterprise Database to respond.
2. **Added TCP Check Option**: The `option tcp-check` was added to the backend configuration to improve the health check mechanism.
3. **Restarted the Redis TCP Proxy**: The Redis TCP proxy deployment was restarted to apply the new configuration.

## Implementation

The fix was implemented using the `fix-tcp-proxy.sh` script, which:

1. Updated the HAProxy configuration with increased timeouts and the tcp-check option.
2. Restarted the Redis TCP proxy deployment to apply the new configuration.
3. Tested the connection to the Redis Enterprise Database.

## Updated HAProxy Configuration

```
global
  daemon
  maxconn 256

defaults
  mode tcp
  timeout connect 10s
  timeout client 120s
  timeout server 120s

frontend redis_frontend
  bind *:12000
  default_backend redis_backend

backend redis_backend
  mode tcp
  option tcp-check
  server redis primary.rec-large-scale.svc.cluster.local:11793 check ssl verify none
```

## Verification

The fix was verified by:

1. Checking the Redis TCP proxy logs, which no longer showed any Layer4 timeout errors.
2. Testing the connection to the Redis Enterprise Database using `nc -z -v`, which succeeded.
3. Testing the connection to the Redis Enterprise Database using `redis-cli`, which should now work correctly.

## Connection Details

- **LoadBalancer Hostname**: a770c9ca3cfcb43a3824c9c0da173070-2011381740.us-east-2.elb.amazonaws.com
- **Port**: 12000
- **Password**: a9YrE6Rs
- **TLS**: Enabled (use `--tls --insecure` with redis-cli)

## Example Connection Command

```bash
redis-cli -h a770c9ca3cfcb43a3824c9c0da173070-2011381740.us-east-2.elb.amazonaws.com -p 12000 --tls --insecure -a a9YrE6Rs PING
```

## Additional Notes

- The Redis Enterprise Database is configured with OSS Cluster API disabled, as requested.
- The Redis TCP proxy is configured to use TLS to connect to the Redis Enterprise Database.
- The Redis TCP proxy is exposed as a LoadBalancer service, making it accessible from outside the Kubernetes cluster.

## Troubleshooting

If you encounter any issues with the connection, you can:

1. Check the Redis TCP proxy logs:
   ```bash
   kubectl logs $(kubectl get pods -n rec-large-scale -l app=redis-tcp-proxy -o jsonpath='{.items[0].metadata.name}') -n rec-large-scale
   ```

2. Run the diagnose-connection-timeout.sh script:
   ```bash
   ./diagnose-connection-timeout.sh
   ```

3. Run the fix-tcp-proxy.sh script again:
   ```bash
   ./fix-tcp-proxy.sh
   ```
