# Storage-qualification coordinator — amd64 / i7i.metal-24xl

A benchmark runner that carries **both** a physically-attached EC2 instance store
and a **dedicated** EBS data volume, so the same host can serve either storage
condition with nothing but a coordinator restart.

Built for [testing-infrastructure#162](https://github.com/redis-performance/testing-infrastructure/issues/162).
The ARM counterpart is `redis-benchmarks-spec-sc-coordinator-arm64-ubuntu24.04-i8g.metal-24xl-nvme-1`.

## Why this box exists

The full-sync qualification in
[redis/redis-benchmarks-specification#577](https://github.com/redis/redis-benchmarks-specification/pull/577)
saw a median write throughput of 125.048 MiB/s with a 15.4 ms write await and a
weighted average queue depth of 15.4 — a storage-limited profile whose low
coefficient of variation made it *look* repeatable.

That ceiling has since been attributed: the runner's root volume
(`vol-070a9bc8caeb8001a` on `x86-aws-m7i.metal-24xl-2`) is **gp3, 256 GiB, 3000
IOPS, 125 MiB/s provisioned throughput**. The observed median is the provisioned
ceiling, not a coincidence near it.

Two structural causes, both addressed here:

| Cause | Where | Fixed by |
|---|---|---|
| Every fleet runner sits at gp3 provider defaults — the coordinator modules' `root_block_device` never sets `iops` or `throughput` | existing modules | `ebs_data_volume_*` variables, set explicitly and recorded |
| Benchmark data lands on the root volume, which also carries the OS, docker images and build artifacts | `Path.home()` (see below) | dedicated `/mnt/ebs` volume and `/mnt/nvme` instance store; root is never used |

## The two conditions

| Condition | Mount | Platform name | Backend |
|---|---|---|---|
| `nvme` | `/mnt/nvme` | `x86-aws-i7i.metal-24xl-nvme` | EC2 instance store, RAID0 across 6 × 3750 GB |
| `ebs` | `/mnt/ebs` | `x86-aws-i7i.metal-24xl-ebs` | dedicated gp3 volume, IOPS/throughput set in terraform |

Switch between them on the box:

```bash
sudo supervisorctl stop redis-benchmarks-spec-sc-coordinator
sudo benchmark-storage-condition ebs     # or: nvme
sudo supervisorctl start redis-benchmarks-spec-sc-coordinator
sudo benchmark-storage-condition status
```

CPU, binary, affinity, memory, filesystem and configuration are identical across
the switch — only the mount changes. That is what makes the comparison
attributable to storage.

### The platform name changes with the condition, deliberately

Results are namespaced by platform in the timeseries DB. If both conditions
published under one name their series would interleave and the EBS and NVMe
baselines would silently merge — the exact failure #162 says to avoid. Each
condition therefore publishes under its own suffixed platform name, and a
comparison must name the suffix it wants.

## How benchmark data is actually relocated

There is **no `--datadir` flag upstream.** The coordinator does:

```python
home = str(Path.home())                    # self_contained_coordinator.py:836
temporary_dir = tempfile.mkdtemp(dir=home) # :1816
```

and bind-mounts `temporary_dir` into the redis container as its `--dir`. So the
storage path is decided entirely by where `$HOME` resolves. `benchmark-storage-condition`
sets `HOME` (and `TMPDIR`) in the supervisor program block to
`<mount>/coordinator-home`, which moves benchmark data onto the selected mount
with no upstream code change.

This is a workaround, not a fix. The durable version — an explicit `--datadir`,
a backing-device check that fails closed, and storage identity in the result
metadata — belongs in `redis-benchmarks-specification` and is tracked as the
measurement half of #162.

## Why this runner only accepts storage benchmarks

Two independent gates, both verified against the coordinator source:

- **`--explicit-only`** — only stream entries carrying a `target_platform` that
  matches this runner are processed; untargeted broadcast work is skipped
  (`self_contained_coordinator.py:1439`). A fleet-wide trigger cannot pull this
  box in.
- **`--tests-regexp`** — applied once at startup via `extract_testsuites`
  (`:749`) to build the universe of specs the runner will ever consider, which
  is then handed to the per-message filter (`:1518`). A trigger's own regexp can
  narrow that universe but never widen it. Default here is the full-sync /
  persistence family, not the ~490-spec suite.

> **The startup list is built once.** Changing `tests_regexp` requires a
> coordinator restart, and a targeted run whose test does not match is **silently
> skipped** — it looks identical to a run that never happened. Check
> `benchmark-storage-condition status` before concluding work was lost.

## Storage verification and metadata

`prepare_storage.sh` runs from cloud-init before the coordinator is configured:

- Identifies instance-store disks via the `Instance_Storage` marker in
  `/dev/disk/by-id/` — **an NVMe device name proves nothing**, since EBS is also
  exposed as `/dev/nvme*`.
- RAID0s them (chunk 256K), formats ext4, mounts `/mnt/nvme`.
- Formats and mounts the dedicated EBS volume at `/mnt/ebs`.
- **Fails rather than falling back to the root disk** if either is unavailable.
  A run that quietly lands on `/` is worse than no run: it looks like a valid
  datapoint for whichever condition was requested.
- Writes `/etc/benchmark-storage.json` — device identity, model, serial, RAID
  members, filesystem, mount options, scheduler, rotational flag.

The EBS volume's provisioned tier is set in terraform and must be read back to
be recorded with results:

```bash
aws ec2 describe-volumes --region us-east-1 \
  --filters "Name=attachment.instance-id,Values=<instance-id>" \
  --query 'Volumes[].{vol:VolumeId,dev:Attachments[0].Device,type:VolumeType,sizeGiB:Size,iops:Iops,throughputMiBs:Throughput}'
```

## Deployment

```bash
export EC2_REGION=us-east-1
export EVENT_STREAM_HOST=... EVENT_STREAM_PORT=... EVENT_STREAM_USER=... EVENT_STREAM_PASS=...
export DATASINK_RTS_HOST=... DATASINK_RTS_PORT=... DATASINK_RTS_PASS=...

terraform init
terraform validate
terraform plan
terraform apply
```

Then verify before trusting any number from the box:

```bash
ssh -i ~/.ssh/benchmarksredislabsus-east-1.pem ubuntu@<ip>
sudo tail -f /var/log/cloud-init-output.log        # wait for completion
cat /etc/benchmark-storage.json                    # device identity
sudo benchmark-storage-condition status            # active condition
findmnt /mnt/nvme /mnt/ebs
sudo supervisorctl status
```

`coordinator_autostart` defaults to `false`, so the coordinator is configured
but not running after apply. Start it when the box is ready to accept work.

## Qualification protocol

#162's acceptance criteria, in the order they have to be met:

1. Same workload on **both mounts of the same host**, CPU affinity, binary,
   filesystem and configuration held fixed.
2. For the full-sync case: both payloads × both load policies, **≥5 fresh
   repetitions per cell per storage condition**. Retain failures; report
   variability separately.
3. Show whether faster storage reduces waiting. **Local NVMe alone does not
   establish CPU-limited execution** — collect phase-aligned physical I/O bytes,
   throughput, latency, queue depth, I/O pressure and CPU utilization alongside
   elapsed time.
4. Demonstrate sensitivity to a relevant code change **before** using a
   condition as a CPU/serialization regression gate.
5. Keep the EBS and local-NVMe baselines distinct. The existing EBS cohort stays
   unchanged as a deployment-specific result.
