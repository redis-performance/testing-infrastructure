#!/bin/bash
# Update kubeconfig
aws eks update-kubeconfig --region us-east-2 --name re-eks-cluster-5-nodes-r7i-16xlarge

kubectl config set-context --current --namespace=rec-large-scale

# Set namespace
NAMESPACE="rec-large-scale"
CLUSTER_NAME=rec-large-scale-5nodes
TARGET_CLUSTER_NAME=rec-large-scale-5nodes

# Get Redis Enterprise Cluster admin credentials
CLUSTER_USER=$(kubectl get secret rec-large-scale-5nodes -n $NAMESPACE -o jsonpath="{.data.username}" | base64 --decode)
CLUSTER_PASSWORD=$(kubectl get secret rec-large-scale-5nodes -n $NAMESPACE -o jsonpath="{.data.password}" | base64 --decode)

echo "Redis Enterprise Cluster admin credentials:"
echo "Username: $CLUSTER_USER"
echo "Password: $CLUSTER_PASSWORD"


SOURCE_DB=primary
TARGET_DB=replicaof

kubectl port-forward pod/${CLUSTER_NAME}-0 9443


JQ='.[] | select(.name=="'
JQ+="${SOURCE_DB}"
JQ+='") | ("redis://admin:" + .authentication_admin_pass + "@"+.name+":"+(.endpoints[0].port|tostring))'
URI=`curl -sf -k -u "$CLUSTER_USER:$CLUSTER_PASSWORD" "https://localhost:9443/v1/bdbs?fields=uid,name,endpoints,authentication_admin_pass" | jq "$JQ" | sed 's/"//g'`

cat << EOF > secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: ${SOURCE_DB}-url
stringData:
  uri: ${URI}
EOF
kubectl apply -f secret.yaml





cat << EOF > 
apiVersion: app.redislabs.com/v1alpha1
kind: RedisEnterpriseDatabase
metadata:
  name: replicaof # name this whatever you wish
spec:
  replicaSources:
   - replicaSourceType: SECRET
     replicaSourceName: redis-11793.rec-large-scale-5nodes.rec-large-scale.svc.cluster.local:11793
  memorySize: 200GiB
  evictionPolicy: volatile-lru
  databasePort: 13000
  modulesList:
  - name: search
    config: "MT_MODE MT_MODE_FULL WORKER_THREADS 12"
  - name: bf
  - name: ReJSON
  - name: timeseries
  redisEnterpriseCluster:
    name: rec-large-scale-5nodes # Change this to whatever you named the REC
  replication: false
  ossCluster: false            # Explicitly disable OSS Cluster API
  shardCount: 40
  persistence: disabled
  tlsMode: enabled             # MUST be enabled for HAProxy
  shardsPlacement: "sparse"
EOF
kubectl apply -f replicaof-db.yaml