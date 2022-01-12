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
cd terraform/oss-3nodes-mongodb-m5d
terraform plan
terraform apply
terraform output -json server_public_ip

# use the outputed 3 external addresses
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook --private-key /tmp/benchmarks.redislabs.pem -u ubuntu -i 18.222.166.132,18.117.158.156,3.17.183.206, ./../deps/automata/ansible/mongodb.yml  -K


terraform output -json server_private_ip

# use the outputed 3 internal addresses
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook --private-key /tmp/benchmarks.redislabs.pem -u ubuntu -i 3.137.178.136,  ../deps/automata/ansible/mongodb.yml -e mongo_cluster_host=1 -e "{"mongodb_nodes":['10.3.0.15,10.3.0.80,10.3.0.124']}" -K

```

### Benchmark steps

Within the benchmark machine

#### Install tsbs
```
sudo apt update
sudo apt install default-jdk maven python -y
java --version

git clone http://github.com/RediSearch/YCSB.git
cd YCSB
git checkout commerce-workload
mvn -pl site.ycsb:redisjson2-binding -am clean package

```


### 5. Load data and run the tests

```
./bin/ycsb load mongodb -s -P workloads/workloadecommerce -p mongodb://10.3.0.15,10.3.0.80,10.3.0.124/?replicaSet=rdReplSet&readPreference=secondary&w=0 -p "threadcount=64" -p "recordcount=1000000" -p "operationcount=1000000" > outputLoad.txt
./bin/ycsb run redisearch -s -P workloads/workloade -p mongodb.url=mongodb://localhost:27017/ycsb?w=0 -p "threadcount=32" -p "recordcount=30000000" -p "operationcount=30000000" > outputRunE.txt
```
