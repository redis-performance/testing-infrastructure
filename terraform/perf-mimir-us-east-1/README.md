# perf-mimir-us-east-1

The performance team's long-retention metrics store: [Grafana Mimir](https://grafana.com/oss/mimir/) in
monolithic mode, with its blocks in S3, kept forever. Benchmark clients and the systems under test push
Prometheus `remote_write` while a run is in flight; Grafana reads it with the Prometheus query API. It is
multi-tenant: each team or project gets its own tenant, and the credential decides the tenant. The first tenant
is `ultra` (the Redis Ultra perf benchmarks). Benchmarks account (726902207197), us-east-1.

| piece | what |
|---|---|
| EC2 `r7i.xlarge`, Ubuntu 26.04 | Mimir 3.2.1 (`-target=all`, the release binary, SHA-256 checked, under systemd, every port on 127.0.0.1) behind nginx (nginx.org stable) |
| `https://metrics.cto.redislabs.com` | the only way in: push (`POST /api/v1/push`) from anywhere with a push credential; read (`/prometheus/api/v1/{query,query_range,series,labels,label/<name>/values,metadata}`) with a read credential and only from `read_allowed_cidrs` (the neptune-dev Grafana's NAT). Everything else is 403. |
| S3 `perf-mimir-us-east-1-<account>` | the TSDB blocks (`blocks/<tenant>/`, kept forever: `retention_period = 0`) and the ruler's storage (`ruler/`). Versioned; old versions expire after 30 days. |
| EBS `…-data` (150 GiB, `/data`) | the ingester's WAL and TSDB head, the last 13 h of blocks, compaction scratch, the store-gateway's index headers and the TLS certificates. Survives instance replacement (`prevent_destroy`); not snapshotted, since S3 has every shipped block. |
| SSM `/perf-mimir-us-east-1/…` | `htpasswd/{push,read}` (credential hashes, written by hand) and `runtime-overrides` (per-tenant limits, written by Terraform) |
| CloudWatch | logs `/perf-mimir-us-east-1/{mimir,nginx,system}`; alarms → SNS `…-alarms` (status checks with recover/reboot, CPU, disk, memory, `Ready`, certificate days left, discarded samples, series used) |

About $220/month at list prices to start, most of it the instance; S3 grows with what's kept (see "Cost").

## Apply

```bash
cd terraform/perf-mimir-us-east-1
AWS_PROFILE=bench terraform init
AWS_PROFILE=bench terraform plan -var alarm_email=<you>@redis.com -out p.tfplan
AWS_PROFILE=bench terraform apply p.tfplan
```

Without `alarm_email` the alarms notify nobody (confirm the SNS subscription email). `github_actor` defaults to
the owner's tag value because nothing passes it on a manual apply.

## Out of band, once

1. **DNS** (CTO account, zone `cto.redislabs.com`): an A record `metrics.cto.redislabs.com` →
   `terraform output -raw public_ip`, and a CAA record limiting issuance to Let's Encrypt:
   ```bash
   IP=$(AWS_PROFILE=bench terraform output -raw public_ip)
   ZONE=$(aws route53 list-hosted-zones-by-name --profile <cto-profile> --dns-name cto.redislabs.com \
     --query 'HostedZones[0].Id' --output text)
   aws route53 change-resource-record-sets --profile <cto-profile> --hosted-zone-id "$ZONE" --change-batch "$(jq -n --arg ip "$IP" '{Changes: [
     {Action: "CREATE", ResourceRecordSet: {Name: "metrics.cto.redislabs.com.", Type: "A", TTL: 300, ResourceRecords: [{Value: $ip}]}},
     {Action: "CREATE", ResourceRecordSet: {Name: "metrics.cto.redislabs.com.", Type: "CAA", TTL: 300,
       ResourceRecords: [{Value: "0 issue \"letsencrypt.org\""}, {Value: "0 issuewild \";\""}]}}]}')"
   ```
   The server gets its certificate within 10 minutes of the name resolving to it (it doesn't try before: failed
   validations are rate limited), then enables 443.
2. **Credentials** for the first tenant, `ultra`: see "Credentials" below.

## Tenants

A tenant is a separate TSDB in Mimir: its own series, limits and blocks (`blocks/<tenant>/`). Queries never
cross tenants.

- **The credential is the tenant.** Users are named `<tenant>-<role>-<1|2>` (`ultra-push-1`, `ultra-read-1`);
  nginx forwards the `<tenant>` part as `X-Scope-OrgID`, after it has checked the password. Whatever tenant
  header a client sends is dropped, so a client can't choose its tenant: whoever writes the SSM parameter does.
  Tenant names: `[a-z][a-z0-9_]{0,31}` (no `-`, so the user name splits one way).
- **Reads are per tenant too.** A `<tenant>-read-N` credential reads only that tenant, so one Grafana datasource
  per tenant, and a team's dashboards can't see another team's data. A panel that needs two tenants uses
  Grafana's mixed datasource. Mimir's tenant federation (`X-Scope-OrgID: a|b`) is off, and nginx never sends a
  `|`. Turning it on later means a read user whose map entry is a list of tenants, which is easy to add but is a
  wider grant, so it waits for a real need.
- **Adding a tenant** is adding its users to the two parameters (below). No Terraform change: the default limits
  apply. To give it other limits, add it to `tenant_limits`.
- **Limits.** The defaults (variables) apply to each tenant: 2M active series, 100k samples/s with a burst of
  1M, 64 label names per series, label names up to 1024 bytes and values up to 4096, a 1 h out-of-order window.
  `tenant_limits` overrides any Mimir limit per tenant (Mimir's YAML names), e.g.
  `{ ultra = { max_global_series_per_user = 3000000 } }`; Terraform writes it to SSM, and the server applies it
  within 5 minutes without a restart. The server checks it first (known limit names, the default's type) and
  keeps the current overrides if it fails, or if Mimir refuses them; `/var/log/perf-mimir-ops.log` says why.
  Above the per-tenant limits sit two for the whole server, sized to the instance: `max_series_total` (2.5M) and
  `max_ingestion_rate_total` (150k samples/s). Past them the ingester refuses pushes rather than run out of memory.

## Credentials

Two users per tenant and role (`-1` and `-2`, so a rotation can overlap), as SHA-512 crypt htpasswd lines, one
per line, in the SecureString parameters `/perf-mimir-us-east-1/htpasswd/push` and `…/read`. The server reloads
them every 5 minutes. It accepts only `<tenant>-<role>-1|2:$6$…` lines in each role's own parameter, keeps the
current file if a value is malformed or SSM errors, and empties it when the parameter is deleted (revokes
everyone). SHA-512 crypt, not bcrypt: nginx checks the password on every request, and bcrypt would block its
workers.

Add a user (the same for `read`; keep the password in the password manager, it's what the client sends):
```bash
export AWS_PROFILE=bench AWS_REGION=us-east-1
T=ultra R=push N=1 PARAM=/perf-mimir-us-east-1/htpasswd/$R
P=$(openssl rand -base64 32)
LINE="$T-$R-$N:$(openssl passwd -6 -stdin <<<"$P")"
CUR=$(aws ssm get-parameter --with-decryption --name "$PARAM" --query Parameter.Value --output text 2>/dev/null || true)
aws ssm put-parameter --overwrite --type SecureString --name "$PARAM" \
  --value "$( { printf '%s\n' "$CUR" | grep -v "^$T-$R-$N:"; echo "$LINE"; } | sed '/^$/d')" >/dev/null
```
(It keeps the other users' lines and replaces an older line for the same user.)

- **Rotate:** add `<tenant>-<role>-2` with a new password, move the clients to it, then remove the `-1` line.
- **Revoke one user:** put the parameter back without its line. Deleting the parameter revokes the whole role.
- **Where the read password goes:** the Grafana datasource (below). The push password goes to the clients
  (`remote_write` `basic_auth`), never into a repository.

## Ultra label contract (tenant `ultra`)

Every series the Ultra perf suite pushes carries these labels, set by the collector (Alloy) for the whole run,
so a series can always be traced to the run that produced it and runs are never pooled by accident:

| label | value |
|---|---|
| `source_run_id` | the GitHub Actions run ID of the perf workflow run |
| `run_attempt` | that run's attempt number |
| `run_id` | the suite's ID for the benchmark run |
| `lane` | the perf lane the run used |
| `profile` | the benchmark profile (preset) |
| `database_id` | the database under test |
| `phase` | the benchmark phase the sample belongs to |
| `node_type` | the data nodes' EC2 instance type (`unknown` if it couldn't be read) |
| `operator_image` | the operator image the database ran under |
| `redis_version` | the Redis version of the database |
| `job` | the source: `ycsb` (the load generator), `shard` (Redis shard exporters), `node` (data-node `node_exporter`), `pod` (cAdvisor container metrics), `client_host` (the benchmark client's `node_exporter`) |

Rules for any tenant's clients:

- A label value is never empty (`unknown` instead): Prometheus treats an empty label as absent, so the series
  would silently match other runs' queries.
- No unbounded values in labels (request IDs, timestamps, per-key names): every distinct label set is a new
  series held in memory. A new run, phase or pod is a new series by design, and that's fine at these volumes.
- Keep it under 64 label names per series, including the metric's own and the scrape's `instance`.
- Samples may arrive up to an hour late per series (after a network blip, clients replay their buffer); older
  ones are discarded (the `discarded-samples` alarm).

## Sizing

Mimir's ingester keeps every active series in memory, so memory decides the instance. Grafana's capacity
planning guidance budgets, with production headroom, 2.5 GB of ingester memory per 300k in-memory series and
1 GB of distributor memory per 25k samples/s. At the server-wide caps (2.5M series, 150k samples/s) that is
~21 + 6 GB. The `r7i.xlarge` (4 vCPU, 32 GiB, Go's soft memory limit at 80 % = 25.6 GiB) holds it. An
`m7i.xlarge` (16 GiB) would hold ~1.2M series, below the 2–5M a few concurrent benchmark runs may reach. It's the
cheaper choice if `max_series_total` drops to 1.2M.

CPU is the compromise. The same guidance asks for 1 core per 25k samples/s and 1 per 300k series, about 14
cores at the caps. Those numbers are for production clusters. Benchmark ingest comes in bursts, and a few runs
are expected to stay well under the caps, so 4 vCPU is the starting point. The `cpu` alarm (85 % for 15
minutes) says when it isn't enough; the next steps are `m7i.2xlarge` (8 vCPU, 32 GiB, ~$294) and `r7i.2xlarge`
(8 vCPU, 64 GiB, ~$386, also for 5M series with `max_series_total` raised).

The data disk (150 GiB gp3). The same guidance gives the ingester 5 GB per 300k series (~42 GB at 2.5M) for the
WAL, the head and the blocks of the last 13 h. On top of that:
- compaction scratch: a 24 h block of the busiest tenant plus its sources, up to ~30 GB at the rate cap;
- the store-gateway's index headers, which grow slowly with the years kept.

That leaves room for the cardinality spikes benchmark runs bring. The `disk-data` alarm fires at 80 %, and the
disk grows in place (runbook).

## Cost

List prices, us-east-1, per month: EC2 `r7i.xlarge` ~$193, EBS (40 + 150 GiB gp3) ~$15, public IPv4 ~$4,
CloudWatch (metrics, alarms, logs; successful pushes aren't logged) ~$5, S3 requests ~$1–3. S3 storage then grows
with what's kept: a 24 h block costs roughly 1.5–2 bytes a sample, so a sustained 20k samples/s (a couple of
runs) adds ~3 GB a day, ~$2 a month for each month kept. Recently compacted sources stay as old versions for 30
days. `m7i.xlarge` instead saves ~$46.

## Teardown

`terraform destroy` fails on purpose: the bucket, the volume and the EIP (the DNS record points at it) have
`prevent_destroy`, and the instance has termination protection. See the runbook's "Decommission".

## Runbook

Workstation setup (no SSH; SSM Session Manager):
```bash
export AWS_PROFILE=bench AWS_REGION=us-east-1
IID=$(terraform output -raw instance_id); B=$(terraform output -raw bucket); VOL=$(terraform output -raw data_volume_id)
aws ssm start-session --target "$IID"          # then: sudo -i
```

### Health (on the instance)

```bash
HOST=metrics.cto.redislabs.com
systemctl is-active mimir nginx mimir-credentials.timer mimir-limits.timer mimir-tls.timer mimir-watchdog.timer certbot.timer
findmnt /data && cat /data/.perf-mimir          # perf-mimir-data
curl -s 127.0.0.1:9009/ready; echo
curl -s --resolve $HOST:443:127.0.0.1 https://$HOST/healthz
grep -E 'level=(error|warn)' /var/log/mimir/mimir.log | tail
tail -20 /var/log/perf-mimir-ops.log            # credential and limit reloads
tail -50 /var/log/server-init.log               # the bootstrap
```
Mimir's own status pages (rings, runtime config, per-tenant limits) are on 127.0.0.1:9009 through the forward
below, e.g. `/ingester/ring`, `/runtime_config?mode=diff`, `/api/v1/user_limits` (with a tenant header).

### Query from a workstation (SSM port forward)

The public read path only admits the Grafana NAT. Tunnel to Mimir's port and send the tenant yourself; the
forward is admin access, so it has no credentials:
```bash
aws ssm start-session --target "$IID" --document-name AWS-StartPortForwardingSession \
  --parameters portNumber=9009,localPortNumber=19009 &
curl -s -H 'X-Scope-OrgID: ultra' 'localhost:19009/prometheus/api/v1/label/source_run_id/values' | jq .
```
A local Grafana works the same way: a Prometheus datasource with URL `http://localhost:19009/prometheus` (from a
Grafana in Docker, `http://host.docker.internal:19009/prometheus`) and a custom header `X-Scope-OrgID: ultra`.

### Grafana datasource (neptune-dev Grafana)

One Prometheus datasource per tenant, with that tenant's read credential. The tenant header is nginx's job, not
the datasource's. Provisioning:
```yaml
apiVersion: 1
datasources:
  - name: Perf metrics (ultra)
    uid: perf-mimir-ultra
    type: prometheus
    access: proxy
    url: https://metrics.cto.redislabs.com/prometheus
    basicAuth: true
    basicAuthUser: $PERF_MIMIR_READ_USER          # ultra-read-1
    secureJsonData:
      basicAuthPassword: $PERF_MIMIR_READ_PASSWORD
    jsonData:
      prometheusType: Mimir                       # Grafana can't ask (status/buildinfo isn't served)
      prometheusVersion: 2.9.1
      httpMethod: POST
      timeInterval: 10s                           # the collectors' scrape interval
      timeout: 130
    editable: false
```
The password reaches Grafana the way the Pyroscope read credential does (a secret synced into the Grafana pod's
environment). Grafana's requests must leave from an address in `read_allowed_cidrs`. Exemplars, alerting rules
and `status/*` aren't served, so leave them off.

**Switches:** `touch /data/.hold` keeps Mimir stopped across restarts and reboots; `rm /data/.hold && systemctl
start mimir` undoes it. While it's stopped, pushes fail and clients buffer and retry (and drop what's older than
their buffer).

### Planned replacement (user-data, AMI, Mimir version, a default limit, CIDR change)

1. No run in flight (pushes fail during the swap; clients retry, but their buffer is finite).
2. `terraform plan -out r.tfplan`: expect only `-/+` on the instance, the volume attachment and the EIP
   association, and in-place alarm updates. **Stop if anything touches the volume or the bucket.**
3. `terraform apply r.tfplan` (6–10 min): the old instance stops (Mimir gets 120 s), the volume moves, the new
   instance boots, mounts `/data`, keeps the certificate, replays the WAL and starts. Nothing shipped or unshipped
   is lost.
4. Health check. If the bootstrap failed (`/var/log/server-init.log`) on a transient download, re-run it:
   `cloud-init single --name scripts_user --frequency always` (idempotent).

### Instance lost

- Host failure: the `system-status` alarm recovers it (same ID, IP, volume); `instance-status` reboots it.
- Terminated: the volume is intact; `terraform apply` creates a new instance and attaches it.

### Data volume lost

Every block shipped to S3 is safe; what's lost is the samples not yet shipped (about the last 2 h). Drop the
volume from the state and apply: a new, blank volume is formatted and Mimir starts on it (the certificate is
issued again).
```bash
terraform state rm aws_ebs_volume.data
terraform plan -out new.tfplan     # a new volume; instance, attachment, EIP association replaced
terraform apply new.tfplan
```

### Undelete blocks (purge by mistake)

The bucket keeps deleted objects as old versions for 30 days. This is for a purge (a wrong `retention_period`,
a manual delete), not for compaction, whose sources are already in the compacted blocks. Fix the cause first
(e.g. the retention), then, with Mimir held (`touch /data/.hold; systemctl stop mimir`) and an admin role (the
server's can't touch versions):
```bash
TM=<UTC time just before the purge, e.g. 2026-10-06T09:00:00>; P=blocks/<tenant>/
aws s3api list-object-versions --bucket "$B" --prefix "$P" --output json \
  | jq -r --arg t "$TM" '.DeleteMarkers[]? | select(.IsLatest and .LastModified >= $t) | [.Key,.VersionId] | @tsv' > markers.tsv
while IFS=$'\t' read -r k v; do aws s3api delete-object --bucket "$B" --key "$k" --version-id "$v" >/dev/null; done < markers.tsv
# The compactor's deletion marks written since then would delete those blocks again:
aws s3api list-objects-v2 --bucket "$B" --prefix "$P" --output json \
  | jq -r --arg t "$TM" '.Contents[]? | select((.Key | endswith("deletion-mark.json")) and .LastModified >= $t) | .Key' \
  | while read -r k; do aws s3 rm "s3://$B/$k"; done
```
Then `rm /data/.hold && systemctl start mimir`; the compactor rebuilds the tenant's bucket index within the hour.

### Mimir upgrade

Read the release notes (config changes and deprecations), then set `mimir_version` and `mimir_sha256` (the
release's `mimir-linux-amd64-sha-256` asset; check it matches the binary) in a PR and follow the planned
replacement. A rollback is the same with the old pair; Mimir's blocks are Prometheus TSDB blocks, so that
normally works, but check the release notes for format or WAL changes first.

### Grow the data disk

Raise `data_volume_size_gb` and apply (in place), then `resize2fs "$(findmnt -n -o SOURCE /data)"` on the
instance (the bootstrap also does it on the next replacement).

### Certificates

Renewed by `certbot.timer` (webroot, nginx reload hook); stored on `/data`, so a replacement doesn't re-issue.
`CertDaysLeft` alarms under 14 days (and reads 0 until the A record exists).

### Decommission

In a reviewed PR remove the `prevent_destroy`s and `disable_api_termination`, decide whether the bucket is kept;
`terraform destroy`; delete the DNS records.
