# Redis Enterprise Cluster License Update

This document describes how to update the Redis Enterprise Cluster license using the `update-license.sh` script.

## Overview

The Redis Enterprise Cluster requires a valid license to operate with full functionality. The license is stored in a Kubernetes secret and referenced by the Redis Enterprise Cluster (REC) custom resource.

The `update-license.sh` script automates the process of updating the license, providing two methods:
1. Using a Kubernetes secret (recommended)
2. Directly in the REC custom resource (not recommended)

## Prerequisites

- A valid Redis Enterprise license file
- Access to the Kubernetes cluster where Redis Enterprise is deployed
- kubectl configured to access the cluster

## License File

The license should be stored in a file named `license.txt` in the same directory as the script. 

**Important**: The license file contains sensitive information and should not be committed to Git. The repository's `.gitignore` file is configured to ignore `*.txt` files, so `license.txt` should be excluded automatically.

## Usage

```bash
./update-license.sh [OPTION]
```

### Options

- `--secret`: Update the license using a Kubernetes secret (recommended)
- `--inline`: Update the license directly in the REC custom resource (not recommended)
- `--help`: Display help information

### Examples

1. Update the license using a Kubernetes secret (recommended):
   ```bash
   ./update-license.sh --secret
   ```

2. Update the license directly in the REC custom resource (not recommended):
   ```bash
   ./update-license.sh --inline
   ```

3. Display help information:
   ```bash
   ./update-license.sh --help
   ```

## How It Works

### Secret Method (Recommended)

When using the `--secret` option, the script:

1. Reads the license from the `license.txt` file
2. Creates or updates a Kubernetes secret named `redis-enterprise-license` containing the license
3. Updates the Redis Enterprise Cluster custom resource to reference the secret using the `licenseSecretName` field

This method is recommended because:
- It separates the license from the cluster configuration
- It makes it easier to update the license without modifying the cluster configuration
- It follows Kubernetes best practices for managing sensitive information

### Inline Method (Not Recommended)

When using the `--inline` option, the script:

1. Reads the license from the `license.txt` file
2. Updates the Redis Enterprise Cluster custom resource directly, embedding the license in the `license` field

This method is not recommended because:
- It embeds sensitive information directly in the cluster configuration
- It makes the cluster configuration more complex
- It doesn't follow Kubernetes best practices for managing sensitive information

## Verifying the License Update

After updating the license, you can verify that it was applied correctly by:

1. Checking the Redis Enterprise Cluster status:
   ```bash
   kubectl get rec rec-large-scale-5nodes -n rec-large-scale
   ```
   Look for the `LICENSE STATE` and `LICENSE EXPIRATION DATE` fields.

2. Accessing the Redis Enterprise Cluster UI:
   ```bash
   ./port-forward-rec-ui.sh
   ```
   Then open https://localhost:8443 in your browser and navigate to the license page.

## Troubleshooting

If you encounter issues when updating the license:

1. Make sure the license file is valid and properly formatted
2. Check that the Redis Enterprise Cluster is running
3. Verify that you have the necessary permissions to update the cluster
4. Check the Kubernetes events for any errors:
   ```bash
   kubectl get events -n rec-large-scale
   ```

## Related Scripts

- `port-forward-rec-ui.sh`: Sets up port forwarding to access the Redis Enterprise Cluster UI
- `access-redis.sh`: Comprehensive tool for accessing Redis Enterprise Cluster and databases
- `set-rec-credentials.sh`: Retrieves and sets environment variables for Redis Enterprise Cluster credentials
