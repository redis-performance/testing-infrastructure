#!/bin/bash
#
# setup-redis-external-access.sh - Set up external access to Redis Enterprise Database
#
# This script sets up external access to a Redis Enterprise Database using a dedicated
# TCP proxy on port 12000.
#

set -e  # Exit immediately if a command exits with a non-zero status

# Configuration
NAMESPACE="rec-large-scale"
DB_NAME="primary"
DB_PORT="11793"
PROXY_PORT="12000"

echo "=== Setting Up External Access to Redis Enterprise Database ==="
echo ""
echo "Namespace: $NAMESPACE"
echo "Database name: $DB_NAME"
echo "Database port: $DB_PORT"
echo "Proxy port: $PROXY_PORT"
echo ""

# Step 1: Create the IngressClass Resource
echo "Step 1: Creating IngressClass resource..."
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: haproxy
spec:
  controller: haproxy-ingress.github.io/controller
EOF
echo "IngressClass resource created."

# Step 2: Create a TCP Services ConfigMap for HAProxy
echo ""
echo "Step 2: Creating TCP Services ConfigMap for HAProxy..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: haproxy-tcp-services
  namespace: $NAMESPACE
data:
  "$DB_PORT": "$NAMESPACE/$DB_NAME:$DB_PORT"
EOF
echo "TCP Services ConfigMap created."

# Step 3: Update HAProxy Ingress Controller to Use TCP Services
echo ""
echo "Step 3: Updating HAProxy Ingress Controller to use TCP Services..."
kubectl set env deployment/haproxy-ingress --namespace=$NAMESPACE \
  --containers=haproxy-ingress \
  TCP_SERVICES_CONFIGMAP=$NAMESPACE/haproxy-tcp-services
echo "HAProxy Ingress Controller updated."

# Step 4: Update HAProxy Service to Expose Redis Port
echo ""
echo "Step 4: Checking if HAProxy Service already exposes Redis port..."
PORT_EXISTS=$(kubectl get service haproxy-ingress -n $NAMESPACE -o jsonpath="{.spec.ports[?(@.port==$DB_PORT)]}")
if [ -z "$PORT_EXISTS" ]; then
  echo "Adding Redis port to HAProxy Service..."
  kubectl patch service haproxy-ingress -n $NAMESPACE --type=json -p="[
    {
      \"op\": \"add\",
      \"path\": \"/spec/ports/-\",
      \"value\": {
        \"name\": \"redis-$DB_PORT\",
        \"port\": $DB_PORT,
        \"protocol\": \"TCP\",
        \"targetPort\": $DB_PORT
      }
    }
  ]"
  echo "HAProxy Service updated."
else
  echo "Redis port already exposed in HAProxy Service."
fi

# Step 5: Create a Dedicated TCP Proxy for Redis
echo ""
echo "Step 5: Checking if TCP proxy already exists..."
PROXY_EXISTS=$(kubectl get deployment redis-tcp-proxy -n $NAMESPACE 2>/dev/null)
if [ -z "$PROXY_EXISTS" ]; then
  echo "Creating a dedicated TCP proxy for Redis..."
  cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-tcp-proxy
  namespace: $NAMESPACE
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
        - containerPort: $PROXY_PORT
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
  namespace: $NAMESPACE
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
      bind *:$PROXY_PORT
      default_backend redis_backend

    backend redis_backend
      mode tcp
      server redis $DB_NAME.$NAMESPACE.svc.cluster.local:$DB_PORT check ssl verify none
---
apiVersion: v1
kind: Service
metadata:
  name: redis-tcp-proxy
  namespace: $NAMESPACE
spec:
  type: LoadBalancer
  ports:
  - port: $PROXY_PORT
    targetPort: $PROXY_PORT
    protocol: TCP
  selector:
    app: redis-tcp-proxy
EOF
  echo "TCP proxy created."
else
  echo "TCP proxy already exists. Updating configuration..."
  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-tcp-proxy-config
  namespace: $NAMESPACE
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
      bind *:$PROXY_PORT
      default_backend redis_backend

    backend redis_backend
      mode tcp
      server redis $DB_NAME.$NAMESPACE.svc.cluster.local:$DB_PORT check ssl verify none
EOF

  # Check if the service has the correct port
  SERVICE_PORT=$(kubectl get service redis-tcp-proxy -n $NAMESPACE -o jsonpath="{.spec.ports[0].port}")
  if [ "$SERVICE_PORT" != "$PROXY_PORT" ]; then
    echo "Updating TCP proxy service port from $SERVICE_PORT to $PROXY_PORT..."
    kubectl patch service redis-tcp-proxy -n $NAMESPACE --type=json -p="[
      {
        \"op\": \"replace\",
        \"path\": \"/spec/ports/0/port\",
        \"value\": $PROXY_PORT
      },
      {
        \"op\": \"replace\",
        \"path\": \"/spec/ports/0/targetPort\",
        \"value\": $PROXY_PORT
      }
    ]"
  fi

  # Restart the TCP proxy pod to pick up the new configuration
  echo "Restarting TCP proxy pod..."
  kubectl delete pod -n $NAMESPACE -l app=redis-tcp-proxy
  echo "TCP proxy updated."
fi

# Step 6: Wait for the TCP proxy to start
echo ""
echo "Step 6: Waiting for the TCP proxy to start..."
kubectl rollout status deployment/redis-tcp-proxy -n $NAMESPACE
echo "TCP proxy started."

# Step 7: Get the LoadBalancer hostname for the TCP proxy
echo ""
echo "Step 7: Getting the LoadBalancer hostname for the TCP proxy..."
LB_HOSTNAME=$(kubectl get service redis-tcp-proxy -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
if [ -z "$LB_HOSTNAME" ]; then
    echo "Warning: LoadBalancer hostname not available yet. Please run the following command to get it:"
    echo "kubectl get service redis-tcp-proxy -n $NAMESPACE"
else
    echo "LoadBalancer hostname: $LB_HOSTNAME"
fi

# Step 8: Get the database password
echo ""
echo "Step 8: Getting the database password..."
PASSWORD=$(kubectl get secret redb-$DB_NAME -n $NAMESPACE -o jsonpath="{.data.password}" | base64 --decode 2>/dev/null)
if [ -z "$PASSWORD" ]; then
    echo "Warning: Could not retrieve the database password. Please get it manually using:"
    echo "kubectl get secret redb-$DB_NAME -n $NAMESPACE -o jsonpath=\"{.data.password}\" | base64 --decode"
else
    echo "Database password retrieved."
fi

echo ""
echo "=== External Access Setup Complete ==="
echo ""
echo "You can now connect to the Redis Enterprise Database using:"
if [ -n "$LB_HOSTNAME" ] && [ -n "$PASSWORD" ]; then
    echo "redis-cli -h $LB_HOSTNAME -p $PROXY_PORT -a $PASSWORD"
else
    echo "redis-cli -h <LoadBalancer-Hostname> -p $PROXY_PORT -a <password>"
fi
echo ""
echo "To get the LoadBalancer hostname, run:"
echo "kubectl get service redis-tcp-proxy -n $NAMESPACE"
echo ""
echo "To get the database password, run:"
echo "kubectl get secret redb-$DB_NAME -n $NAMESPACE -o jsonpath=\"{.data.password}\" | base64 --decode"
