# oss-standalone-redistimeseries-m5

Deploy Multi-VM benchmark scenario, including 1 client and 1 DB machine.
- Cloud provider: AWS
- OS: Ubuntu 18.04
- Client machine: c5.2xlarge
- Benchmark machine: m5.8xlarge

-------

#### Tested scenarios

- TBD

#### Deployment

##### Required env variables

The terraform and ansible scripts expect the following env variables to be filled:
```
export EC2_REGION={ ## INSERT REGION ## }
export EC2_ACCESS_KEY={ ## INSERT EC2 ACCESS KEY ## }
export EC2_SECRET_KEY={ ## INSERT EC2 SECRET KEY ## }
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
```

##### Required pub/private keys

The terraform script expects the following public private keys to be present on ~/.ssh/ dir:
```
~/.ssh/perf-cto-joint-tasks.pem
~/.ssh/perf-cto-joint-tasks.pub
```

##### Deployment steps
within project repo

```bash
cd terraform/oss-standalone-redistimeseries-m5
terraform plan
terraform apply
```




### Benchmark steps

Within the benchmark machine
#### Install tsbs
```
sudo snap install go --classic
git clone https://github.com/RedisTimeSeries/tsbs.git --branch redistimeseries-v1.4
cd tsbs
make
```

#### benchmark reads scale 100
```
SCALE=100 ./scripts/generate_data_redistimeseries.sh
SCALE=100 ./scripts/generate_queries_redistimeseries.sh
DATABASE_HOST=10.3.0.171 SCALE=100 DATABASE_PORT=30001 CLUSTER_FLAG="--cluster" ./scripts/load/load_redistimeseries.sh
DATABASE_HOST=10.3.0.171 DATABASE_PORT=30001 CLUSTER_FLAG="--cluster" SCALE=100 DATABASE_PORT=30001 REPETITIONS=1 MAX_QUERIES=1000 CLUSTER_FLAG="--cluster" ./scripts/run_queries/run_queries_redistimeseries_rate_limited_redistimeseries.sh
```

#### benchmark reads scale 4000
```
TBD
```


### Ingestion benchmarks

#### 100 devices x 10 metrics	31 days
```
FORMATS="redistimeseries" SCALE=100 TS_END="2016-02-01T00:00:00Z" ./scripts/generate_data.sh
 DATABASE_HOST=10.3.0.171  DATABASE_PORT=30001 CLUSTER_FLAG="--cluster" FORMAT=redistimeseries SCALE=100  TS_END="2016-02-01T00:00:00Z" CONNECTIONS=32 PIPELINE=15 ./scripts/load/load_redistimeseries.sh
```

#### 4000 devices x 10 metrics (1382400000 metrics)	4 days
```
FORMATS="redistimeseries" SCALE=4000 TS_END="2016-01-05T00:00:00Z" ./scripts/generate_data.sh
DATABASE_HOST=10.3.0.171 DATABASE_PORT=30001 CLUSTER_FLAG="--cluster" FORMAT=redistimeseries SCALE=100 ./scripts/load/load_redistimeseries.sh
```


#### 100K devices  x 10 metrics	3 hours
```
FORMATS="redistimeseries" SCALE=100000 TS_END="2016-01-01T03:00:00Z" ./scripts/generate_data.sh
DATABASE_HOST=10.3.0.171 DATABASE_PORT=30001 CLUSTER_FLAG="--cluster" FORMAT=redistimeseries SCALE=100000 ./scripts/load/load_redistimeseries.sh
```

#### 1M devices  x 10 metrics	3 minutes
```
FORMATS="redistimeseries" SCALE=1000000 TS_END="2016-01-01T00:03:00Z" ./scripts/generate_data.sh
DATABASE_HOST=10.3.0.171 DATABASE_PORT=30001 CLUSTER_FLAG="--cluster" FORMAT=redistimeseries SCALE=1000000 ./scripts/load/load_redistimeseries.sh
```

#### 10M devices  x 10 metrics	3 minutes
```
FORMATS="redistimeseries" SCALE=10000000 TS_END="2016-01-01T00:03:00Z" ./scripts/generate_data.sh
DATABASE_HOST=10.3.0.171 DATABASE_PORT=30001 CLUSTER_FLAG="--cluster" FORMAT=redistimeseries SCALE=10000000 ./scripts/load/load_redistimeseries.sh
```
