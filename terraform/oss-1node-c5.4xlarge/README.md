# oss-standalone-redisbloom-m5

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
cd terraform/oss-standalone-redisbloom-m5
terraform plan
terraform apply
```
