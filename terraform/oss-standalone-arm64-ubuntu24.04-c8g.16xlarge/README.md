# oss-redis-standalone-arm64-ubuntu24.04-c8g.16xlarge

Deploy Multi-VM benchmark sceneario, including 2 clients and 1 DB machine.

- Cloud provider: AWS
- OS: Ubuntu 24.04
- Client machine: c8g.16xlarge
- Benchmark machine: c8g.16xlarge

---

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
~/.ssh/perf-ci.pem
~/.ssh/perf-ci.pub
```

##### Deployment steps

within project repo

```bash
cd terraform/oss-standalone-arm64-ubuntu24.04-c8g.16xlarge
terraform plan
terraform apply
```
