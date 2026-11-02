# oss-proxy-us-east-2 (benchmarks.redislabs.com-PROXY-2)

Side-by-side replacement for `benchmarks.redislabs.com-PROXY-1` (Ubuntu 16.04, HAProxy 1.8,
`terraform/benchmarks_redislabs_infrastructure`). Ubuntu 24.04, HAProxy 3.2 (ppa:vbernat/haproxy-3.2), same subnet
and security group. No EIP yet: PROXY-1 keeps `18.116.150.197` until a deliberate cutover.

## State
- HAProxy 3.2 runs PROXY-1's live `haproxy.cfg` unchanged and its TLS cert (copied by hand; not in git).
- All 10 listeners (3000, 8125, 8443, 11999-12012, 15000, 15001) answer the same as PROXY-1 (checked with a
  PING / HTTP probe against both).
- `15000` -> the oss-api host cannot work until the EIP moves: `benchmarks.redislabs.sg` only admits PROXY-1's EIP on
  35000 (`terraform/oss-api-us-east-1`).
- Request mirroring (SPOE + `haproxytech/spoa-mirror`) is NOT set up yet.

## Cutover (at a quiet time: the RTS ports hold long-lived benchmark connections)
1. Check `ss -tn state established` on PROXY-1 for 12000/12010/12011.
2. Move the EIP (`eipalloc-0b47bbade74616b3c`) to PROXY-2 and update `benchmarks_redislabs_infrastructure`
   (`aws_eip_association.proxy_eip_assoc`) to match, so Terraform does not move it back.
3. Re-run the probes; keep PROXY-1 until you are sure. Rollback = move the EIP back.

## Status: cut over (2026-11-02)
`benchmarks-redislabs-eip` (`18.116.150.197`) is on PROXY-2 (`aws_eip_association.proxy`). PROXY-1
(`i-0413b2ea2e7b3583f`, `terraform/benchmarks_redislabs_infrastructure`) is kept running, unchanged and with
termination protection, as the rollback target for at least 24 h. PROXY-2 has no other public IP and PROXY-1 has none
now, so reach PROXY-1 through the jumpbox at `10.3.0.83`.

### Rollback (swap back)
```
aws ec2 associate-address --region us-east-2 --allocation-id eipalloc-0b47bbade74616b3c \
  --instance-id i-0413b2ea2e7b3583f --allow-reassociation
terraform state rm aws_eip_association.proxy   # in this dir, so a later apply does not move it again
```
Long-lived RTS connections drop on every swap, as they did at the cutover.

### Request mirroring
`config/`: `haproxy.cfg` (PROXY-1's config + the `:15000` SPOE filter and `mirroragents` backend),
`spoe-mirror.cfg`, `spoa-mirror.service`. The agent is `haproxytech/spoa-mirror` v1.2.21 (commit `18e272a`) built
from source into `/usr/local/bin`. Only `POST /api/gh/redis/redis/commits` is copied; headers (including the
`X-Hub-Signature-256`) and body are preserved. **The target is still a local test sink**
(`-u http://127.0.0.1:18080/` in the unit): point it at the real listener and `systemctl restart spoa-mirror`.
