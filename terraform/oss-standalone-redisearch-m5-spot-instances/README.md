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
ansible-playbook --private-key <pem> -u ubuntu -i <output of server_public_ip>, ../deps/automata/ansible/mongodb.yml -K
```

### Benchmark steps

Within the benchmark machine

#### Install tsbs
```
sudo apt update
sudo apt install default-jdk maven -y

git clone http://github.com/RediSearch/YCSB.git
cd YCSB
mvn -pl site.ycsb:mongodb-binding -am clean package

```
