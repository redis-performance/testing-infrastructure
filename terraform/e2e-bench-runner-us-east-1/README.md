# e2e-bench-runner-us-east-1

A self-hosted GitHub Actions runner host for long end-to-end benchmark jobs. GitHub-hosted runners stop a
job at 6 hours; a self-hosted runner's job can run for up to 5 days (AWS credentials from GitHub OIDC
still cap a single session at the role's MaxSessionDuration, at most 12 h).

- **Size:** m7i.8xlarge (32 vCPU, 128 GiB), 1 TB gp3 root. That's the same size as
  `terraform/github-runner-cloud-benchmarks`.
- **Runners:** `runner_count` (default 20) actions/runner processes, each running one job at a time.
- **Isolation:** each runner runs as its own user (`runner01`, `runner02`, ...), with a 0700 home and no
  sudo, so concurrent jobs can't read each other's environment, temp files, kubeconfigs or caches.
  - Each runner's work dir is emptied after every job (a job-completed hook); its tool and action caches
    are kept.
  - Runner users can't reach the instance metadata service (an iptables owner rule on their `runners`
    group, applied before networking at boot; each runner's systemd unit requires it), so no job gets the
    instance role.
  - Each runner's unit runs with a private `/tmp` and can't see other users' processes
    (`PrivateTmp`, `ProtectProc=invisible`). `register.sh` writes the units itself, so root never runs a
    file a job could have changed.
  - After each job the hook also removes credentials a job may leave in the runner user's home (`~/.kube`,
    `~/.aws`, `~/.docker/config.json`, `~/.git-credentials`, `~/.netrc`, `~/.config/gh`).
  - Runners update themselves, as GitHub requires, so a job can modify its *own* runner's install: treat
    each runner as trusted by every later job on it.
- **Network:** a security group with no ingress, and a fixed egress EIP (output `egress_ip`).
  Administration is via Session Manager only.
- **AWS access:** the instance role allows Session Manager and this host's own SSM parameter, nothing
  else. Workflows bring their own AWS credentials (GitHub OIDC).
- **Alarms:** a system status failure recovers the instance onto new hardware, and an instance status
  failure notifies only. Pass `-var alarm_email=...` to get email.
- **Tags:** `team = performance_analysis_optimization`, `owner = github_actor` (default
  `filipe_oliveira`), plus `Environment` and `setup`.
- **Cost:** about $1,260/month on demand: the instance about $1,177, the gp3 volume about $82, the EIP
  about $4.

**Register these runners to private repositories only.** On a public repository, a pull request from a
fork could run code on them.

## Apply

```bash
cd terraform/e2e-bench-runner-us-east-1
AWS_PROFILE=bench terraform init
AWS_PROFILE=bench terraform apply [-var alarm_email=you@example.com]
```

The bootstrap installs the runners but doesn't register them. To check that it finished:

```bash
ID=$(AWS_PROFILE=bench terraform output -raw instance_id)
AWS_PROFILE=bench aws ssm describe-instance-information --region us-east-1 \
  --filters Key=InstanceIds,Values=$ID --query 'InstanceInformationList[0].PingStatus'
CMD=$(AWS_PROFILE=bench aws ssm send-command --region us-east-1 --instance-ids "$ID" \
  --document-name AWS-RunShellScript --parameters 'commands=["cloud-init status; tail -3 /var/log/runner-init.log"]' \
  --query Command.CommandId --output text)
AWS_PROFILE=bench aws ssm wait command-executed --region us-east-1 --instance-id "$ID" --command-id "$CMD" || true
AWS_PROFILE=bench aws ssm get-command-invocation --region us-east-1 --instance-id "$ID" --command-id "$CMD" \
  --query '[Status,StandardOutputContent,StandardErrorContent]' --output text
```

The log ends with `runner-init done` when it's ready.

## Register the runners

Registration needs a repository (or organization) admin. The token is short-lived (1 h) and can only
register runners. It goes straight from `gh` into an SSM SecureString, never into a shell variable or a
command line. `register.sh` reads it, deletes it when it exits, and hands the token to each runner's
`config.sh` through its environment.

```bash
REPO=<owner>/<repo>
PARAM=$(AWS_PROFILE=bench terraform output -raw registration_parameter)
gh api -X POST "repos/$REPO/actions/runners/registration-token" |
  jq --arg url "https://github.com/$REPO" --arg labels "self-hosted,linux,x64,<your-label>" \
     --arg name_prefix "<host-name>" '{url:$url, token:(.token // error("no token")), labels:$labels, name_prefix:$name_prefix}' |
  AWS_PROFILE=bench aws ssm put-parameter --region us-east-1 --name "$PARAM" --type SecureString \
      --value file:///dev/stdin --overwrite
CMD=$(AWS_PROFILE=bench aws ssm send-command --region us-east-1 --instance-ids "$ID" \
  --document-name AWS-RunShellScript --parameters 'commands=["/opt/actions-runner/register.sh"]' \
  --query Command.CommandId --output text)
AWS_PROFILE=bench aws ssm wait command-executed --region us-east-1 --instance-id "$ID" --command-id "$CMD" || true
AWS_PROFILE=bench aws ssm get-command-invocation --region us-east-1 --instance-id "$ID" --command-id "$CMD" \
  --query '[Status,StandardOutputContent,StandardErrorContent]' --output text   # ends with "registered: N runners"
gh api --paginate "repos/$REPO/actions/runners" --jq '.runners[] | "\(.name) \(.status) \(.busy)"'
```

- **Waiting:** `wait command-executed` gives up after 100 s; registering 20 runners can take longer, so re-run the wait and the `get-command-invocation` until the status is `Success`.
- **Re-running:** `register.sh` registers and starts only the runners that aren't registered yet, so
  running it again (with a fresh parameter) is safe. It refuses while a job is running.
- **Targeting:** a workflow uses the runners with `runs-on: [self-hosted, <your-label>]`.

## Replace or remove

Changes to the bootstrap, the AMI or `runner_count` don't replace the host on their own: jobs can run
for days, and a replacement drops every registered runner. To replace the host, once its runners are
idle, run:

```bash
AWS_PROFILE=bench terraform apply -replace=aws_instance.runner
```

Then deregister the old runners and register the new ones. To deregister (they also show offline in
Settings → Actions → Runners):

```bash
gh api --paginate "repos/$REPO/actions/runners" --jq '.runners[] | select(.name|startswith("<host-name>-")) | .id' |
  while read -r id; do gh api -X DELETE "repos/$REPO/actions/runners/$id"; done
```

`terraform destroy` lifts the termination protection itself (`force_destroy`), and the EIP is released
with it. Deregister the runners first.
