# Redis Enterprise Database Connection Guide

This guide provides instructions for connecting to the Redis Enterprise Database using different methods.

## Connection Methods

### 1. Using NodePort (Recommended)

The NodePort method is the most reliable way to connect to the Redis Enterprise Database. It exposes the database on a specific port on all nodes in the cluster.

```bash
redis-cli -h 18.223.203.147 -p 30793 --tls --insecure -a fEyYdaqU
```

Replace `18.223.203.147` with the external IP of any node in the cluster. You can get the list of node IPs using:

```bash
kubectl get nodes -o wide
```

### 2. Using HAProxy Ingress (Advanced)

The HAProxy Ingress method provides a more robust and scalable solution for external access, but it requires additional configuration.

#### 2.1. Using SSL Passthrough

```bash
redis-cli -h a245ddcf13c764d7aada41f71a8bbcad-220634774.us-east-2.elb.amazonaws.com -p 443 --tls --insecure --sni primary.a245ddcf13c764d7aada41f71a8bbcad-220634774.us-east-2.elb.amazonaws.com -a fEyYdaqU
```

**Note**: This method may not work reliably due to SSL passthrough configuration issues.

#### 2.2. Using TCP Ingress

```bash
redis-cli -h a245ddcf13c764d7aada41f71a8bbcad-220634774.us-east-2.elb.amazonaws.com -p 443 --tls --insecure --sni primary-tcp.a245ddcf13c764d7aada41f71a8bbcad-220634774.us-east-2.elb.amazonaws.com -a fEyYdaqU
```

**Note**: This method may not work reliably due to TCP ingress configuration issues.

### 3. Using Port Forwarding (Development Only)

Port forwarding is useful for development and testing, but it's not suitable for production use.

```bash
# Start port forwarding in one terminal
kubectl port-forward svc/primary -n rec-large-scale 11793:11793

# Connect to the database in another terminal
redis-cli -p 11793 --tls --insecure -a fEyYdaqU
```

## Troubleshooting

### 1. Check Database Status

```bash
kubectl get redb primary -n rec-large-scale
```

### 2. Check Database Service

```bash
kubectl get svc primary -n rec-large-scale
```

### 3. Check Database Endpoints

```bash
kubectl get endpoints primary -n rec-large-scale
```

### 4. Check NodePort Service

```bash
kubectl get svc primary-nodeport -n rec-large-scale
```

### 5. Check HAProxy Ingress

```bash
kubectl get ingress -n rec-large-scale
```

### 6. Check HAProxy Ingress Logs

```bash
kubectl logs -n rec-large-scale -l app.kubernetes.io/name=haproxy-ingress
```

### 7. Check Database Password

```bash
kubectl get secret redb-primary -n rec-large-scale -o jsonpath="{.data.password}" | base64 --decode
```

## Common Issues

### 1. Connection Refused

If you get a "Connection refused" error, check if the service is running and the port is open:

```bash
# Check if the service is running
kubectl get svc primary -n rec-large-scale

# Check if the port is open
nc -z -w 5 <hostname> <port>
```

### 2. Authentication Failed

If you get an "Authentication failed" error, check if the password is correct:

```bash
kubectl get secret redb-primary -n rec-large-scale -o jsonpath="{.data.password}" | base64 --decode
```

### 3. TLS Connection Failed

If you get a TLS connection error, check if the TLS configuration is correct:

```bash
openssl s_client -connect <hostname>:<port> -servername <sni-hostname> -quiet </dev/null
```

### 4. Protocol Error

If you get a "Protocol error, got 'H' as reply type byte" error, it means the server is responding with HTTP instead of Redis protocol. This can happen when:

1. The SSL passthrough is not working correctly
2. The SNI hostname is incorrect
3. The HAProxy Ingress is not configured correctly

Try using the NodePort method instead.

## Scripts

The following scripts are available to help you connect to the Redis Enterprise Database:

1. `test-nodeport-connection.sh`: Tests the connection using the NodePort method
2. `test-external-connection.sh`: Tests the connection using the HAProxy Ingress method
3. `test-ssl-passthrough.sh`: Tests the connection using the SSL passthrough method
4. `test-portforward-connection.sh`: Tests the connection using the port forwarding method

## Additional Resources

For more information, see the Redis Enterprise Kubernetes documentation:
https://docs.redis.com/latest/kubernetes/
