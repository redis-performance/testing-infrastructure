# ultra-pyroscope-us-east-1

A long-lived [Grafana Pyroscope](https://grafana.com/oss/pyroscope/) v2 server for continuous profiling of
the Redis Ultra (Shaka) perf benchmarks: the Neptune perf-lane cells push per-thread eBPF profiles while a
benchmark runs, and the neptune-dev Grafana reads them. Benchmarks account (726902207197), us-east-1.

| piece | what |
|---|---|
| EC2 `m7i.xlarge`, Ubuntu 26.04 | Pyroscope 2.3.1 (single binary, docker, host network, every port on 127.0.0.1) behind nginx (nginx.org stable) |
| `https://pyroscope.cto.redislabs.com` | the only way in: push (`/push.v1.PusherService/Push`, `/ingest`) with push credentials; read (the querier API) with read credentials and only from `read_allowed_cidrs` (the Grafana NAT). Everything else is 403. |
| S3 `ultra-pyroscope-us-east-1-<account>` | the profiles (`data/`, kept forever: `retention_period = 0`) and raft snapshot copies (`backups/`) |
| EBS `…-metastore` (20 GiB, `/data`) | the v2 metastore (raft log, snapshots, index) and the TLS certificates. **Pyroscope v2 can't rebuild its index from S3**: this volume is protected (`prevent_destroy`), snapshotted hourly by DLM (30 days) and survives instance replacement. |
| CloudWatch | logs `/ultra-pyroscope-us-east-1/{pyroscope,nginx,system}`; alarms → SNS `…-alarms` (status checks with recover/reboot, disk, memory, `Ready`, certificate days left, discarded samples) |

About $160/month at list prices, almost all of it the instance.

## Apply

```bash
cd terraform/ultra-pyroscope-us-east-1
AWS_PROFILE=bench terraform init
AWS_PROFILE=bench terraform plan -var alarm_email=<you>@redis.com -out p.tfplan
AWS_PROFILE=bench terraform apply p.tfplan
```

Without `alarm_email` the alarms notify nobody (confirm the SNS subscription email). `github_actor` defaults to
the owner's tag value because nothing passes it on a manual apply.

## Out of band, once

1. **DNS:** an A record `pyroscope.cto.redislabs.com` → `terraform output -raw public_ip` in the
   `cto.redislabs.com` zone (CTO account). The server gets its Let's Encrypt certificate within 10 minutes of
   the name resolving to it (it doesn't try before: failed validations are rate limited), then enables 443.
   Recommended: a CAA record limiting issuance to Let's Encrypt.
2. **Credentials:** two users per role (`push-1`/`push-2`, `read-1`/`read-2`, so rotation can overlap), as
   SHA-512 crypt htpasswd lines in SSM SecureString parameters. The server reloads them every 5 minutes; it
   accepts nothing but `<role>-1|2:$6$…` lines, keeps the current file on SSM errors, and empties it when the
   parameter is deleted (revocation).
   ```bash
   P=$(openssl rand -base64 32)        # keep it in the password manager; it's what clients send
   aws ssm put-parameter --profile bench --region us-east-1 --type SecureString \
     --name /ultra-pyroscope-us-east-1/htpasswd/push --value "push-1:$(openssl passwd -6 "$P")"
   ```
   Same for `/ultra-pyroscope-us-east-1/htpasswd/read` with `read-1`. Several users: one line each.

## Teardown

`terraform destroy` fails on purpose: the bucket, the volume and the EIP (the DNS record points at it) have
`prevent_destroy`, and the instance has termination protection. See the runbook's "Decommission".

## Runbook

Workstation setup (no SSH; SSM Session Manager):
```bash
export AWS_PROFILE=bench AWS_REGION=us-east-1
IID=$(terraform output -raw instance_id); B=$(terraform output -raw bucket)
VOL=$(terraform state show -no-color aws_ebs_volume.metastore | awk '$1=="id"{gsub(/"/,"",$3);print $3}')
aws ssm start-session --target "$IID"          # then: sudo -i
```

### Health (on the instance)

```bash
HOST=pyroscope.cto.redislabs.com
systemctl is-active pyroscope nginx pyroscope-watchdog.timer pyroscope-backup.timer certbot.timer
findmnt /data && cat /data/.ultra-pyroscope     # ultra-pyroscope-metastore
curl -s 127.0.0.1:4042/ready; echo
curl -s --resolve $HOST:443:127.0.0.1 https://$HOST/healthz
docker logs --since 15m pyroscope 2>&1 | grep -E 'level=(error|warn)|panic' | tail
tail -50 /var/log/server-init.log               # the bootstrap
```
Queries (the public read path only admits the Grafana NAT): tunnel to 4040 and send `X-Scope-OrgID: ultra`:
```bash
aws ssm start-session --target "$IID" --document-name AWS-StartPortForwardingSession \
  --parameters portNumber=4040,localPortNumber=14040 &
curl -s -H 'X-Scope-OrgID: ultra' -H 'Content-Type: application/json' -X POST \
  localhost:14040/querier.v1.QuerierService/LabelNames -d "{\"start\":$(( ($(date +%s)-40*86400)*1000 )),\"end\":$(date +%s)000}"
```

**Switches:** `touch /data/.hold` keeps Pyroscope stopped across restarts and reboots (the watchdog leaves a
stopped unit alone); `rm /data/.hold && systemctl start pyroscope` undoes it.

### Planned replacement (user-data, image, AMI, CIDR change)

1. No perf run in flight. Take a manual snapshot:
   `aws ec2 create-snapshot --volume-id "$VOL" --description "pre-replace $(date -u +%FT%TZ)"`.
2. `terraform plan -out r.tfplan`: expect only `-/+` on the instance, the volume attachment and the EIP
   association, and in-place alarm updates. **Stop if anything touches the volume, the bucket or DLM.**
3. `terraform apply r.tfplan` (6–10 min): the old instance stops (Pyroscope gets 90 s), the volume detaches,
   the instance terminates (`force_destroy` lifts the protection), the new one boots, mounts `/data`, keeps the
   certificate and starts.
4. Health check. If the bootstrap failed (`/var/log/server-init.log`) on a transient download, re-run it:
   `cloud-init single --name scripts_user --frequency always` (idempotent).

### Instance lost

- Host failure: the `system-status` alarm recovers it (same ID, IP, volume); `instance-status` reboots it.
- Terminated: the volume is intact; `terraform apply` creates a new instance and attaches it.

### Metastore volume lost or corrupt: restore from a DLM snapshot (preferred)

RPO ≤ 1 h; profiles pushed after the snapshot stay in S3 but drop out of the index.

1. Freeze: `touch /data/.hold; systemctl stop pyroscope-watchdog.timer pyroscope` (if the instance is alive).
2. Pick a snapshot from before the corruption:
   ```bash
   aws ec2 describe-snapshots --owner-ids self --filters Name=tag:Name,Values=ultra-pyroscope-us-east-1-metastore \
     Name=status,Values=completed --query 'reverse(sort_by(Snapshots,&StartTime))[:5].[SnapshotId,StartTime]' --output text
   SNAP=snap-…; T=<its StartTime>
   ```
3. Undelete what compaction removed after T (the restored index still points at it; the noncurrent versions
   live 45 days). Needs an admin role (the server role can't touch versions):
   ```bash
   TM=$(date -u -d "$T - 1 hour" +%FT%T)
   aws s3api list-object-versions --bucket "$B" --prefix data/ --output json \
     | jq -r --arg t "$TM" '.DeleteMarkers[]? | select(.IsLatest and .LastModified >= $t) | [.Key,.VersionId] | @tsv' > markers.tsv
   while IFS=$'\t' read -r k v; do aws s3api delete-object --bucket "$B" --key "$k" --version-id "$v" >/dev/null; done < markers.tsv
   ```
4. Create the volume and swap it into the state (`prevent_destroy` blocks destroys, not `state rm`):
   ```bash
   NEWVOL=$(aws ec2 create-volume --availability-zone us-east-1a --snapshot-id "$SNAP" --volume-type gp3 \
     --query VolumeId --output text) && aws ec2 wait volume-available --volume-ids "$NEWVOL"
   terraform state rm aws_ebs_volume.metastore
   terraform import aws_ebs_volume.metastore "$NEWVOL"
   terraform plan -out restore.tfplan     # volume tags in place; instance, attachment, EIP association replaced
   terraform apply restore.tfplan
   ```
   The new instance mounts the restored volume (the sentinel names the role, not the volume ID). The restored
   volume loads lazily from its snapshot, so the first start can be slow.
5. Health check, then untag the old volume so DLM stops snapshotting it
   (`aws ec2 delete-tags --resources <OLDVOL> --tags Key=ultra-pyroscope-us-east-1-snapshot`), and record the gap.

A **blank** volume never silently becomes an empty index: if the bucket already holds profiles, the bootstrap
refuses to format it unless `/ultra-pyroscope-us-east-1/allow-empty-metastore` exists in SSM (delete it after).

### Restore from an S3 raft snapshot (only without a usable DLM snapshot)

Raft snapshots only happen every 8192 entries, so this RPO is hours of ingest.

1. Freeze; if the volume is gone, `terraform state rm aws_ebs_volume.metastore`, create the
   `allow-empty-metastore` parameter and `terraform apply`, then `touch /data/.hold; systemctl stop pyroscope`.
2. Pick the newest complete snapshot by its time field (the term sorts first):
   `aws s3 ls "s3://$B/backups/raft-snapshots/" | awk '$1=="PRE"{print $2}' | tr -d / | sort -t- -k3,3n | tail -3`.
3. Stage it:
   ```bash
   mv /data/metastore /data/metastore.pre-import-$(date +%s)
   mkdir -p /data/metastore/raft /data/metastore/data /data/metastore/import/snapshots
   aws s3 cp --recursive "s3://$B/backups/raft-snapshots/$ID/" "/data/metastore/import/snapshots/$ID/"
   chown -R 10001:10001 /data/metastore
   sed -i 's|^    snapshots_dir: /data-metastore/raft$|&\n    snapshots_import_dir: /data-metastore/import|' /etc/pyroscope/config.yaml
   rm /data/.hold; systemctl start pyroscope   # logs: "importing snapshot" id=$ID
   ```
4. **Mandatory, once a new snapshot exists in `/data/metastore/raft/snapshots`:** the imported one keeps its old,
   higher term and would be preferred over every newer one, and a restart some 18k entries later fails with
   `failed to get log`. Remove it:
   ```bash
   systemctl stop pyroscope
   rm -rf "/data/metastore/raft/snapshots/$ID" /data/metastore/import
   sed -i '/snapshots_import_dir/d' /etc/pyroscope/config.yaml
   systemctl start pyroscope && systemctl start pyroscope-watchdog.timer
   ```

### Image upgrade

Resolve the index digest (`docker buildx imagetools inspect grafana/pyroscope:X.Y.Z`), update
`pyroscope_image` in a PR, then follow the planned replacement. The manual snapshot is the rollback point
(raft or bbolt format changes may not go backwards).

### Grow the metastore disk

Raise `metastore_volume_size_gb` and apply (in place), then `resize2fs` on the instance (the bootstrap also
does it on the next replacement).

### Certificates

Renewed by `certbot.timer` (webroot, nginx reload hook); stored on `/data`, so a replacement doesn't
re-issue. `CertDaysLeft` alarms under 14 days (and reads 0 until the A record exists).

### Decommission

Export a final raft snapshot (`/usr/local/sbin/pyroscope-backup`) and an EBS snapshot; in a reviewed PR remove
the `prevent_destroy`s and `disable_api_termination`, decide whether the bucket is kept; `terraform destroy`;
delete the DLM snapshots by tag.
