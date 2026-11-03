# re-2nodes-flex-mkt-2pct-i7i.metal-48xl

Two-node Redis Enterprise Flex (Redis on Flash v2) cluster with 2% of the dataset in RAM, plus two
memtier_benchmark clients. This is the setup behind the 2-node Flex value-size sweep (4 KB to 64 KB,
read / 80-20 mixed / write) on i7i.metal-48xl.

- Cloud provider: AWS, `us-east-1a`, one cluster placement group for the servers
- Servers: 2x `i7i.metal-48xl` (2 sockets x 96 cores, 12x 3.4 TB NVMe), Ubuntu 22.04
- Clients: 2x `i7i.metal-48xl`, memtier_benchmark built from source with TLS
- Redis Enterprise `100.0.21-40429`, Redis 8.4

## What `terraform apply` does

1. Servers: install Redis Enterprise, run RS `prepare_flash.sh`, then `setup_xfs.sh` rebuilds the flash
   array as RAID-0 (256K chunks) with XFS, keeping 20% of the array unformatted as overprovisioning.
2. `rladmin cluster create` / `cluster join` with flash enabled, then
   `rladmin tune proxy all threads <proxy_threads> max_threads <proxy_threads>`.
3. Speedb tuning appended to `redis-base-8.4-big2.conf` before the DB exists:
   `maincf-level0_file_num_compaction_trigger 16`, `level0_slowdown_writes_trigger 24`,
   `level0_stop_writes_trigger 60`, `write_buffer_size 1GB`.
4. One database through `POST /v1/bdbs`: 60 primaries with replication (sparse placement), 50 TiB
   `memory_size`, 1 TiB `bigstore_ram_size` (2%), TLS without client auth, OSS Cluster API,
   persistence disabled, `proxy_policy all-master-shards`.
5. `numa_pinning.sh` on each server: half of the shards per socket (with `migratepages`), dmcproxy
   workers 0-15 on socket 0 and 16-31 on socket 1, NIC IRQs split across both sockets. With
   `proxy_threads=40`, workers 32-39 fall to the default branch (socket 0).
6. Clients: memtier_benchmark and the three benchmark scripts copied to `/home/ubuntu`.

## Deployment

```bash
cd terraform/re-2nodes-flex-mkt-2pct-i7i.metal-48xl
terraform init
terraform plan  -var rs_username=<admin email> -var rs_password=<password> -var license_file=<path to license>
terraform apply -var rs_username=<admin email> -var rs_password=<password> -var license_file=<path to license>
```

The license is copied to node 1 at apply time and is never committed. Override `github_actor` with
your own name so the `owner` tag identifies you.

`proxy_threads` defaults to 32 (used for 4 KB). The 8 KB to 64 KB runs used 40:
`-var proxy_threads=40`.

## Benchmark steps

On each client (half 0 and half 1 split the key range; client 0 also flushes the DB between sizes):

```bash
export RS_USER=<admin email> RS_PASS=<password>   # client 0 only
./benchmark-all.sh <db_endpoint> 0                 # client 0
./benchmark-all.sh <db_endpoint> 1                 # client 1
```

`db_endpoint` is a terraform output. For each value size the orchestrator fills 5 TiB
(`--key-pattern=P:P -n allkeys`, pipeline 10), then runs read (0:1), mixed (1:4) and write (1:0) for
600 s at max throughput, then at 80% and 50% of that max through `--rate-limiting`. Every run uses
16 threads x 20 clients, `--cluster-mode --tls --tls-skip-verify`.

## CPU metrics

The DMC / shard CPU columns of the original report were read from a Prometheus server at
`localhost:9090` scraping the cluster's metrics endpoint (`:8070`). This module does not deploy that
Prometheus; run one (or tunnel to an existing one) if you need those columns.
