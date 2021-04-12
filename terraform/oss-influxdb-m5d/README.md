# oss-influxdb-m5d -- InfluxDB v1.8.4

Deploy Multi-VM benchmark scenario, including 1 client and 1 DB machine.
- Cloud provider: AWS
- OS: Ubuntu 20.04
- Client machine: m5d.8xlarge
- Benchmark machine: m5d.8xlarge. InfluxDB v1.8.4

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
cd terraform/oss-influxdb-m5d
terraform plan
terraform apply
ansible-playbook --private-key <pem> -u ubuntu -i <output of server_public_ip>, ../deps/automata/ansible/influxdb.yml -K
```

Extra settings: 
- cache-max-memory-size = "50g"
- max-values-per-tag = 0
- max-series-per-database 100000000
  

### Benchmark steps

Within the benchmark machine
#### Install tsbs
```
git clone https://github.com/RedisTimeSeries/tsbs.git --branch redistimeseries-v1.4
cd tsbs
make
```

#### benchmark reads scale 100
```
FORMATS="influx" SCALE=100 ./scripts/generate_data.sh
FORMATS="influx" SCALE=100 TS_END="2016-01-04T00:00:00Z" ./scripts/generate_queries.sh
DATABASE_HOST=<output of server_public_ip> FORMAT=influx SCALE=100 ./scripts/load/load_influx.sh
DATABASE_HOST=<output of server_public_ip> FORMAT=influx SCALE=100 ./scripts/run/run_queries_influx.sh
```

#### benchmark reads scale 4000
```
FORMATS="influx" SCALE=4000 ./scripts/generate_data.sh
FORMATS="influx" SCALE=4000 TS_END="2016-01-04T00:00:00Z" ./scripts/generate_queries.sh
DATABASE_HOST=<output of server_public_ip> FORMAT=influx SCALE=4000 ./scripts/load/load_influx.sh
DATABASE_HOST=<output of server_public_ip> FORMAT=influx SCALE=4000 ./scripts/run/run_queries_influx.sh
```



### Ingestion benchmarks

#### 100 devices x 10 metrics	31 days
```
FORMATS="influx" SCALE=100 TS_END="2016-02-01T00:00:00Z" ./scripts/generate_data.sh
DATABASE_HOST=<output of server_public_ip> FORMAT=influx SCALE=100 ./scripts/load/load_timescale.sh
```

#### 4000 devices x 10 metrics (1382400000 metrics)	4 days
```
FORMATS="influx" SCALE=4000 TS_END="2016-01-05T00:00:00Z" ./scripts/generate_data.sh
DATABASE_HOST=<output of server_public_ip> FORMAT=influx SCALE=100 ./scripts/load/load_timescale.sh
```


#### 100K devices  x 10 metrics	3 hours
```
FORMATS="influx" SCALE=100000 TS_END="2016-01-01T03:00:00Z" ./scripts/generate_data.sh
DATABASE_HOST=<output of server_public_ip> FORMAT=influx SCALE=100000 ./scripts/load/load_timescale.sh
```

#### 1M devices  x 10 metrics	3 minutes
```
FORMATS="influx" SCALE=1000000 TS_END="2016-01-01T00:03:00Z" ./scripts/generate_data.sh
DATABASE_HOST=<output of server_public_ip> FORMAT=influx SCALE=1000000 ./scripts/load/load_timescale.sh
```

#### 10M devices  x 10 metrics	3 minutes
```
FORMATS="influx" SCALE=10000000 TS_END="2016-01-01T00:03:00Z" ./scripts/generate_data.sh
DATABASE_HOST=<output of server_public_ip> FORMAT=influx SCALE=10000000 ./scripts/load/load_timescale.sh
```
