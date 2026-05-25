# Contributing

We treat this repo as "Open Source" within Redis: anyone who clears the bar below is welcome to contribute.

## Local setup

This repo manages Terraform configurations that provision AWS-based performance testing infrastructure (golden images, benchmark client VMs, Redis/RE server setups, and shared networking resources). Each subdirectory under `terraform/` is a self-contained Terraform root module.

### Prerequisites

- [awscli](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) installed and configured
- [Terraform](https://releases.hashicorp.com/terraform/0.13.5/terraform_0.13.5_linux_amd64.zip) (>= 0.13.5) installed and on `$PATH`
- [ansible](https://docs.ansible.com/ansible/latest/installation_guide/index.html) installed
- SSH key pair at `~/.ssh/perf-ci.pem` (private) and `~/.ssh/perf-ci.pub` (public) - request these from the team

```bash
# Clone the repo (including the automata submodule)
git clone --recurse-submodules git@github.com:redis-performance/testing-infrastructure.git
cd testing-infrastructure

# Install system dependencies (installs zip and, if needed, Terraform 0.13.5)
./install_deps.sh
```

### Required environment variables

Every Terraform module and Ansible script expects these variables to be set:

```bash
export EC2_REGION=us-east-2
export EC2_ACCESS_KEY=<your-aws-access-key-id>
export EC2_SECRET_KEY=<your-aws-secret-access-key>
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES   # macOS only -- harmless on Linux
```

### Working with a specific setup

Each directory under `terraform/` is an independent root module with its own remote S3 backend. To bring one up:

```bash
cd terraform/<setup-name>   # e.g. terraform/oss-standalone-amd64-ubuntu22.04-c6i.16xlarge
terraform init
terraform validate
terraform plan
terraform apply
```

To tear it down when done:

```bash
terraform destroy
```

## Branch naming

```
<type>/<short-description>
```

Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`

Example: `feat/add-pipeline-mode`

## Coding standards

- Keep changes focused; one logical change per PR.
- Follow the conventions already present in the codebase (formatting, naming, error handling).
- No dead code, no commented-out blocks.

## Submitting changes

1. Fork or create a branch from `master`.
2. Make your changes with clear, atomic commits.
3. Open a pull request against `master` with a descriptive title and summary.
4. Address review comments promptly; force-push to the same branch to update.

## Testing / validation

There is no automated unit-test suite; correctness is validated by linting and a dry-run plan. Before opening a PR, run the following against every module you touched:

```bash
cd terraform/<setup-name>
terraform init
terraform validate
terraform plan
```

`terraform validate` must exit 0. `terraform plan` must produce no errors and the diff must match your intent.

## Review process

- At least one maintainer approval is required before merge.
- CI must be green.
- Maintainers may request changes or close PRs that do not meet the bar -- this is normal and not personal.
