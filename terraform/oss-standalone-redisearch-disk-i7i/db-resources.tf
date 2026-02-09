resource "aws_instance" "server" {
  count         = var.server_instance_count
  ami           = var.instance_ami
  instance_type = var.server_instance_type

  subnet_id                   = data.terraform_remote_state.shared_resources.outputs.subnet_public_id
  vpc_security_group_ids      = ["${data.terraform_remote_state.shared_resources.outputs.performance_cto_sg_id}"]
  key_name                    = var.key_name
  associate_public_ip_address = "true"
  #placement_group             = data.terraform_remote_state.shared_resources.outputs.perf_cto_pg_name
  availability_zone           = "us-east-2a"

  cpu_options {
    core_count       = var.server_instance_cpu_core_count
    threads_per_core = var.server_instance_cpu_threads_per_core
  }

  root_block_device {
    volume_size           = var.instance_volume_size
    volume_type           = var.instance_volume_type
    encrypted             = var.instance_volume_encrypted
    delete_on_termination = true
  }

  volume_tags = {
    Environment    = "${var.environment}"
    Project        = "${var.environment}"
    Name           = "ebs_block_device-${var.setup_name}-DB-${count.index + 1}"
    setup          = "${var.setup_name}"
    triggering_env = "${var.triggering_env}"
    github_actor   = "${var.github_actor}"
    github_org     = "${var.github_org}"
    github_repo    = "${var.github_repo}"
    github_sha     = "${var.github_sha}"
    timeout_secs   = "${var.timeout_secs}"
  }

  tags = {
    Environment    = "${var.environment}"
    Project        = "${var.environment}"
    Name           = "${var.setup_name}-DB-${count.index + 1}"
    setup          = "${var.setup_name}"
    triggering_env = "${var.triggering_env}"
    github_actor   = "${var.github_actor}"
    github_org     = "${var.github_org}"
    github_repo    = "${var.github_repo}"
    github_sha     = "${var.github_sha}"
    timeout_secs   = "${var.timeout_secs}"
  }

  ################################################################################
  # Deployment related
  ################################################################################
}

################################################################################
# Flash storage setup via remote-exec
################################################################################
resource "null_resource" "flash_setup" {
  count = var.server_instance_count

  depends_on = [aws_instance.server]

  # Trigger re-run when the script changes
  triggers = {
    script_hash = filemd5("${path.module}/prepare_flash.sh")
    instance_id = aws_instance.server[count.index].id
  }

  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(var.private_key)
    host        = aws_instance.server[count.index].public_ip
    timeout     = "10m"
  }

  provisioner "file" {
    source      = "${path.module}/prepare_flash.sh"
    destination = "/tmp/prepare_flash.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/prepare_flash.sh",
      "sudo /tmp/prepare_flash.sh",
      "echo 'Flash setup completed'",
      "df -h /mnt/flash"
    ]
  }
}

################################################################################
# Polar Signals Parca agent configuration via remote-exec (optional)
################################################################################
resource "null_resource" "parca_agent_setup" {
  count = var.enable_parca_agent ? var.server_instance_count : 0

  depends_on = [aws_instance.server]

  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(var.private_key)
    host        = aws_instance.server[count.index].public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "#!/bin/bash",
      "set -e",
      "echo '=== Installing Parca Agent ==='",
      "sudo snap install parca-agent --classic",
      "echo '=== Configuring Parca Agent Token ==='",
      "sudo snap set parca-agent remote-store-bearer-token='${var.parca_agent_token}'",
      "echo '=== Verifying Token Configuration ==='",
      "TOKEN=$(sudo snap get parca-agent remote-store-bearer-token)",
      "if [ -z \"$TOKEN\" ]; then echo 'ERROR: Parca agent token not properly set!'; exit 1; fi",
      "echo \"Token configured (first 20 chars): $${TOKEN:0:20}...\"",
      "echo '=== Creating Parca Agent Relabel Config ==='",
      "cat <<'EOF' | sudo tee /etc/parca-agent.yml > /dev/null",
      "relabel_configs:",
      "  - source_labels: [__meta_thread_id]",
      "    target_label: thread_id",
      "  - source_labels: [__meta_thread_comm]",
      "    target_label: thread_name",
      "  - source_labels: [__meta_process_pid]",
      "    target_label: pid",
      "  - source_labels: [__meta_process_executable_name]",
      "    regex: \"^redis-server$\"",
      "    action: keep",
      "EOF",
      "echo '=== Setting Config Path ==='",
      "sudo snap set parca-agent config-path=/etc/parca-agent.yml",
      "echo '=== Starting Parca Agent ==='",
      "sudo snap start --enable parca-agent",
      "echo '=== Waiting for Parca Agent to Initialize ==='",
      "sleep 5",
      "echo '=== Parca Agent Logs ==='",
      "sudo snap logs parca-agent || true",
      "echo '=== Checking for PermissionDenied Errors ==='",
      "if sudo snap logs parca-agent 2>/dev/null | grep -q 'PermissionDenied'; then echo 'ERROR: Parca agent has PermissionDenied errors!'; exit 1; fi",
      "echo '=== Checking for Successful Attachment ==='",
      "if sudo snap logs parca-agent 2>/dev/null | grep -q 'Attached tracer program'; then echo 'SUCCESS: Parca Agent Started'; else echo 'WARNING: May not have attached'; fi",
      "echo '=== Saving logs ==='",
      "sudo snap logs parca-agent 2>/dev/null | sudo tee /var/log/parca-agent-init.log || true",
    ]
  }
}
