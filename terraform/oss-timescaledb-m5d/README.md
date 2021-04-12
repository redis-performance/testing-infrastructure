# oss-timescaledb-m5d

Deploy Multi-VM benchmark scenario, including 1 client and 1 DB machine.
- Cloud provider: AWS
- OS: Ubuntu 20.04
- Client machine: m5d.8xlarge
- Benchmark machine: m5d.8xlarge. 

-------

#### Deployment

##### Required env variables

The terraform and ansible scripts expect the following env variables to be filled:
```
export EC2_REGION={ ## INSERT REGION ## }
export EC2_ACCESS_KEY={ ## INSERT EC2 ACCESS KEY ## }
export EC2_SECRET_KEY={ ## INSERT EC2 SECRET KEY ## }
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
```

##### Required private key

The terraform script expects the following private key to be present on:
```
/tmp/benchmarks.redislabs.pem
```

##### Deployment steps
within project repo

```bash
cd terraform/oss-timescale-m5d
terraform plan
terraform apply
ansible-playbook --private-key <pem> -u ubuntu -i <output of server_public_ip>, ../deps/automata/ansible/influxdb.yml -K
```

### Benchmark steps

Within the benchmark machine
#### Install tsbs
```
sudo apt install postgresql-client-common
sudo apt install postgresql-client
git clone https://github.com/RedisTimeSeries/tsbs.git --branch redistimeseries-v1.4
cd tsbs
make
```

#### benchmark reads scale 100
```
FORMATS="timescaled" SCALE=100 ./scripts/generate_data.sh
FORMATS="timescaled" SCALE=100 TS_END="2016-01-04T00:00:00Z" ./scripts/generate_queries.sh
DATABASE_HOST=<output of server_public_ip> FORMAT=timescaled SCALE=100 ./scripts/load/load_timescale.sh
DATABASE_HOST=<output of server_public_ip> FORMAT=timescaled SCALE=100 ./scripts/run/run_queries_timescale.sh
```

#### benchmark reads scale 4000
```
TBD
```

### Ingestion benchmarks

#### 100 devices x 10 metrics	31 days
```
FORMATS="timescaledb" SCALE=100 TS_END="2016-02-01T00:00:00Z" ./scripts/generate_data.sh
DATABASE_HOST=<output of server_public_ip> FORMAT=timescaledb SCALE=100 ./scripts/load/load_timescale.sh
```

#### 4000 devices x 10 metrics (1382400000 metrics)	4 days
```
FORMATS="timescaledb" SCALE=4000 TS_END="2016-01-05T00:00:00Z" ./scripts/generate_data.sh
DATABASE_HOST=<output of server_public_ip> FORMAT=timescaledb SCALE=100 ./scripts/load/load_timescale.sh
```


#### 100K devices  x 10 metrics	3 hours
```
FORMATS="timescaledb" SCALE=100000 TS_END="2016-01-01T03:00:00Z" ./scripts/generate_data.sh
DATABASE_HOST=<output of server_public_ip> FORMAT=timescaledb SCALE=100000 ./scripts/load/load_timescale.sh
```

#### 1M devices  x 10 metrics	3 minutes
```
FORMATS="timescaledb" SCALE=1000000 TS_END="2016-01-01T00:03:00Z" ./scripts/generate_data.sh
DATABASE_HOST=<output of server_public_ip> FORMAT=timescaledb SCALE=1000000 ./scripts/load/load_timescale.sh
```

#### 10M devices  x 10 metrics	3 minutes
```
FORMATS="timescaledb" SCALE=10000000 TS_END="2016-01-01T00:03:00Z" ./scripts/generate_data.sh
DATABASE_HOST=<output of server_public_ip> FORMAT=timescaledb SCALE=10000000 ./scripts/load/load_timescale.sh
```
