# Captured host configuration (oss-api, us-east-1)

Copies of what runs on `i-0f292e23e1ca09cf4`, so the host can be rebuilt. Terraform does not apply any of this.

| File | Lives on the host at | Notes |
|---|---|---|
| `supervisor/ci.benchmarks-watchdog.conf` | `/etc/supervisor/conf.d/` | `redisbench-admin watchdog --terminate-after-secs 3600`. Holds a static AWS key (see below). |
| `supervisor/api.benchmarks.redislabs.com.conf` | `/etc/supervisor/conf.d/` | **Stale**: the API now runs in Docker. `autostart = false`; remove it. |
| `rbs-api/Dockerfile`, `rbs-api/run.sh` | n/a | Reconstructed from `docker history` / `docker inspect`. |
| `../../benchmarks_redislabs_infrastructure/config/haproxy.cfg` | proxy `/etc/haproxy/haproxy.cfg` | `:15000` -> `35.174.199.145:35000` is the GitHub webhook path. |

Webhook path: GitHub -> proxy `:15000` (HAProxy) -> this host `:35000` (`rbs-api`, `POST /api/gh/redis/redis/commits`).

## Secrets (not in git)
Placeholders to fill from the host or the team's secret store: `GH_REDIS_SERVER_AUTH`, `PERFORMANCE_RTS_AUTH`,
`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` (the watchdog's static IAM user key; the host has no instance role),
`<REDIS_AUTH>` in `haproxy.cfg`. Do not commit the real values.

## Restart notes
`rbs-api` is `restart=always`; docker, supervisor and alloy are enabled; the watchdog autostarts.
