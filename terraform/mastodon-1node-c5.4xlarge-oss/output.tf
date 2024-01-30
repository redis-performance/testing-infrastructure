output "public_ip" {
  value = ["${aws_instance.db[0].public_ip}"]
}

output "private_ip" {
  value = ["${aws_instance.db[0].private_ip}"]
}

