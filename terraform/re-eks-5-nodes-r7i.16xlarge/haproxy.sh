#!/bin/bash
#
# haproxy.sh - Configure HAProxy Ingress Controller for Redis Enterprise Cluster
#
# This script installs the HAProxy Ingress Controller and configures Ingress resources
# to route external traffic to Redis Enterprise services.
#

set -e  # Exit immediately if a command exits with a non-zero status

# Configuration
NAMESPACE="rec-large-scale"
REC_NAME="rec-large-scale-5nodes"
INGRESS_NAME="haproxy-ingress"
INGRESS_CLASS="haproxy"


echo "Configuring HAProxy Ingress Controller for Redis Enterprise Cluster..."
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: haproxy
spec:
  controller: haproxy-ingress.github.io/controller
EOF


cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: haproxy-tcp-services
  namespace: rec-large-scale
data:
  "11793": "rec-large-scale/primary:11793"
EOF


kubectl set env deployment/haproxy-ingress --namespace=rec-large-scale \
  --containers=haproxy-ingress \
  TCP_SERVICES_CONFIGMAP=rec-large-scale/haproxy-tcp-services


kubectl patch service haproxy-ingress -n rec-large-scale --patch '{
  "spec": {
    "ports": [
      {
        "name": "http-80",
        "port": 80,
        "protocol": "TCP",
        "targetPort": "http"
      },
      {
        "name": "https-443",
        "port": 443,
        "protocol": "TCP",
        "targetPort": "https"
      },
      {
        "name": "redis-11793",
        "port": 11793,
        "protocol": "TCP",
        "targetPort": 11793
      }
    ]
  }
}'

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

kubectl get service redis-tcp-proxy -n rec-large-scale