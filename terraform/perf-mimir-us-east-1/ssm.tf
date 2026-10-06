# Per-tenant limit overrides, as Mimir's runtime configuration. Not secret. The server copies it into
# /etc/mimir/runtime.yaml every 5 minutes and Mimir reloads it, so a change applies without replacing the
# instance. The credential hashes (htpasswd/push, htpasswd/read) are SecureString parameters written out of
# band, never by Terraform (they'd be in the state).
resource "aws_ssm_parameter" "runtime_overrides" {
  name        = "${local.ssm_prefix}/runtime-overrides"
  description = "Mimir per-tenant limit overrides (runtime config)"
  type        = "String"
  value       = yamlencode({ overrides = var.tenant_limits })
  tags        = local.tags
}
