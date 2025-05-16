#!/bin/bash
#
# troubleshooting-guide.sh - Comprehensive guide for troubleshooting Redis Enterprise Database connectivity
#
# This script provides a comprehensive guide for troubleshooting connectivity issues
# with Redis Enterprise Database in Kubernetes.
#

# Configuration
NAMESPACE="rec-large-scale"
DB_NAME="primary"
INGRESS_NAME="primary-haproxy-ingress"

echo "=== Redis Enterprise Database Connectivity Troubleshooting Guide ==="
echo ""
echo "This guide will help you troubleshoot connectivity issues with Redis Enterprise Database."
echo ""

# Get database information
echo "Step 1: Check Redis Enterprise Database status"
echo "---------------------------------------------"
echo "Run the following command to check the database status:"
echo "kubectl get redb $DB_NAME -n $NAMESPACE"
echo ""
echo "Expected output:"
echo "NAME      VERSION   PORT    CLUSTER                  SHARDS   STATUS   SPEC STATUS   AGE"
echo "$DB_NAME  7.4.2     11793   rec-large-scale-5nodes   20       active   Valid         45m"
echo ""
echo "If the database is not found or not active, make sure it's properly deployed."
echo ""

# Get database endpoints
echo "Step 2: Check Redis Enterprise Database endpoints"
echo "------------------------------------------------"
echo "Run the following command to check the database endpoints:"
echo "kubectl get redb $DB_NAME -n $NAMESPACE -o jsonpath='{.status.internalEndpoints}' | jq -r '.'"
echo ""
echo "Expected output:"
echo '[
  {
    "host": "redis-11793.rec-large-scale-5nodes.rec-large-scale.svc.cluster.local",
    "port": 11793
  }
]'
echo ""
echo "Note the host and port for internal connections."
echo ""

# Check HAProxy Ingress
echo "Step 3: Check HAProxy Ingress status"
echo "-----------------------------------"
echo "Run the following command to check the HAProxy Ingress service:"
echo "kubectl get svc -n $NAMESPACE -l app.kubernetes.io/name=haproxy-ingress"
echo ""
echo "Expected output:"
echo "NAME              TYPE           CLUSTER-IP      EXTERNAL-IP                                                              PORT(S)                      AGE"
echo "haproxy-ingress   LoadBalancer   172.20.67.239   a774cbc5b6f0e4c3c8591b1f5bfe945e-398267775.us-east-2.elb.amazonaws.com   80:30285/TCP,443:30271/TCP   40m"
echo ""
echo "Make sure the service has an EXTERNAL-IP assigned."
echo ""

# Check Ingress resources
echo "Step 4: Check Ingress resources"
echo "------------------------------"
echo "Run the following command to check the Ingress resources:"
echo "kubectl get ingress -n $NAMESPACE | grep -i $DB_NAME"
echo ""
echo "Expected output:"
echo "primary-haproxy-ingress           haproxy   primary-db.example.com                                                                     80      21m"
echo "primary-haproxy-ingress-primary   haproxy   primary.a774cbc5b6f0e4c3c8591b1f5bfe945e-398267775.us-east-2.elb.amazonaws.com             80      31m"
echo ""
echo "Make sure the Ingress resources are properly configured."
echo ""

# Test internal connectivity
echo "Step 5: Test internal connectivity"
echo "--------------------------------"
echo "Run the following command to test connectivity from inside a Redis Enterprise pod:"
echo ""
echo "# Get a Redis Enterprise pod name"
echo "POD_NAME=\$(kubectl get pods -n $NAMESPACE -l app=redis-enterprise -o jsonpath='{.items[0].metadata.name}')"
echo ""
echo "# Get the database password"
echo "PASSWORD=\$(kubectl get secret redb-$DB_NAME -n $NAMESPACE -o jsonpath=\"{.data.password}\" | base64 --decode)"
echo ""
echo "# Connect to the database from inside the pod"
echo "kubectl exec -it \$POD_NAME -c redis-enterprise-node -n $NAMESPACE -- redis-cli -h redis-11793.rec-large-scale-5nodes.rec-large-scale.svc.cluster.local -p 11793 -a \$PASSWORD"
echo ""
echo "If this works, it confirms that the database is accessible from inside the cluster."
echo ""

# Test external connectivity
echo "Step 6: Test external connectivity"
echo "--------------------------------"
echo "Run the following command to test connectivity from outside the cluster:"
echo ""
echo "# Get the LoadBalancer hostname"
echo "LB_HOSTNAME=\$(kubectl get svc -n $NAMESPACE -l app.kubernetes.io/name=haproxy-ingress -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')"
echo ""
echo "# Get the database password"
echo "PASSWORD=\$(kubectl get secret redb-$DB_NAME -n $NAMESPACE -o jsonpath=\"{.data.password}\" | base64 --decode)"
echo ""
echo "# Connect to the database from outside the cluster"
echo "redis-cli -h \$LB_HOSTNAME -p 11793 --tls --insecure --sni $DB_NAME.\$LB_HOSTNAME -a \$PASSWORD"
echo ""
echo "If this doesn't work, it could be due to network connectivity issues or firewall rules."
echo ""

# Check network connectivity
echo "Step 7: Check network connectivity"
echo "--------------------------------"
echo "Run the following command to check if you can reach the LoadBalancer hostname:"
echo ""
echo "# Get the LoadBalancer hostname"
echo "LB_HOSTNAME=\$(kubectl get svc -n $NAMESPACE -l app.kubernetes.io/name=haproxy-ingress -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')"
echo ""
echo "# Check if you can resolve the hostname"
echo "nslookup \$LB_HOSTNAME"
echo ""
echo "# Check if you can reach the hostname on port 443"
echo "telnet \$LB_HOSTNAME 443"
echo ""
echo "If you can't reach the hostname, it could be due to network connectivity issues or firewall rules."
echo ""

# Troubleshooting tips
echo "Step 8: Troubleshooting tips"
echo "--------------------------"
echo "1. Make sure the HAProxy Ingress controller is properly configured for SSL passthrough."
echo "2. Check if there are any network policies or security groups blocking the connection."
echo "3. Make sure the port in the Ingress resource matches the database port."
echo "4. Check the HAProxy Ingress logs for any errors."
echo "5. Try connecting from a different network or machine."
echo "6. Make sure the SNI hostname matches the one in the Ingress resource."
echo ""

# Useful commands
echo "Step 9: Useful commands"
echo "---------------------"
echo "# Check Redis Enterprise Database status"
echo "./check-db-status.sh"
echo ""
echo "# Check HAProxy Ingress configuration"
echo "./check-haproxy-config.sh"
echo ""
echo "# Test connection from inside a Redis Enterprise pod"
echo "./test-conn-internal.sh"
echo ""
echo "# Test connection using redis-cli with insecure TLS"
echo "./test-redis-cli-insecure.sh"
echo ""
echo "# Get redis-cli connection instructions"
echo "./redis-cli-instructions.sh"
echo ""

echo "=== End of Troubleshooting Guide ==="
