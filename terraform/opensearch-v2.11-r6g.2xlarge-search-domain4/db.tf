variable "domain_name" {
  description = "The name of the OpenSearch domain"
  type        = string
  default     = "vector-benchmark-d4" # You can override this value during `terraform apply`
}


data "aws_caller_identity" "current" {}

resource "aws_opensearch_domain" "example" {
  domain_name    = var.domain_name
  engine_version = "OpenSearch_2.11"

  cluster_config {
    instance_type = "r6g.2xlarge.search"
  }

  advanced_security_options {
    enabled                        = false
    anonymous_auth_enabled         = true
    internal_user_database_enabled = true
    master_user_options {
      master_user_name     = "opensearch"
      master_user_password = "Performance2025#"
    }
  }

  encrypt_at_rest {
    enabled = true
  }

  # The Action element in the policy is set to es:*, which means it allows all Amazon OpenSearch Service actions.
  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "es:*"
        Resource  = "arn:aws:es:us-east-2:${data.aws_caller_identity.current.account_id}:domain/${var.domain_name}/*"
      }
    ]
  })


  ebs_options {
    ebs_enabled = true
    volume_size = 360
  }


  domain_endpoint_options {
    enforce_https       = false
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  node_to_node_encryption {
    enabled = true
  }

  vpc_options {
    subnet_ids = [
      data.terraform_remote_state.shared_resources.outputs.subnet_public_id,
    ]

    security_group_ids = ["${data.terraform_remote_state.shared_resources.outputs.performance_cto_sg_id}"]
  }


  tags = {
    Domain  = var.domain_name
    Name    = "vector-benchmark-opensearch-v2-11"
    Project = "Vector-Competitive-OpenSearch"
  }
}
