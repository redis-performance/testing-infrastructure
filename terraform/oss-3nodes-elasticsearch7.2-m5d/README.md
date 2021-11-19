# oss-elasticsearch7-m5d

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
cd terraform/oss-3nodes-elasticsearch-m5d
terraform plan
terraform apply

ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook --private-key /tmp/benchmarks.redislabs.pem -u ubuntu -i 3.12.36.37,3.144.27.172,3.141.28.145, -e "elasticsearch_nodes=[10.3.0.75,10.3.0.47,10.3.0.11]" ../deps/automata/ansible/elasticsearch.yml
```

```
sudo mdadm --create --verbose /dev/md0 --level=0 --raid-devices=2 /dev/nvme1n1 /dev/nvme2n1
sudo mkfs.ext4 -F /dev/md0
sudo mkdir -p /mnt/elastic
sudo mount /dev/md0 /mnt/elastic/
sudo mdadm --detail --scan | sudo tee -a /etc/mdadm/mdadm.conf

# at the end you should have
lsblk
NAME        MAJ:MIN RM   SIZE RO TYPE  MOUNTPOINT
nvme1n1     259:0    0 558.8G  0 disk  
└─md0         9:0    0   1.1T  0 raid0 /mnt/elastic
nvme2n1     259:1    0 558.8G  0 disk  
└─md0         9:0    0   1.1T  0 raid0 /mnt/elastic
nvme0n1     259:2    0     1T  0 disk  
└─nvme0n1p1 259:3    0  1024G  0 part  /

```

At the end you should have a similar reply to:
```
curl -X GET "localhost:9200/_cluster/health?pretty"
{
  "cluster_name" : "my-cluster",
  "status" : "green",
  "timed_out" : false,
  "number_of_nodes" : 3,
  "number_of_data_nodes" : 3,
  "active_primary_shards" : 15,
  "active_shards" : 15,
  "relocating_shards" : 0,
  "initializing_shards" : 0,
  "unassigned_shards" : 0,
  "delayed_unassigned_shards" : 0,
  "number_of_pending_tasks" : 0,
  "number_of_in_flight_fetch" : 0,
  "task_max_waiting_in_queue_millis" : 0,
  "active_shards_percent_as_number" : 100.0
}
```

and
```
curl -X GET "localhost:9200"
{
  "name" : "redes-1030236",
  "cluster_name" : "my-cluster",
  "cluster_uuid" : "8_mJxBOcQbazaqbuHa1cZg",
  "version" : {
    "number" : "7.15.0",
    "build_flavor" : "default",
    "build_type" : "deb",
    "build_hash" : "79d65f6e357953a5b3cbcc5e2c7c21073d89aa29",
    "build_date" : "2021-09-16T03:05:29.143308416Z",
    "build_snapshot" : false,
    "lucene_version" : "8.9.0",
    "minimum_wire_compatibility_version" : "6.8.0",
    "minimum_index_compatibility_version" : "6.0.0-beta1"
  },
  "tagline" : "You Know, for Search"
}
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
mvn -pl site.ycsb:elasticsearch7-binding -am clean package

```


### 5. Load data and run the tests

```
# create the index

./bin/ycsb load elasticsearch7-rest -P workloads/workload-ecommerce -p "es.number_of_shards=15" -p "es.hosts.list=10.3.0.75:9200" -p "orderedinserts=true" -p "threadcount=1" -p "recordcount=1"

# load the data
./bin/ycsb load elasticsearch7-rest -P workloads/workload-ecommerce -p "es.number_of_shards=15" -p "es.hosts.list=10.3.0.75:9200" -p "operationcount=1000000" -p "threadcount=64" -p "recordcount=1000000"
 

# enable index updates
curl -X PUT "localhost:9200/es.ycsb/_settings?pretty" -H 'Content-Type: application/json' -d'
{
  "index" : {
    "refresh_interval" : "1s"
  }                                                                   
}                                                                        
'


```

## test 

```
curl -X GET "localhost:9200/es.ycsb/_search?pretty" -H 'Content-Type: application/json' -d'
{
  "query": {
    "term": {
      "productName": "paper"       
    }
  }, "sort": [ {"productScore":{}} ],"size": 2
}
'
```