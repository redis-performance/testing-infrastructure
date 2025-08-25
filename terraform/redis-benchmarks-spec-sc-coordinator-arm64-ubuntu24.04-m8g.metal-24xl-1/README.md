# Redis Benchmarks Spec SC Coordinator - ARM64 Ubuntu 22.04

This Terraform configuration deploys an AWS EC2 instance with automated setup of the Redis benchmarks specification coordinator using cloud-init.

## Features

The cloud-init script automatically installs and configures:

- **Development tools**: git, gcc, g++, make, cmake, clang, etc.
- **Redis installations**: Redis 7.2 and Redis 8.0.0 built from source with TLS support
- **Python environment**: pip3, pyopenssl, redis-benchmarks-specification package
- **Docker**: For containerized workloads
- **Supervisor**: Process management for the benchmark coordinator
- **Benchmark coordinator**: Automatically configured and started via supervisor

## Configuration

1. Copy the example variables file:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Edit `terraform.tfvars` with your actual configuration:
   ```hcl
   platform_name = "your-platform-name"
   event_stream_host = "your-event-stream-host.com"
   event_stream_port = "6379"
   event_stream_user = "your-username"
   event_stream_pass = "your-password"
   datasink_redistimeseries_host = "your-redistimeseries-host.com"
   datasink_redistimeseries_port = "6379"
   datasink_redistimeseries_pass = "your-redistimeseries-password"
   ```

## Deployment

1. Initialize Terraform:
   ```bash
   terraform init
   ```

2. Plan the deployment:
   ```bash
   terraform plan
   ```

3. Apply the configuration:
   ```bash
   terraform apply
   ```

## Monitoring

After deployment, you can monitor the setup progress and benchmark coordinator:

1. SSH into the instance:
   ```bash
   ssh -i ~/.ssh/benchmarksredislabsus-east-1.pem ubuntu@<instance-ip>
   ```

2. Check cloud-init logs:
   ```bash
   sudo tail -f /var/log/cloud-init-output.log
   ```

3. Check supervisor status:
   ```bash
   sudo supervisorctl status
   ```

4. Check benchmark coordinator logs:
   ```bash
   sudo tail -f /var/opt/redis-benchmarks-spec-sc-coordinator-1.log
   ```

## Files

- `cloud-init.yaml`: Cloud-init configuration template
- `variables.tf`: Terraform variables including benchmark coordinator settings
- `db-resources.tf`: EC2 instance configuration with user_data
- `terraform.tfvars.example`: Example configuration file

