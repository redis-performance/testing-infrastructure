

# oss-k8s-milvus-1node-m6i

```
terraform apply
```


## DB machine
Based on https://milvus.io/docs/install_cluster-helm.md#Install-Milvus-Cluster


```
Install kubectl binary with curl on Linux 
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
chmod +x kubectl
mkdir -p ~/.local/bin/kubectl
mv ./kubectl ~/.local/bin/kubectl
kubectl version --client
```


### install minikube and check kubectl cluster state
```
sudo apt install docker.io -y
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# as ubuntu user
sudo usermod -aG docker $USER && newgrp docker
minikube start
kubectl cluster-info
```

sample output:
```
$ kubectl cluster-info
Kubernetes control plane is running at https://192.168.49.2:8443
CoreDNS is running at https://192.168.49.2:8443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

### install helm

```
sudo snap install helm --classic
```

### add milvus repo to helm
```
helm repo add milvus https://milvus-io.github.io/milvus-helm/
helm repo update
```

### Start Milvus
```
helm install m6i-8xlarge-milvus milvus/milvus
```

### Check the status of the running pods.
```
$ kubectl get pods
NAME                                                      READY   STATUS      RESTARTS       AGE
m6i-8xlarge-milvus-datacoord-557745cbd6-rc88m             1/1     Running     1 (2m8s ago)   6m38s
m6i-8xlarge-milvus-datanode-dd9f7d77f-p4nbw               1/1     Running     1 (2m8s ago)   6m38s
m6i-8xlarge-milvus-etcd-0                                 1/1     Running     0              6m38s
m6i-8xlarge-milvus-etcd-1                                 1/1     Running     0              6m38s
m6i-8xlarge-milvus-etcd-2                                 1/1     Running     0              6m38s
m6i-8xlarge-milvus-indexcoord-79c6d46465-4t9qq            1/1     Running     0              6m38s
m6i-8xlarge-milvus-indexnode-996db9868-hhl46              1/1     Running     0              6m38s
m6i-8xlarge-milvus-minio-0                                1/1     Running     0              6m38s
m6i-8xlarge-milvus-minio-1                                1/1     Running     0              6m38s
m6i-8xlarge-milvus-minio-2                                1/1     Running     0              6m38s
m6i-8xlarge-milvus-minio-3                                1/1     Running     0              6m38s
m6i-8xlarge-milvus-proxy-5c6d78b75f-cfr28                 1/1     Running     1 (2m8s ago)   6m38s
m6i-8xlarge-milvus-pulsar-autorecovery-59f767dfc4-s69nd   1/1     Running     0              6m38s
m6i-8xlarge-milvus-pulsar-bastion-84597c45dd-wlvqv        1/1     Running     0              6m38s
m6i-8xlarge-milvus-pulsar-bookkeeper-0                    1/1     Running     0              6m38s
m6i-8xlarge-milvus-pulsar-bookkeeper-1                    1/1     Running     0              4m36s
m6i-8xlarge-milvus-pulsar-bookkeeper-2                    1/1     Running     0              4m4s
m6i-8xlarge-milvus-pulsar-broker-76496c6988-qcfzf         1/1     Running     0              6m38s
m6i-8xlarge-milvus-pulsar-proxy-56b5c4b57b-n4zgf          2/2     Running     0              6m38s
m6i-8xlarge-milvus-pulsar-zookeeper-0                     1/1     Running     0              6m38s
m6i-8xlarge-milvus-pulsar-zookeeper-1                     1/1     Running     0              5m47s
m6i-8xlarge-milvus-pulsar-zookeeper-2                     1/1     Running     0              5m25s
m6i-8xlarge-milvus-pulsar-zookeeper-metadata-jltj7        0/1     Completed   0              6m38s
m6i-8xlarge-milvus-querycoord-c45f55d8b-l7r45             1/1     Running     1 (2m7s ago)   6m38s
m6i-8xlarge-milvus-querynode-5c8ff9f866-wfffc             1/1     Running     1 (2m8s ago)   6m38s
m6i-8xlarge-milvus-rootcoord-545f974f5d-kxcqh             1/1     Running     1 (2m8s ago)   6m38s
```

### Connect to milvus
```
 kubectl port-forward --address 0.0.0.0 service/m6i-8xlarge-milvus 19530
```

### Test connection
```
python3 -m pip install pymilvus==2.0.0
wget https://raw.githubusercontent.com/milvus-io/pymilvus/v2.0.0/examples/hello_milvus.py
python3 hello_milvus.py
```

### Optional (install netdata for quick resource analysis)

```
sudo apt install netdata -y

```


## Client VM

### Instal ann-benchmark
```
sudo apt update
sudo apt install docker.io -y
sudo apt install python3-pip -y
sudo pip3 install --upgrade pip
git clone https://github.com/RedisAI/ann-benchmarks --branch multiclient_tool
cd ann-benchmarks
pip3 install -r requirements.txt  --ignore-installed PyYAML
pip3 install pymilvus==2.0.0
```

### Run milvus-hnsw
```
python3 run.py --local --algorithm milvus-hnsw --port 19530 --host <ip vector server> 
```