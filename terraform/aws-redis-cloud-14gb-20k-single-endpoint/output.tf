
output "public_endpoint" {
  value = ["${rediscloud_subscription_database.database-resource.public_endpoint}"]
}

output "private_endpoint" {
  value = ["${rediscloud_subscription_database.database-resource.private_endpoint}"]
}

output "password" {
  value = ["${rediscloud_subscription_database.database-resource.password}"]
  sensitive = true
}
