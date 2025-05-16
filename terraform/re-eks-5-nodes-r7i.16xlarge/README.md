# Redis Enterprise Cluster on EKS

This directory contains Terraform configurations and utility scripts for deploying and managing a Redis Enterprise Cluster on Amazon EKS.

## Overview

The configuration deploys a 5-node Redis Enterprise Cluster on Amazon EKS using r7i.16xlarge instances. It includes optimizations to prevent IP address exhaustion by setting the WARM_ENI_TARGET to 10 (reduced from the default of 50).

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform installed
- kubectl installed and configured
- A valid Redis Enterprise license

## Deployment

1. Initialize Terraform:
   ```bash
   terraform init
   ```

2. Apply the Terraform configuration:
   ```bash
   terraform apply
   ```

3. Deploy the Redis Enterprise Cluster:
   ```bash
   ./deploy.sh
   ```

## Utility Scripts

This directory includes several utility scripts to help manage the Redis Enterprise Cluster:

### access-redis.sh

A comprehensive tool for accessing Redis Enterprise Cluster and databases.

```bash
./access-redis.sh [OPTION]
```

Options:
- `ui`: Set up port forwarding for Redis Enterprise Cluster UI
- `db NAME`: Set up port forwarding for a specific Redis database
- `list`: List all Redis databases
- `creds`: Show Redis Enterprise Cluster credentials
- `help`: Display help information

For more information, run `./access-redis.sh help`.

### port-forward-rec-ui.sh

Sets up port forwarding to access the Redis Enterprise Cluster UI.

```bash
./port-forward-rec-ui.sh
```

After running this script, you can access the UI at https://localhost:8443.

### set-rec-credentials.sh

Retrieves and sets environment variables for Redis Enterprise Cluster credentials.

```bash
source ./set-rec-credentials.sh
```

This script sets the following environment variables:
- `REC_USERNAME`: The Redis Enterprise Cluster username
- `REC_PASSWORD`: The Redis Enterprise Cluster password
- `REC_UI_URL`: The URL for the Redis Enterprise Cluster UI (if available)

### update-license.sh

Updates the Redis Enterprise Cluster license.

```bash
./update-license.sh [OPTION]
```

Options:
- `--secret`: Update the license using a Kubernetes secret (recommended)
- `--inline`: Update the license directly in the REC custom resource (not recommended)
- `--help`: Display help information

For detailed documentation, see [README-license.md](README-license.md).

### check-ips-eni.sh

Checks the IP address usage in the subnet.

```bash
./check-ips-eni.sh
```

### monitor-ip-usage.sh

Monitors IP address usage in the subnet.

```bash
./monitor-ip-usage.sh
```

### haproxy.sh

Configures HAProxy Ingress Controller for external routing to Redis Enterprise services.

```bash
./haproxy.sh
```

This script:
- Installs the HAProxy Ingress Controller using Helm
- Creates Ingress resources for Redis Enterprise UI and API
- Configures SSL passthrough for secure access
- Provides access URLs for the Redis Enterprise services

### configure-db-ingress.sh

Configures Ingress for Redis Enterprise Databases to enable external access.

```bash
./configure-db-ingress.sh --db-name DATABASE_NAME [--db-host HOSTNAME]
```

This script:
- Dynamically retrieves the correct port for the specified Redis database
- Creates an Ingress resource to route external traffic to the database
- Supports custom hostnames for the database
- Provides connection information for accessing the database

### apply-primary-haproxy.sh

Applies the primary-haproxy.yaml file to set up external access to the primary database.

```bash
./apply-primary-haproxy.sh
```

This script:
- Applies the primary-haproxy.yaml file with the correct port configuration
- Provides instructions for testing the connection

### test-conn-lb.sh

Tests connection to Redis Enterprise Database using LoadBalancer hostname.

```bash
./test-conn-lb.sh
```

This script:
- Uses the LoadBalancer hostname to connect to the database
- Provides instructions for testing the connection using OpenSSL

### setup-and-test-db-access.sh

Sets up and tests external access to Redis Enterprise Database.

```bash
./setup-and-test-db-access.sh
```

This script:
- Applies the primary-haproxy.yaml file
- Retrieves the database hostname and port
- Provides detailed instructions for testing the connection

### test-redis-cli-insecure.sh

Tests connection to Redis Enterprise Database using redis-cli with insecure TLS.

```bash
./test-redis-cli-insecure.sh
```

This script:
- Uses redis-cli with the --tls --insecure options to skip certificate verification
- Connects to the database using the LoadBalancer hostname
- Uses SNI (Server Name Indication) to route the request to the correct backend

### redis-cli-instructions.sh

Provides instructions for connecting to Redis Enterprise Database using redis-cli.

```bash
./redis-cli-instructions.sh
```

This script:
- Provides detailed instructions for installing and using redis-cli
- Shows how to connect using the LoadBalancer hostname or Ingress hostname
- Includes options for both insecure TLS and certificate verification

### test-conn-internal.sh

Tests connection to Redis Enterprise Database from inside a Redis Enterprise pod.

```bash
./test-conn-internal.sh
```

This script:
- Connects to the database from inside a Redis Enterprise pod
- Uses the internal service name to bypass external connectivity issues
- Provides a reliable way to test database connectivity

### test-conn-pod.sh

Tests connection to Redis Enterprise Database from inside a Redis Enterprise pod with detailed steps.

```bash
./test-conn-pod.sh
```

This script:
- Follows the official Redis Enterprise documentation for connecting to a database
- Retrieves the secret name, service names, and password from the Kubernetes secret
- Uses the --tls --insecure options when TLS is enabled
- Provides a connection information summary for easier troubleshooting

