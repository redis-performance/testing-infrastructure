# Agent guidelines

Instructions for AI coding agents (Claude Code, Copilot, Cursor, etc.) working in this repo.

## Project overview

`testing-infrastructure` provisions and manages the AWS-based performance testing infrastructure used by the Redis performance team. It is a collection of Terraform root modules (one per subdirectory under `terraform/`) that spin up golden images, benchmark client VMs, Redis OSS/RE server setups, and shared networking resources (VPC, security groups, placement groups, EIPs). Each module stores its state in a shared S3 backend (`performance-cto-group`) and reads shared networking outputs via `terraform_remote_state`. There is no application code -- the repo is pure Infrastructure-as-Code (HCL) plus helper shell scripts that install Redis, memtier_benchmark, and other benchmark tooling onto the provisioned VMs.

## Local setup

### Prerequisites

- [awscli](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) installed and configured
- [Terraform](https://releases.hashicorp.com/terraform/0.13.5/terraform_0.13.5_linux_amd64.zip) (>= 0.13.5) on `$PATH`
- [ansible](https://docs.ansible.com/ansible/latest/installation_guide/index.html) installed
- SSH key pair at `~/.ssh/perf-ci.pem` (private) and `~/.ssh/perf-ci.pub` (public)

```bash
# Clone including the automata submodule
git clone --recurse-submodules git@github.com:redis-performance/testing-infrastructure.git
cd testing-infrastructure

# Install system dependencies (zip, and Terraform 0.13.5 if not found)
./install_deps.sh
```

Required environment variables (needed by every Terraform module):

```bash
export EC2_REGION=us-east-2
export EC2_ACCESS_KEY=<aws-access-key-id>
export EC2_SECRET_KEY=<aws-secret-access-key>
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES   # macOS only
```

## Branch naming

Same as human contributors: `<type>/<short-description>` (e.g. `fix/off-by-one-in-pipeline`).

## Coding standards

- Match the style already in the file you are editing.
- Prefer clear, minimal changes over large refactors unless explicitly asked.
- Do not add comments that describe *what* the code does -- only add comments when the *why* is non-obvious.
- Do not introduce new dependencies without checking with the maintainer.
- Variable defaults, resource tags, and backend bucket/key paths must match the naming convention of the surrounding modules.

## Running tests / validation

There is no automated unit-test suite. Validate every module you touch with:

```bash
cd terraform/<setup-name>
terraform init
terraform validate
terraform plan
```

`terraform validate` must exit 0. `terraform plan` must complete without errors and the planned diff must match the intended change. Always run this before declaring a task complete.

## How to submit changes

1. Create a branch: `git checkout -b <type>/<description>`.
2. Commit with a clear message focused on *why*, not *what*.
3. Open a pull request against `master`.
4. Do **not** push directly to `master`.

## What to avoid

- Do not reformat files unrelated to your change.
- Do not remove error handling or provisioner blocks.
- Do not commit secrets, credentials, `.pem` keys, or large binary files.
- Do not amend published commits.
- Do not change the S3 backend bucket (`performance-cto-group`) or state key paths -- these are shared across the team and a wrong change will corrupt remote state.
- Do not run `terraform apply` or `terraform destroy` in CI/automation contexts without explicit maintainer instruction; these commands provision or destroy real AWS infrastructure.
