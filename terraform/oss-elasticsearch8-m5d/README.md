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
cd terraform/oss-elasticsearch8-m5d
terraform plan
terraform apply
ansible-playbook --private-key <pem> -u ubuntu -i <output of server_public_ip>, ../deps/automata/ansible/elasticsearch.yml -K
```


witin the DB vm
```bash
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

Get the dataset 

```bash

wget -c https://github.com/RediSearch/RediSearchBenchmark/releases/latest/download/document-benchmark-$(uname -mrs | awk '{ print tolower($1) }')-$(dpkg --print-architecture).tar.gz -O - | tar -xz

wget https://s3.amazonaws.com/benchmarks.redislabs/redisearch/datasets/enwiki-abstract/enwiki-latest-abstract.xml

```

```
.document-benchmark -hosts "https://10.3.0.225:9200" -engine elastic -file enwiki-latest-abstract.xml -maxdocs 100000 -c 1 
```