### check-haproxy-config.sh

Checks HAProxy Ingress configuration for Redis Enterprise Database.

```bash
./check-haproxy-config.sh
```

This script:
- Verifies that HAProxy Ingress is installed and running
- Checks the Ingress resource configuration
- Ensures that the port and service name are correctly configured
- Provides troubleshooting information for connectivity issues

### check-db-status.sh

Checks Redis Enterprise Database status and provides detailed information.

```bash
./check-db-status.sh
```

This script:
- Retrieves detailed information about the Redis Enterprise Database
- Shows the database configuration, endpoints, and services
- Provides the correct internal and external connection strings
- Helps diagnose connectivity issues by showing all relevant information

### inspect-haproxy-config.sh

Inspects HAProxy Ingress configuration for Redis Enterprise Database access.

```bash
./inspect-haproxy-config.sh
```

This script:
- Examines the HAProxy Ingress configuration file
- Checks for SSL passthrough and TCP mode configuration
- Verifies backend configuration for Redis Enterprise Database
- Analyzes HAProxy Ingress logs for errors

### check-ingress-annotations.sh

Checks Ingress annotations for Redis Enterprise Database access.

```bash
./check-ingress-annotations.sh
```

This script:
- Verifies that the correct annotations are set on the Ingress resource
- Checks for SSL passthrough and SSL redirect annotations
- Ensures the Ingress class is set to HAProxy
- Validates backend service and port configuration

### fix-haproxy-config.sh

Fixes HAProxy Ingress configuration for Redis Enterprise Database access.

```bash
./fix-haproxy-config.sh
```

This script:
- Updates or creates Ingress resources with the correct configuration
- Sets the required annotations for SSL passthrough
- Ensures the correct port is used for the Redis Enterprise Database
- Creates an additional Ingress resource for the LoadBalancer hostname

### diagnose-connection-timeout.sh

Diagnoses connection timeout issues when connecting to Redis Enterprise Database.

```bash
./diagnose-connection-timeout.sh
```

This script:
- Checks if the LoadBalancer hostname is resolvable
- Tests if the port is reachable using telnet and netcat
- Examines AWS security groups for potential issues
- Verifies HAProxy Ingress configuration for TCP passthrough
- Checks if the database is accessible from inside the cluster
- Identifies network policies that might be blocking the connection

### test-with-temp-pod.sh

Tests connection to Redis Enterprise Database using a temporary pod.

```bash
./test-with-temp-pod.sh
```

This script:
- Creates a temporary pod with redis-cli installed
- Retrieves database connection information from Kubernetes secrets
- Tests the connection from inside the Kubernetes cluster
- Provides detailed diagnostics if the connection fails
- Offers an interactive environment for further testing

### redis-tcp-proxy.yaml

Deploys a dedicated TCP proxy for Redis Enterprise Database access.

```bash
kubectl apply -f redis-tcp-proxy.yaml
```

This file:
- Creates a deployment with HAProxy configured for TCP mode
- Sets up a LoadBalancer service to expose the proxy
- Configures HAProxy to handle TLS traffic to the Redis Enterprise Database
- Provides a reliable way to access the Redis Enterprise Database from outside the cluster

### test-redis-tcp-proxy.sh

Tests connection to Redis Enterprise Database through the TCP proxy.

```bash
./test-redis-tcp-proxy.sh
```

This script:
- Tests the connection to the Redis Enterprise Database through the TCP proxy
- Tries both with and without TLS to determine the correct connection method
- Provides detailed diagnostics if the connection fails
- Offers guidance on how to use redis-cli to interact with the database

### setup-redis-external-access.sh

Sets up external access to Redis Enterprise Database on port 12000.

```bash
./setup-redis-external-access.sh
```

This script:
- Creates an IngressClass resource for HAProxy
- Creates a TCP Services ConfigMap for HAProxy
- Updates the HAProxy Ingress Controller to use the TCP Services ConfigMap
- Updates the HAProxy Service to expose the Redis port
- Creates a dedicated TCP proxy for Redis using port 12000
- Waits for the TCP proxy to start
- Gets the LoadBalancer hostname for the TCP proxy
- Gets the database password
- Provides instructions for connecting to the Redis Enterprise Database

### test-redis-port-12000.sh

Tests connection to Redis Enterprise Database on port 12000.

```bash
./test-redis-port-12000.sh
```

This script:
- Gets the LoadBalancer hostname for the TCP proxy
- Gets the database password
- Tests the connection to the Redis Enterprise Database on port 12000
- Provides detailed diagnostics if the connection fails
- Offers guidance on how to use redis-cli to interact with the database

## IP Address Optimization

This configuration uses a reduced WARM_ENI_TARGET value of 10 (down from the default of 50) to prevent IP address exhaustion in the subnet. This is set in the cluster.tf file.

## License Management

The Redis Enterprise Cluster requires a valid license to operate with full functionality. See [README-license.md](README-license.md) for detailed information on how to update the license.

## Troubleshooting

If you encounter issues with the deployment:

1. Check the Terraform logs for any errors
2. Verify that the EKS cluster is running:
   ```bash
   kubectl get nodes
   ```
3. Check the status of the Redis Enterprise Cluster:
   ```bash
   kubectl get rec
   ```
4. Check the Kubernetes events for any errors:
   ```bash
   kubectl get events
   ```

## Cleanup

To destroy the resources created by Terraform:

```bash
terraform destroy
```

This will remove all resources created by this configuration, including the EKS cluster and the Redis Enterprise Cluster.
