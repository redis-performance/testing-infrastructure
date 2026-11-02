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
