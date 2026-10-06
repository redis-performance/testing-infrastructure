# Written by Terraform from `tenants`; not secret. The server reads both every 5 minutes, so a change applies
# without replacing the instance. The credential hashes (htpasswd/push, htpasswd/read) are SecureString
# parameters written out of band, never by Terraform (they'd be in the state).

# The tenants nginx admits users of, one per line.
resource "aws_ssm_parameter" "tenants" {
  name        = "${local.ssm_prefix}/tenants"
  description = "Mimir tenants (one per line); users of other tenants are refused"
  type        = "String"
  value       = join("\n", sort(keys(var.tenants)))
  tags        = local.tags
}

# Per-tenant limit overrides, as Mimir's runtime configuration (every tenant listed, {} for the defaults; the
# typed variable means only known limits with valid values get here). A Standard parameter holds 4 KB.
resource "aws_ssm_parameter" "runtime_overrides" {
  name        = "${local.ssm_prefix}/runtime-overrides"
  description = "Mimir per-tenant limit overrides (runtime config)"
  type        = "String"
  value       = yamlencode({ overrides = { for t, l in var.tenants : t => { for k, v in l : k => v if v != null } } })
  tags        = local.tags
}
