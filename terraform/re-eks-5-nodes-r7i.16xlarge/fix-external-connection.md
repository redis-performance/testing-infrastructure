# Fixing External Connection to Redis Enterprise Database

## Current Issues

1. **LoadBalancer Service Issue**: The HAProxy Ingress LoadBalancer service is in a `<pending>` state because there are not enough IP addresses available in the subnet. The error message is:
   ```
   Error syncing load balancer: failed to ensure load balancer: InvalidSubnet: Not enough IP space available in subnet-0597ccd9e8d2a050e. ELB requires at least 8 free IP addresses in each subnet.
   ```

2. **AWS Credentials Expired**: The AWS credentials have expired, preventing us from making changes to the AWS resources or updating the Kubernetes configuration.

## Solution Steps (After AWS Credentials are Refreshed)

### Step 1: Free up IP addresses in the subnet

```bash
# Update AWS credentials
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_SESSION_TOKEN="your-session-token"
export AWS_REGION="us-east-2"

# Update kubeconfig
aws eks update-kubeconfig --region us-east-2 --name re-eks-cluster-5-nodes-r7i-16xlarge

# Reduce the number of IP addresses reserved by the AWS VPC CNI plugin
kubectl set env daemonset aws-node -n kube-system WARM_ENI_TARGET=0 WARM_IP_TARGET=1

# Wait for the changes to take effect
sleep 60

# Check available IP addresses in the subnet
aws ec2 describe-subnets --subnet-ids subnet-0597ccd9e8d2a050e --query 'Subnets[0].{CIDR:CidrBlock,AvailableIPs:AvailableIpAddressCount}'
```

### Step 2: Recreate the HAProxy Ingress service

```bash
# Delete the existing HAProxy Ingress service
kubectl delete svc haproxy-ingress -n rec-large-scale

# Reinstall HAProxy Ingress
./haproxy.sh
```

### Step 3: Test the external connection

```bash
# Wait for the LoadBalancer to be provisioned
kubectl get svc haproxy-ingress -n rec-large-scale

# Once the LoadBalancer has an external IP, test the connection
./test-external-connection.sh
```

## Alternative Solution: Use NodePort Instead of LoadBalancer

If the LoadBalancer service still doesn't work, you can use a NodePort service instead:

```bash
# Create a NodePort service for the Redis database
cat > primary-nodeport.yaml << EOF
apiVersion: v1
kind: Service
metadata:
  name: primary-nodeport
  namespace: rec-large-scale
spec:
  type: NodePort
  ports:
  - port: 11793
    targetPort: 11793
    nodePort: 30793
    protocol: TCP
  selector:
    redis.io/bdb-1: "1"
EOF

# Apply the NodePort service
kubectl apply -f primary-nodeport.yaml

# Allow traffic on the NodePort
NODE_SECURITY_GROUP=$(aws ec2 describe-instances --filters "Name=instance-id,Values=$(kubectl get nodes -o jsonpath='{.items[0].spec.providerID}' | cut -d '/' -f5)" --query "Reservations[0].Instances[0].SecurityGroups[*].GroupId" --output text)
aws ec2 authorize-security-group-ingress --group-id $NODE_SECURITY_GROUP --protocol tcp --port 30793 --cidr 0.0.0.0/0

# Get the external IP of one of the nodes
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')

# Test the connection
redis-cli -h $NODE_IP -p 30793 --tls --insecure -a VK7wvBPC PING
```

## Alternative Solution: Use Port Forwarding

If neither the LoadBalancer nor NodePort solutions work, you can use port forwarding:

```bash
# Start port forwarding
kubectl port-forward svc/primary -n rec-large-scale 11793:11793

# In another terminal, test the connection
redis-cli -p 11793 --tls --insecure -a VK7wvBPC PING
```

## Troubleshooting Tips

1. **Check the status of the Redis Enterprise Database**:
   ```bash
   kubectl get redb -n rec-large-scale
   ```

2. **Check the Redis Enterprise Database service**:
   ```bash
   kubectl get svc -n rec-large-scale | grep primary
   ```

3. **Check the endpoints for the Redis Enterprise Database service**:
   ```bash
   kubectl get endpoints primary -n rec-large-scale
   ```

4. **Check the Redis Enterprise Database logs**:
   ```bash
   kubectl logs -n rec-large-scale -l redis.io/bdb-1=1
   ```

5. **Check the HAProxy Ingress logs**:
   ```bash
   kubectl logs -n rec-large-scale -l app.kubernetes.io/name=haproxy-ingress
   ```
