data "rediscloud_payment_method" "card" {
  card_type         = "Visa"
  last_four_numbers = data.external.env.result["rediscloud_payment_4digits"]
}

data "rediscloud_cloud_account" "account" {
  exclude_internal_account = true
  provider_type            = "AWS"
  name                     = "PERFORMANCE"
}


resource "rediscloud_subscription" "subscription-resource" {

  name              = var.subscription_name
  payment_method    = "credit-card"
  payment_method_id = data.rediscloud_payment_method.card.id
  memory_storage    = "ram"

  cloud_provider {
    cloud_account_id = data.rediscloud_cloud_account.account.id
    region {
      region                       = "us-east-2"
      networking_deployment_cidr   = "10.3.11.0/24"
      networking_vpc_id = "${data.terraform_remote_state.shared_resources.outputs.performance_cto_vpc_id}"
      preferred_availability_zones = ["us-east-2a"]
    }
  }

  // This block needs to be defined for provisioning a new subscription.
  // This allows creating a well-optimised hardware specification for databases in the cluster
  creation_plan {
    average_item_size_in_bytes   = 1000
    memory_limit_in_gb           = 5
    quantity                     = 1
    replication                  = false
    support_oss_cluster_api      = true
    throughput_measurement_by    = "operations-per-second"
    throughput_measurement_value = var.ops_sec
    modules                      = []
  }
}


// The primary database to provision
resource "rediscloud_subscription_database" "database-resource" {
  subscription_id                       = rediscloud_subscription.subscription-resource.id
  name                                  = var.db_name
  protocol                              = "redis"
  memory_limit_in_gb                    = 5
  data_persistence                      = "none"
  password                              = data.external.env.result["rediscloud_default_password"]
  throughput_measurement_by             = "operations-per-second"
  throughput_measurement_value          = var.ops_sec
  support_oss_cluster_api               = true
  external_endpoint_for_oss_cluster_api = false
  replication                           = false
  depends_on                            = [rediscloud_subscription.subscription-resource]
}
