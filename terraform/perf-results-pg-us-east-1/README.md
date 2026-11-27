# perf-results-pg-us-east-1

A small private PostgreSQL for benchmark results and top-down (TMA) runs, shared by the performance team's
agents and workstations. Benchmarks account, us-east-1, the account's default VPC (where the benchmark VMs
run). No Twingate and no public endpoint: workstations reach it through SSM port forwarding, VMs directly.

| piece | what |
|---|---|
| RDS PostgreSQL 18, `db.t4g.small`, single AZ | gp3 20 GiB (autoscaling to 100), encrypted, TLS only, IAM authentication, 7-day backups, deletion protection, final snapshot |
| `dbadmin` | master user; password managed by RDS in Secrets Manager. Used once to create roles and databases, never by clients |
| roles `writer` / `reader` | log in with IAM tokens (`rds_iam`); policies `…-connect-writer` / `…-connect-reader` for non-admin principals |
| bastion `t4g.nano`, Amazon Linux 2023 | Session Manager only: no SSH, no key pair, no inbound rule |
| security groups | 5432 from the bastion and from `client_security_group_ids` (the benchmark VMs' group); nothing else |

About $30/month at list prices: about $24 for the database, $3 for its storage and $3 for the bastion.

## Apply

```bash
cd terraform/perf-results-pg-us-east-1
AWS_PROFILE=bench terraform init
AWS_PROFILE=bench terraform plan -out p.tfplan
AWS_PROFILE=bench terraform apply p.tfplan
```

## Out of band, once: roles and databases

```bash
export AWS_PROFILE=bench AWS_REGION=us-east-1
$(terraform output -raw tunnel_command) &                       # localhost:15432 -> the database
export PGPASSWORD=$(aws secretsmanager get-secret-value --secret-id "$(terraform output -raw master_secret_arn)" \
  --query SecretString --output text | jq -r .password)
psql "host=localhost port=15432 dbname=postgres user=dbadmin sslmode=require" <<'SQL'
CREATE ROLE writer LOGIN; GRANT rds_iam TO writer;
CREATE ROLE reader LOGIN; GRANT rds_iam TO reader;
SQL
```

Each project gets its own database, owned by `writer`, with `reader` granted `CONNECT` and `SELECT`. Create it in
one `dbadmin` session. PostgreSQL 16+ requires `dbadmin` to be a member of `writer` for `OWNER writer`, and RDS
makes any member of `rds_iam`, even through another role, log in with an IAM token: leave `writer` before
disconnecting, or `dbadmin` stops accepting its password (log in with
`aws rds generate-db-auth-token --username dbadmin` and run the `REVOKE` to recover).

```sql
GRANT writer TO dbadmin;
CREATE DATABASE <project> OWNER writer;
REVOKE ALL ON DATABASE <project> FROM PUBLIC;
GRANT CONNECT, TEMPORARY ON DATABASE <project> TO reader;
REVOKE writer FROM dbadmin;
```

Then, as `writer` (see Connect) in `<project>`, so `reader` can read what `writer` creates:

```sql
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO reader;
```

## Connect

```bash
export AWS_PROFILE=bench AWS_REGION=us-east-1
$(terraform output -raw tunnel_command) &
TOKEN=$(aws rds generate-db-auth-token --hostname "$(terraform output -raw endpoint)" --port 5432 --username reader)
PGPASSWORD="$TOKEN" psql "host=localhost port=15432 dbname=<project> user=reader sslmode=require"
```

The token is valid for 15 minutes, for new connections only. Tunnelled, the server certificate names the RDS
endpoint, not localhost, so use `sslmode=require` (encrypted, name not verified). From a VM in the default VPC,
connect to the endpoint directly with `sslmode=verify-full` and the RDS CA bundle.

## Teardown

`terraform destroy` fails on purpose: the database has `prevent_destroy` and deletion protection, and the
bastion has termination protection. To retire it, lift both, keep the final snapshot, then destroy.
