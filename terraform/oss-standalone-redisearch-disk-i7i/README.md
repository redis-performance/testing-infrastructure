# OSS Standalone RediSearch M5 Setup

## Quick Setup with Parca Profiler

```bash
export TF_VAR_enable_parca_agent=true TF_VAR_parca_agent_token="your-token-here"
terraform init && terraform apply -auto-approve
```

## What This Does

- Deploys Redis server instances on AWS EC2 (m6i.8xlarge)
- Deploys benchmark client instances (m6i.4xlarge)
- Optionally installs and configures Parca agent for continuous profiling via remote-exec
- Parca agent filters to profile **only redis-server** processes
- **Full logs visible during terraform apply** - no need to SSH to check setup

## Parca Configuration

When `enable_parca_agent=true`, the setup uses **remote-exec provisioner** to:
- Install Parca agent via snap
- Configure bearer token for Polar Signals
- Create relabel config to capture thread/process metadata
- Filter profiling to redis-server only
- Verify no PermissionDenied errors (fails deployment if found)
- **Display all logs in terraform output** during apply
- Save logs to `/var/log/parca-agent-init.log` on the server

## Verify Parca Agent

```bash
ssh ubuntu@<server-ip>
sudo snap logs parca-agent
cat /var/log/parca-agent-init.log
```

### Expected Success Indicators
- `Attached tracer program` - eBPF profiler attached successfully
- `Attached sched monitor` - Scheduler monitoring active
- No `PermissionDenied` errors

### Benign Errors (Safe to Ignore)
- `Failed to load /snap/snapd/.../snap` - Normal snap filesystem limitation
- `Can't connect Containerd client` - Expected on non-container hosts

### Critical Errors (Will Fail Deployment)
- `PermissionDenied` - Invalid token or project access issue

## Troubleshooting

**PermissionDenied errors**: The remote-exec provisioner will automatically fail if PermissionDenied errors are detected. This usually means:
- Invalid or expired Parca agent token
- Token doesn't have access to the project
- Missing project ID configuration

Check token configuration:
```bash
sudo snap get parca-agent remote-store-bearer-token
```

**Deployment fails during Parca setup**: Check the terraform output for detailed logs showing exactly where the setup failed.

