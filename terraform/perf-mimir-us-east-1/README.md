# perf-mimir-us-east-1

The performance team's long-retention metrics store: [Grafana Mimir](https://grafana.com/oss/mimir/) in
monolithic mode, with its blocks in S3, kept forever. Benchmark clients and the systems under test push
Prometheus `remote_write` while a run is in flight; Grafana reads it with the Prometheus query API. It is
multi-tenant: each team or project gets its own tenant, and the credential decides the tenant. The first tenant
is `ultra` (the Redis Ultra perf benchmarks). Benchmarks account (726902207197), us-east-1.

| piece | what |
|---|---|
| EC2 `r7g.xlarge` (Graviton, arm64), Ubuntu 26.04 | Mimir 3.2.1 (`-target=all`, the release binary, SHA-256 checked, under systemd, every port on 127.0.0.1) behind nginx (nginx.org stable) |
| `https://metrics.cto.redislabs.com` | the only way in: push (`POST /api/v1/push`) from anywhere with a push credential; read (`/prometheus/api/v1/{query,query_range,series,labels,label/<name>/values,metadata}`) with a read credential and only from `read_allowed_cidrs` (the neptune-dev Grafana's NAT). Everything else is 403. |
| S3 `perf-mimir-us-east-1-<account>` | the TSDB blocks (`blocks/<tenant>/`, kept forever: `retention_period = 0`); `ruler/` stays empty (the ruler runs in `-target=all`, but its API isn't served). Versioned; old versions expire after 30 days. |
| EBS `…-data` (150 GiB, `/data`) | the ingester's WAL and TSDB head, the last 13 h of blocks, compaction scratch, the store-gateway's index headers and the TLS certificates. Survives instance replacement (`prevent_destroy`); not snapshotted, since S3 has every shipped block (two alarms watch that it does). |
| SSM `/perf-mimir-us-east-1/…` | `htpasswd/{push,read}` (credential hashes, written by hand); `tenants` and `runtime-overrides` (the tenant list and their limits, written by Terraform) |
| CloudWatch | logs `/perf-mimir-us-east-1/{mimir,nginx,system}`; alarms → SNS `…-alarms` (status checks with recover/reboot, CPU, disk, memory, `Ready`, certificate days left, discarded samples, series used, rejected configuration, block upload failures, compactor stale) |

About $220/month at list prices to start, nearly all of it the instance; S3 grows with what's kept (see "Cost").

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
     --query "HostedZones[?Name=='cto.redislabs.com.' && !Config.PrivateZone].Id | [0]" --output text)
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

- **The tenants are listed in Terraform.** `tenants` maps each tenant to its limit overrides (`{}` for the
  defaults); Terraform writes the list and the overrides to SSM, and the server picks them up within 5 minutes
  without a restart. Adding a team or project is a PR that adds its entry, plus its users (below). The list
  is a guard against mistakes (a typo can't create a tenant), not an authorization boundary: whoever can write
  the credential parameters can also write the SSM copy of the list until the next apply.
  Tenant names: `[a-z][a-z0-9_]{0,31}` (no `-`, so a user name splits one way). Never reuse a removed tenant's
  name: its data is kept forever, and the new owner would read it.
- **The credential is the tenant.** Users are named `<tenant>-<role>-<1|2>` (`ultra-push-1`, `ultra-read-1`).
  nginx admits only users of listed tenants and forwards the `<tenant>` part as `X-Scope-OrgID`, after it has
  checked the password. Whatever tenant header a client sends is dropped, so a client can't choose its tenant;
  whoever writes the parameters and `tenants` decides.
- **Reads are per tenant too.** A `<tenant>-read-N` credential reads only that tenant. That means one Grafana
  datasource per tenant, and a team's dashboards can't see another team's data. A panel that needs two tenants
  uses Grafana's mixed datasource. Mimir's tenant federation (`X-Scope-OrgID: a|b`) is off, and nginx never sends
  a `|`. Federated reads would need an explicit read user → tenant list map and federation turned on. That's a
  wider grant, so it waits for a real need.
- **Limits.** The defaults (variables) apply to each tenant: 300k active series and 20k samples/s (burst
  200k), 64 label names per series, label names up to 1024 bytes and values up to 4096, a 1 h out-of-order
  window, and query guards (2 GiB estimated memory, 2 GiB of chunks and 1M series per query). `ultra` gets 1.5M
  series and 100k samples/s (burst 1M) through `tenants`. The overridable limits are the fields of the
  `tenants` type (series, rates, label names, out-of-order window, retention, query guards); Terraform checks
  their values. If Mimir still refuses a new runtime config, it keeps the last good one and the
  `config-rejected` alarm fires (`mimir.log` says why).
- **The whole server's caps:** `max_series_total` (2M) and `max_ingestion_rate_total` (120k samples/s), sized to
  the instance ("Sizing"). Past them the ingester refuses pushes for every tenant rather than run out of memory.
  Keep the per-tenant limits of the tenants that run at the same time within them, so one tenant can't crowd out
  the rest.
- **Shared by all tenants:** the read source allowlist (`read_allowed_cidrs`; another team's Grafana NAT added
  there is open to every tenant's read credential, though each still needs one) and the alarms (the
  `discarded-samples` alarm fires on any tenant's client, and on pushes refused at the server-wide caps; the
  logs say which).

## Credentials

There are two users per tenant and role (`-1` and `-2`, so a rotation can overlap). They are SHA-512 crypt
htpasswd lines, one per line, in the SecureString parameters `/perf-mimir-us-east-1/htpasswd/push` and `…/read`.
The server reloads them every 5 minutes and checks each line on its own: a SHA-512 crypt hash, a
`<tenant>-<role>-1|2` name in its role's own parameter, a listed tenant, and not a repeat of an earlier line's
user. It installs the good lines and drops the others. Each drop raises the `config-rejected` alarm and leaves
a line, naming the user only, in `/var/log/perf-mimir-ops.log`. An SSM error keeps the current file; if it lasts
20 minutes, the alarm fires too, because revocations aren't applied meanwhile. Deleting a parameter revokes
that role for every tenant. SHA-512 crypt, not
bcrypt: nginx checks the password on every request, and bcrypt would block its workers.

Add or replace a user (the same for `read`). Keep the password in the password manager; it's what the client
sends. It needs OpenSSL 1.1.1+: macOS's LibreSSL `openssl` has no `-6` (use Homebrew's).
```bash
export AWS_PROFILE=bench AWS_REGION=us-east-1
T=ultra R=push N=1 PARAM=/perf-mimir-us-east-1/htpasswd/$R
PW=$(openssl rand -base64 32)
LINE="$T-$R-$N:$(openssl passwd -6 -stdin <<<"$PW")"
if ! [[ $LINE =~ ^[a-z][a-z0-9_]{0,31}-(push|read)-[12]:\$6\$ ]]; then
  echo "bad line; nothing written"
elif ! { CUR=$(aws ssm get-parameter --with-decryption --name "$PARAM" --query Parameter.Value --output text 2>ssm.err) ||
         { grep -q ParameterNotFound ssm.err && CUR=; }; }; then
  echo "SSM read failed; nothing written"
else
  aws ssm put-parameter --overwrite --type SecureString --name "$PARAM" \
    --value "$( { printf '%s\n' "$CUR" | grep -v "^$T-$R-$N:"; echo "$LINE"; } | sed '/^$/d')" >/dev/null &&
    echo "written" || echo "SSM write failed"
fi
```
It keeps the other users' lines and replaces an older line for the same user. It writes nothing if the line is
malformed or the read fails, since an empty read would revoke everyone else. One person at a time: it's read-modify-write. A Standard parameter
holds 4 KB, about 30 lines; past that, `--tier Advanced` (8 KB).

After 5 minutes, check it took: `/var/log/perf-mimir-ops.log` (CloudWatch `/perf-mimir-us-east-1/system`,
stream `…/ops`) lists the tenant. A push credential gets 400 (an empty body), not 401, from
`curl -s -o /dev/null -w '%{http_code}\n' -u "$T-push-$N:$PW" -X POST https://metrics.cto.redislabs.com/api/v1/push`.

- **Rotate:** add `<tenant>-<role>-2` with a new password, move the clients to it, then revoke `-1`.
- **Revoke one user** (set `T`, `R` and `N` for the user being revoked):
  ```bash
  T=ultra R=push N=1 PARAM=/perf-mimir-us-east-1/htpasswd/$R
  CUR=$(aws ssm get-parameter --with-decryption --name "$PARAM" --query Parameter.Value --output text) && {
    NEW=$(printf '%s\n' "$CUR" | grep -v "^$T-$R-$N:")
    if [ -n "$NEW" ]; then aws ssm put-parameter --overwrite --type SecureString --name "$PARAM" --value "$NEW" >/dev/null
    else aws ssm delete-parameter --name "$PARAM"; fi; }   # last user: deleting the parameter revokes the role
  ```
- **Where the passwords go:** the read password into the Grafana datasource (below); the push password into the
  clients (`remote_write` `basic_auth`), never into a repository.
- **Failed logins cost CPU:** each wrong password is one SHA-512 crypt check (about a millisecond). The per-IP
  limit (200 requests/s) bounds one source, not many. The nginx access log has every failed push (`401`) if that
  ever needs a closer look.

## Ultra label contract (tenant `ultra`)

Every series the Ultra perf suite pushes carries these labels, set by the collector (Alloy). All are fixed for
the run except `phase`, which follows the benchmark, and `job`, which names the source. A series can always be
traced to the run that produced it, and runs are never pooled by accident:

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
| `profiled` | `true` if continuous profiling ran during the run, else `false` (profiled runs aren't compared with unprofiled ones) |
| `job` | the source: `ycsb` (the load generator), `shard` (Redis shard exporters), `node` (data-node `node_exporter`), `pod` (cAdvisor container metrics), `client_host` (the benchmark client's `node_exporter`) |

## Client rules (every tenant)

- A label value is never empty (`unknown` instead). An empty value is the same as no label, so two runs' series
  lose what tells them apart and merge (out-of-order and duplicate rejections, mixed data).
- No unbounded values in labels (request IDs, timestamps, per-key names): every distinct label set is a new
  series held in memory. A new run, phase or pod is a new series by design, and that's fine at these volumes.
- At most 64 label names per series, counting `__name__`, `job` and `instance`.
- Samples up to 1 h older than the tenant's newest sample are accepted (clients replay their buffer after a
  network blip); older ones are discarded (the `discarded-samples` alarm).

## Sizing

Mimir's ingester keeps every active series in memory, so memory decides the instance.

**Expected load.** Estimated from the Ultra collectors' configuration, not measured: about 5–15k series and
~1k samples/s per benchmark run (node_exporter on the client host, data-node and pod metrics federated at 30 s,
the shard exporters, the load generator). A few concurrent runs use a few percent of the caps. Check
`cortex_ingester_memory_series` (or the `SeriesUsedPercent` metric) after the first runs.

**The caps** (2M series, 120k samples/s across tenants) leave room for a few teams, cardinality mistakes, and
series that finished runs leave in memory until the next head compaction (up to ~3 h). They're sized to the
memory; the CPU (below) is what limits sustained throughput. Grafana's capacity planning figures, before the 50 % headroom it adds on top, are:
- ingester: 2.5 GB per 300k in-memory series, 16.7 GB at 2M;
- distributor: 1 GB per 25k samples/s, 4.8 GB at 120k;
- compactor: 4 GB.

That's ~25.5 GB (23.7 GiB) for ingestion and compaction alone. Go's soft memory limit is 80 % of MemTotal, ~25
GiB on the `r7i.xlarge` (MemTotal is a little under its 32 GiB), and the cgroup's hard limit is at 92 %. That
leaves about 1 GiB for queries, which the guards allow up to 2 GiB each, 4 at a time, and none of Grafana's
50 % headroom. So the caps hold at the expected load; at the caps with dashboards querying they're untested.
A synthetic load (e.g. `avalanche`) would confirm them before anyone relies on them.

**CPU** is the compromise. The same guidance asks for 1 core per 25k samples/s and 1 per 300k series, about 12
cores at the caps, against the `r7i.xlarge`'s 4 vCPU (2 physical cores). By that guidance this box sustains
roughly 25–50k samples/s, not the 120k cap: bursts above that are absorbed but sustained ingest at the cap
isn't rated, and nothing has been load tested. At the expected load (a few thousand samples/s) that's plenty.
The `cpu` alarm (85 % for 15 minutes) says when it isn't. For sustained ingest near the caps, take the
`r7g.xlarge` (4 physical cores) or a 2xlarge. The options:

| instance | vCPU (cores) | memory | $/month | note |
|---|---|---|---|---|
| `m7i.xlarge` | 4 (2) | 16 GiB | ~147 | enough for the expected load, but only with the caps cut to ~0.75M series / 75k samples/s |
| `r7i.xlarge` | 4 (2) | 32 GiB | ~193 | the caps above |
| `r7g.xlarge` (default) | 4 (4) | 32 GiB | ~156 | Graviton: same memory, twice the cores, cheaper; needs an arm64 `instance_ami` ("Graviton" below) |
| `m7i.2xlarge` | 8 (4) | 32 GiB | ~294 | more CPU, same caps |
| `r7i.2xlarge` | 8 (4) | 64 GiB | ~386 | for ~5M series (raise `max_series_total`) |

**The data disk** (150 GiB gp3; WAL writes and compactions fit gp3's baseline 125 MB/s and 3000 IOPS), at the
caps:
- the ingester's WAL, head and last 13 h of blocks: 5 GB per 300k series, ~33 GB;
- compaction scratch: a 24 h block of the busiest tenant plus its sources, up to ~30 GB;
- the store-gateway's index headers: Grafana's 13 GB per 1M active series, taken here as a year's worth (it
  gives no time basis), more with churn, kept forever.

At the caps that's ~90 GB in the first year, growing ~25 GB a year. At the expected load it's under 10 GB. The
`disk-data` alarm fires at 80 %, and the disk grows in place (runbook).

## Cost

List prices, us-east-1, per month: EC2 `r7g.xlarge` ~$156 (`r7i.xlarge` ~$193), EBS (40 + 150 GiB gp3) ~$15, public IPv4 ~$4,
CloudWatch ~$8 (13 alarms, ~13 custom metrics, one watchdog call a minute, logs; successful pushes and per-query
evaluation lines aren't shipped), S3 requests ~$1–3. That's ~$220.

S3 storage grows with what's kept, at roughly 1.5–2.5 bytes a sample (more with high churn):
- at ~2k samples/s (two concurrent runs), ~0.3 GB a day, cents per month;
- at a sustained 20k samples/s, ~3 GB a day, ~$2 a month more for each month kept (~$25/month after a year),
  plus ~180 GB of compaction sources kept 30 days as old versions (~$4/month).

`r7g.xlarge` saves ~$37; `m7i.xlarge` saves ~$46 with lower caps.

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
tail -20 /var/log/perf-mimir-ops.log            # credential and limit reloads, what was dropped and why
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
until curl -s localhost:19009/ready >/dev/null; do sleep 1; done
curl -s -H 'X-Scope-OrgID: ultra' 'localhost:19009/prometheus/api/v1/label/__name__/values' | jq .
kill %1   # when done
```
A local Grafana works the same way: a Prometheus datasource with URL `http://localhost:19009/prometheus` and a
custom header `X-Scope-OrgID: ultra`. The forward listens on loopback only: from a Grafana in Docker, use
`http://host.docker.internal:19009/prometheus` on Docker Desktop, or run it with `--network host` on Linux.

### Grafana datasource (one per tenant; neptune-dev's for `ultra`)

One Prometheus datasource per tenant, with that tenant's read credential. The tenant header is nginx's job, not
the datasource's. Provisioning, for `ultra`:
```yaml
apiVersion: 1
datasources:
  - name: Perf metrics (ultra)
    uid: perf-mimir-ultra
    type: prometheus
    access: proxy
    url: https://metrics.cto.redislabs.com/prometheus
    basicAuth: true
    basicAuthUser: $PERF_MIMIR_ULTRA_READ_USER     # ultra-read-1
    secureJsonData:
      basicAuthPassword: $PERF_MIMIR_ULTRA_READ_PASSWORD
    jsonData:
      prometheusType: Mimir                       # Grafana can't ask (status/buildinfo isn't served)
      prometheusVersion: 2.9.1
      httpMethod: POST
      timeInterval: 30s                           # the tenant's slowest scrape interval ($__rate_interval needs it)
      timeout: 130
      disableRecordingRules: true                 # else every query editor load asks /api/v1/rules (403)
      manageAlerts: false                         # else the alert list asks this datasource for rules (403)
    editable: false
```
The password reaches Grafana from a secret in the Grafana deployment's environment, never from a repository. Grafana's requests must leave from an address in `read_allowed_cidrs`. Alerting rules, recording
rules and `status/*` aren't served (the two switches above keep Grafana from asking). Exemplars aren't either,
and Grafana detects that by itself.

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

### Graviton (r7g)

Set `instance_type = "r7g.xlarge"` and `instance_ami` to the arm64 Ubuntu 26.04 AMI:
`aws ssm get-parameter --name /aws/service/canonical/ubuntu/server/26.04/stable/current/arm64/hvm/ebs-gp3/ami-id
--query Parameter.Value --output text`. Then follow the planned replacement. The bootstrap picks the arm64 Mimir
binary (`mimir_sha256["arm64"]`), AWS CLI and CloudWatch agent by itself. The data volume carries over (ext4,
and Mimir's files don't depend on the architecture).

### Instance lost

- Host failure: the `system-status` alarm recovers it (same ID, IP, volume); `instance-status` reboots it.
- Terminated: the volume is intact; `terraform apply` creates a new instance and attaches it.

### Data volume lost

Every block shipped to S3 is safe. What's lost is the samples not yet shipped, up to the last 2–3 h (the head
cuts a block once it spans 3 h). Until the blocks shipped in the last 12 h age past 12 h, queries don't see them:
Mimir queries the ingester, not S3, for that window. Drop the volume from the state and apply: a new, blank
volume is formatted, Mimir starts on it, and the certificate is issued again.
```bash
terraform state rm aws_ebs_volume.data
terraform state rm aws_volume_attachment.data   # only if the old volume no longer exists (detaching it would fail)
terraform plan -out new.tfplan     # a new volume; instance, attachment, EIP association replaced
terraform apply new.tfplan
```
If the old volume still exists, it's now outside Terraform (no `prevent_destroy`) and still billed: snapshot it
if in doubt, then delete it. `Ready`, `certificate-days-left` and `disk-data` alarm during the swap.

A boot that died in the middle of `mkfs` can leave a volume with no filesystem that isn't blank either; the
bootstrap then refuses to format it (`not formatting it` in `/var/log/server-init.log`). It holds nothing:
`wipefs -a <device>` on it, then re-run the bootstrap.

### Block uploads failing or compactor stale

The data volume has no snapshots because S3 has every shipped block; the `block-upload-failures` and
`compactor-stale` alarms say when that stops being true. Look for `shipper` or `compactor` errors in
`/var/log/mimir/mimir.log`. The usual causes are the instance role or the bucket policy (an `AccessDenied`) and
a full disk. Until it's fixed, unshipped blocks pile up on the one volume: if it'll take long, take a manual
snapshot (`aws ec2 create-snapshot --volume-id "$VOL"`).

### Undelete blocks (purge by mistake)

The bucket keeps deleted objects as old versions for 30 days. This is for a purge (a wrong `retention_period`,
a manual delete), not for compaction, whose sources are already in the compacted blocks. Fix the cause first
(e.g. the retention), then, with Mimir held (`touch /data/.hold; systemctl stop mimir`) and an admin role (the
server's can't touch versions):
```bash
TM=<UTC time just before the purge, e.g. 2026-10-06T09:00:00>; PFX=blocks/<tenant>/
aws s3api list-object-versions --bucket "$B" --prefix "$PFX" --output json \
  | jq -r --arg t "$TM" '.DeleteMarkers[]? | select(.IsLatest and .LastModified >= $t) | [.Key,.VersionId] | @tsv' > markers.tsv
while IFS=$'\t' read -r k v; do aws s3api delete-object --bucket "$B" --key "$k" --version-id "$v" >/dev/null </dev/null; done < markers.tsv
# The compactor's deletion marks written since then would delete those blocks again:
aws s3api list-objects-v2 --bucket "$B" --prefix "$PFX" --output json \
  | jq -r --arg t "$TM" '.Contents[]? | select((.Key | endswith("deletion-mark.json")) and .LastModified >= $t) | .Key' \
  | while read -r k; do aws s3 rm "s3://$B/$k" </dev/null; done
```
Then `rm /data/.hold && systemctl start mimir`; the compactor rebuilds the tenant's bucket index within the hour.

### Mimir upgrade

Read the release notes (config changes and deprecations), then set `mimir_version` and both `mimir_sha256`
entries in a PR. The checksums are the release's `mimir-linux-amd64-sha-256` and `mimir-linux-arm64-sha-256`
assets; check them against the binaries. Then follow the planned replacement. A rollback is the same with the
old values. Mimir's blocks are Prometheus TSDB blocks, so that normally works, but check the release notes for
format or WAL changes first.

### Grow the data disk

Raise `data_volume_size_gb` and apply (in place). Wait until
`aws ec2 describe-volumes-modifications --volume-ids "$VOL" --query 'VolumesModifications[0].ModificationState'`
says `optimizing` or `completed`. Then run `resize2fs "$(findmnt -n -o SOURCE /data)"` on the instance (the
bootstrap also does it on the next replacement).

### Certificates

Renewed by `certbot.timer` (webroot, nginx reload hook); stored on `/data`, so a replacement doesn't re-issue.
`CertDaysLeft` alarms under 14 days (and reads 0 until the A record exists).

### Decommission

In a reviewed PR remove the `prevent_destroy`s and `disable_api_termination`, decide whether the bucket is kept;
`terraform destroy` (the data volume leaves a final snapshot: tag it `team`/`owner` by hand); delete the DNS records and the
`htpasswd/{push,read}` parameters (written by hand, so Terraform doesn't).
