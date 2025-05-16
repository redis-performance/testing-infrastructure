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
