# Setting Up External Access to Redis Enterprise Database

This guide provides step-by-step instructions for setting up external access to a Redis Enterprise Database using a dedicated TCP proxy on port 12000.

## Prerequisites

- Kubernetes cluster with Redis Enterprise Database deployed
- `kubectl` configured to access the cluster
- Basic understanding of Kubernetes concepts

## Step 1: Create the IngressClass Resource

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: haproxy
spec:
  controller: haproxy-ingress.github.io/controller
EOF
```

## Step 2: Create a TCP Services ConfigMap for HAProxy

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: haproxy-tcp-services
  namespace: rec-large-scale
data:
  "11793": "rec-large-scale/primary:11793"
EOF
```

## Step 3: Update HAProxy Ingress Controller to Use TCP Services

```bash
kubectl set env deployment/haproxy-ingress --namespace=rec-large-scale \
  --containers=haproxy-ingress \
  TCP_SERVICES_CONFIGMAP=rec-large-scale/haproxy-tcp-services
```

## Step 4: Update HAProxy Service to Expose Redis Port

First, check if the port is already exposed:

```bash
PORT_EXISTS=$(kubectl get service haproxy-ingress -n rec-large-scale -o jsonpath="{.spec.ports[?(@.port==11793)]}")
```

If the port is not already exposed, add it:

```bash
kubectl patch service haproxy-ingress -n rec-large-scale --type=json -p="[
  {
    \"op\": \"add\",
    \"path\": \"/spec/ports/-\",
    \"value\": {
      \"name\": \"redis-11793\",
      \"port\": 11793,
      \"protocol\": \"TCP\",
      \"targetPort\": 11793
    }
  }
]"
```

## Step 5: Create a Dedicated TCP Proxy for Redis

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-tcp-proxy
  namespace: rec-large-scale
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis-tcp-proxy
  template:
    metadata:
      labels:
        app: redis-tcp-proxy
    spec:
      containers:
      - name: haproxy
        image: haproxy:latest
        ports:
        - containerPort: 12000
        volumeMounts:
        - name: haproxy-config
          mountPath: /usr/local/etc/haproxy/haproxy.cfg
          subPath: haproxy.cfg
      volumes:
      - name: haproxy-config
        configMap:
          name: redis-tcp-proxy-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-tcp-proxy-config
  namespace: rec-large-scale
data:
  haproxy.cfg: |
    global
      daemon
      maxconn 256

    defaults
      mode tcp
      timeout connect 5s
      timeout client 50s
      timeout server 50s

    frontend redis_frontend
      bind *:12000
      default_backend redis_backend

    backend redis_backend
      mode tcp
      server redis primary.rec-large-scale.svc.cluster.local:11793 check ssl verify none
---
apiVersion: v1
kind: Service
metadata:
  name: redis-tcp-proxy
  namespace: rec-large-scale
spec:
  type: LoadBalancer
  ports:
  - port: 12000
    targetPort: 12000
    protocol: TCP
  selector:
    app: redis-tcp-proxy
EOF
```

## Step 6: Wait for the TCP Proxy to Start

```bash
kubectl rollout status deployment/redis-tcp-proxy -n rec-large-scale
```

## Step 7: Get the LoadBalancer Hostname for the TCP Proxy

```bash
LB_HOSTNAME=$(kubectl get service redis-tcp-proxy -n rec-large-scale -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "LoadBalancer hostname: $LB_HOSTNAME"
```

## Step 8: Get the Database Password

```bash
PASSWORD=$(kubectl get secret redb-primary -n rec-large-scale -o jsonpath="{.data.password}" | base64 --decode)
echo "Database password: $PASSWORD"
```

## Step 9: Connect to the Redis Enterprise Database

```bash
redis-cli -h $LB_HOSTNAME -p 12000 -a $PASSWORD
```

## Troubleshooting

If you encounter any issues, try the following:

1. Check if the TCP proxy pod is running:
   ```bash
   kubectl get pods -n rec-large-scale -l app=redis-tcp-proxy
   ```

2. Check the TCP proxy pod logs:
   ```bash
   kubectl logs -n rec-large-scale -l app=redis-tcp-proxy
   ```

3. Check if the LoadBalancer service is created:
   ```bash
   kubectl get service redis-tcp-proxy -n rec-large-scale
   ```

4. Check if the port is open:
   ```bash
   nc -zv $LB_HOSTNAME 12000
   ```

5. Check if the Redis Enterprise Database is accessible from inside the cluster:
   ```bash
   kubectl exec -it $(kubectl get pods -n rec-large-scale -l app=redis-tcp-proxy -o jsonpath='{.items[0].metadata.name}') -n rec-large-scale -- redis-cli -h primary.rec-large-scale.svc.cluster.local -p 11793 --tls --insecure -a $PASSWORD PING
   ```
