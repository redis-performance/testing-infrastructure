
resource "aws_placement_group" "flex_cluster" {
  name     = var.placement_group
  strategy = "cluster"
}

resource "aws_instance" "server_2a" {
  count                  = var.server_instance_count
  ami                    = var.instance_ami
  instance_type          = var.server_instance_type
  subnet_id              = "subnet-e85eb4c2"
  vpc_security_group_ids = ["sg-046d72511dd949d2b"]
  key_name               = var.key_name
  placement_group        = aws_placement_group.flex_cluster.name
  availability_zone      = "us-east-1a"

  root_block_device {
    volume_size           = var.instance_volume_size
    volume_type           = var.instance_volume_type
    encrypted             = var.instance_volume_encrypted
    delete_on_termination = true
  }

  volume_tags = {
    Environment    = "${var.environment}"
    Project        = "${var.environment}"
    Name           = "ebs_block_device-${var.setup_name}-${count.index + 1}"
    setup          = "${var.setup_name}"
    triggering_env = "${var.triggering_env}"
    github_actor   = "${var.github_actor}"
    github_org     = "${var.github_org}"
    github_repo    = "${var.github_repo}"
    github_sha     = "${var.github_sha}"
    team           = "performance_analysis_optimization"
    owner          = "${var.github_actor}"
  }

  tags = {
    Environment    = "${var.environment}"
    Project        = "${var.environment}"
    Name           = "${var.setup_name}-${count.index + 1}"
    setup          = "${var.setup_name}"
    triggering_env = "${var.triggering_env}"
    github_actor   = "${var.github_actor}"
    github_org     = "${var.github_org}"
    github_repo    = "${var.github_repo}"
    github_sha     = "${var.github_sha}"
    team           = "performance_analysis_optimization"
    owner          = "${var.github_actor}"
  }

  ################################################################################
  # This will ensure we wait here until the instance is ready to receive the ssh connection
  ################################################################################
  provisioner "remote-exec" {
    script = "./wait_for_instance.sh"
    connection {
      host        = self.public_ip # The `self` variable is like `this` in many programming languages
      type        = "ssh"          # in this case, `self` is the resource (the server).
      user        = var.ssh_user
      private_key = file(var.private_key)
      #need to increase timeout to larger then 5m for metal instances
      timeout = "15m"
      agent   = "false"
    }
  }


  ################################################################################
  # Copy license file to node 1
  ################################################################################
  provisioner "file" {
    source      = count.index == 0 ? pathexpand(var.license_file) : "/dev/null"
    destination = "/tmp/license.txt"

    connection {
      host        = self.public_ip
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.private_key)
      timeout     = "15m"
      agent       = "false"
    }
  }


  ################################################################################
  # Install RS
  ################################################################################
  provisioner "remote-exec" {
    inline = [
      "echo 'Starting benchmark tools installation...'",

      # Install prerequisites for Redis repository
      "sudo apt-get update",
      "sudo apt-get install -y --no-install-recommends wget ${var.tune_network ? "ethtool" : ""}",

      # Configure network interface interrupt coalescing (conditional)
      "${var.tune_network ? "IFACE=$(ip link show | grep -E '^[0-9]+: (eth|ens|eno|enp)' | head -1 | awk -F': ' '{print $2}')" : "echo 'Network tuning disabled'"}",
      "${var.tune_network ? "echo \\\"Configuring network interface: $IFACE\\\"" : ":"}",
      "${var.tune_network ? "sudo ethtool -C $IFACE rx-usecs ${var.rx_usecs} tx-usecs ${var.tx_usecs} adaptive-rx ${var.adaptive_rx} || echo 'ethtool configuration failed or not supported'" : ":"}",
      "${var.tune_network ? "echo 'Final ethtool configuration for $IFACE:...'" : ":"}",
      "${var.tune_network ? "sudo ethtool -c $IFACE" : ":"}",

      # Install netdata for monitoring
      "wget -O /tmp/netdata-kickstart.sh https://get.netdata.cloud/kickstart.sh && sh /tmp/netdata-kickstart.sh --no-updates --disable-telemetry --non-interactive",

      # get RS and install it
      "wget -O /tmp/re.tar https://s3.us-east-1.amazonaws.com/benchmarks.redislabs/artifacts/redis-enterprise/cloud-benchmarks/redislabs-${var.rs_version}-${var.rs_build}-jammy-${var.rs_arch}.tar",
      #"wget -O /tmp/re.tar https://s3.amazonaws.com/redis-enterprise-software-downloads/${var.rs_version}/redislabs-${var.rs_version}-${var.rs_build}-jammy-${var.rs_arch}.tar",
      "cd /tmp",
      "sudo tar vxf /tmp/re.tar",
      "echo 'DNSStubListener=no' | sudo tee -a /etc/systemd/resolved.conf",
      "sudo mv /etc/resolv.conf /etc/resolv.conf.orig",
      "sudo ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf",
      "sudo service systemd-resolved restart",
      "sudo /tmp/install.sh -y",
      "sudo /opt/redislabs/sbin/prepare_flash.sh",

      "echo 'Redis Enterprise installation completed successfully!'"
    ]

    connection {
      host        = self.public_ip
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.private_key)
      timeout     = "15m"
      agent       = "false"
    }
  }

  ################################################################################
  # Copy and run XFS setup script (replaces ext4 with XFS + 256K chunks + 20% OP)
  ################################################################################
  provisioner "file" {
    source      = "${path.module}/setup_xfs.sh"
    destination = "/tmp/setup_xfs.sh"

    connection {
      host        = self.public_ip
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.private_key)
      timeout     = "5m"
      agent       = "false"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/setup_xfs.sh",
      "sudo /tmp/setup_xfs.sh"
    ]

    connection {
      host        = self.public_ip
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.private_key)
      timeout     = "30m"
      agent       = "false"
    }
  }
}


################################################################################
# Client instances
################################################################################

resource "aws_instance" "client" {
  count                  = var.client_instance_count
  ami                    = var.instance_ami
  instance_type          = var.client_instance_type
  subnet_id              = "subnet-e85eb4c2"
  vpc_security_group_ids = ["sg-046d72511dd949d2b"]
  key_name               = var.key_name
  availability_zone      = "us-east-1a"

  root_block_device {
    volume_size           = var.instance_volume_size
    volume_type           = var.instance_volume_type
    encrypted             = var.instance_volume_encrypted
    delete_on_termination = true
  }

  volume_tags = {
    Environment    = "${var.environment}"
    Project        = "${var.environment}"
    Name           = "ebs_block_device-${var.setup_name}-client-${count.index + 1}"
    setup          = "${var.setup_name}"
    triggering_env = "${var.triggering_env}"
    github_actor   = "${var.github_actor}"
    github_org     = "${var.github_org}"
    github_repo    = "${var.github_repo}"
    github_sha     = "${var.github_sha}"
    team           = "performance_analysis_optimization"
    owner          = "${var.github_actor}"
  }

  tags = {
    Environment    = "${var.environment}"
    Project        = "${var.environment}"
    Name           = "${var.setup_name}-client-${count.index + 1}"
    setup          = "${var.setup_name}"
    triggering_env = "${var.triggering_env}"
    github_actor   = "${var.github_actor}"
    github_org     = "${var.github_org}"
    github_repo    = "${var.github_repo}"
    github_sha     = "${var.github_sha}"
    team           = "performance_analysis_optimization"
    owner          = "${var.github_actor}"
  }

  provisioner "remote-exec" {
    script = "./wait_for_instance.sh"
    connection {
      host        = self.public_ip
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.private_key)
      timeout     = "15m"
      agent       = "false"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "echo 'Client setup completed successfully!'"
    ]

    connection {
      host        = self.public_ip
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.private_key)
      timeout     = "15m"
      agent       = "false"
    }
  }
}

################################################################################
# Cluster setup and database creation (runs after RS installation)
################################################################################

resource "null_resource" "cluster_setup" {
  count      = var.server_instance_count
  depends_on = [aws_instance.server_2a]

  provisioner "remote-exec" {
    inline = [
      # Restart RS after XFS setup (setup_xfs.sh stops rlec_supervisor)
      "sudo systemctl start rlec_supervisor",
      "echo 'Waiting for RS to start...'",
      "sleep 30",

      # create cluster (only on node 1)
      "${count.index == 0 ? "sudo /opt/redislabs/bin/rladmin cluster create name ${var.cluster_name} username ${var.rs_username} password ${var.rs_password} flash_enabled flash_path /var/opt/redislabs/flash license_file /tmp/license.txt" : "echo 'Skipping cluster creation on node ${count.index + 1}'"}",

      "${count.index > 0 ? "sudo /opt/redislabs/bin/rladmin cluster join nodes ${aws_instance.server_2a[0].private_ip} username ${var.rs_username} password ${var.rs_password} flash_enabled flash_path /var/opt/redislabs/flash" : "echo 'Skipping cluster join on node ${count.index + 1}'"}",

      # get cluster info
      "sudo /opt/redislabs/bin/rladmin status",

      # setup proxy
      "sudo  /opt/redislabs/bin/rladmin tune proxy all threads ${var.proxy_threads} max_threads ${var.proxy_threads}",

      "sudo /opt/redislabs/bin/dmc_ctl restart",

      # Wait for cluster to be ready
      "sleep 10",

      "echo 'Cluster setup completed successfully!'"
    ]

    connection {
      host        = aws_instance.server_2a[count.index].public_ip
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.private_key)
      timeout     = "15m"
      agent       = "false"
    }
  }
}

################################################################################
# Speedb/bigredis tuning (runs after cluster setup, before DB creation)
################################################################################

resource "null_resource" "bigredis_config" {
  count      = var.server_instance_count
  depends_on = [null_resource.cluster_setup]

  provisioner "remote-exec" {
    inline = [
      "echo 'Appending bigredis driver config (idempotent)...'",
      "grep -q 'level0_file_num_compaction_trigger 16' /opt/redislabs/config/redis/redis-base-8.4-big2.conf || echo 'bigredis-driver-maincf-level0_file_num_compaction_trigger 16' | sudo tee -a /opt/redislabs/config/redis/redis-base-8.4-big2.conf",
      "grep -q 'level0_slowdown_writes_trigger 24' /opt/redislabs/config/redis/redis-base-8.4-big2.conf || echo 'bigredis-driver-maincf-level0_slowdown_writes_trigger 24' | sudo tee -a /opt/redislabs/config/redis/redis-base-8.4-big2.conf",
      "grep -q 'level0_stop_writes_trigger 60' /opt/redislabs/config/redis/redis-base-8.4-big2.conf || echo 'bigredis-driver-maincf-level0_stop_writes_trigger 60' | sudo tee -a /opt/redislabs/config/redis/redis-base-8.4-big2.conf",
      "grep -q 'write_buffer_size 1GB' /opt/redislabs/config/redis/redis-base-8.4-big2.conf || echo 'bigredis-driver-maincf-write_buffer_size 1GB' | sudo tee -a /opt/redislabs/config/redis/redis-base-8.4-big2.conf",
      "echo 'bigredis config updated:'",
      "tail -4 /opt/redislabs/config/redis/redis-base-8.4-big2.conf"
    ]

    connection {
      host        = aws_instance.server_2a[count.index].public_ip
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.private_key)
      timeout     = "15m"
      agent       = "false"
    }
  }
}

################################################################################
# DB setup (runs after bigredis config)
################################################################################

resource "null_resource" "db_setup" {
  count      = var.server_instance_count
  depends_on = [null_resource.bigredis_config]

  provisioner "remote-exec" {
    inline = [
      # Create database using REST API
      "SHARD_COUNT=${var.shard_count}",
      "MEMORY_SIZE=${var.memory_size}",
      "DB_PORT=${var.db_port}",
      "OSS_CLUSTER=${var.oss_cluster}",
      "REPLICATION=${var.replication}",
      "REDIS_VERSION=${var.redis_version}",
      "SHARDS_PLACEMENT=${var.shards_placement}",
      "DATA_PERSISTENCE=${var.data_persistence}",
      "TLS_MODE=${var.tls_mode}",
      "ENFORCE_CLIENT_AUTH=${var.enforce_client_authentication}",
      "BIGSTORE=${var.bigstore}",
      "BIGSTORE_RAM_SIZE=${var.bigstore_ram_size}",
      "SHARDING_ENABLED=false",
      "if [ $SHARD_COUNT -gt 1 ]; then SHARDING_ENABLED=true; fi",

      # create the DB
      "${count.index == 0 ? "curl -k -u '${var.rs_username}:${var.rs_password}' -X POST https://localhost:9443/v1/bdbs -H 'Content-Type: application/json' -d '{\"name\":\"NODES-1-SHARDS-'$SHARD_COUNT'\",\"port\":'$DB_PORT',\"type\":\"redis\",\"replication\":'$REPLICATION',\"memory_size\":'$MEMORY_SIZE',\"bigstore\":'$BIGSTORE',\"bigstore_ram_size\":'$BIGSTORE_RAM_SIZE',\"sharding\":'$SHARDING_ENABLED',\"redis_version\":\"'$REDIS_VERSION'\",\"shards_count\":'$SHARD_COUNT',\"oss_cluster\":'$OSS_CLUSTER',\"proxy_policy\":\"all-master-shards\",\"data_persistence\":\"'$DATA_PERSISTENCE'\",\"shards_placement\":\"'$SHARDS_PLACEMENT'\",\"tls_mode\":\"'$TLS_MODE'\",\"authentication_ssl_client_certs\":[],\"enforce_client_authentication\":\"'$ENFORCE_CLIENT_AUTH'\",\"shard_key_regex\":[{\"regex\":\".*\\\\{(?<tag>.*)\\\\}.*\"},{\"regex\":\"(?<tag>.*)\"}]}'" : "echo 'Skipping db creation on node ${count.index + 1}'"}",

      # Wait for database to be ready
      "sleep 5",

      # get cluster info
      "sudo /opt/redislabs/bin/rladmin status",

      # Verify database creation
      "curl -k -u '${var.rs_username}:${var.rs_password}' https://localhost:9443/v1/bdbs",

      "echo 'DB setup completed successfully!'"
    ]

    connection {
      host        = aws_instance.server_2a[count.index].public_ip
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.private_key)
      timeout     = "15m"
      agent       = "false"
    }
  }
}

################################################################################
# NUMA pinning (runs after DB setup)
# Half/half: split shards evenly across both sockets, each with local memory.
# DMC and network IRQs spread across both sockets.
################################################################################

resource "null_resource" "numa_pinning" {
  count      = var.server_instance_count
  depends_on = [null_resource.db_setup]

  provisioner "file" {
    source      = "${path.module}/numa_pinning.sh"
    destination = "/tmp/numa_pinning.sh"

    connection {
      host        = aws_instance.server_2a[count.index].public_ip
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.private_key)
      timeout     = "5m"
      agent       = "false"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/numa_pinning.sh",
      "sudo /tmp/numa_pinning.sh"
    ]

    connection {
      host        = aws_instance.server_2a[count.index].public_ip
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.private_key)
      timeout     = "15m"
      agent       = "false"
    }
  }
}

################################################################################
# Install memtier_benchmark on client nodes
################################################################################

resource "null_resource" "client_memtier" {
  count      = var.client_instance_count
  depends_on = [aws_instance.client]

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y build-essential autoconf automake libpcre3-dev libevent-dev pkg-config zlib1g-dev libssl-dev git",
      "cd /tmp && git clone https://github.com/RedisLabs/memtier_benchmark.git",
      "cd /tmp/memtier_benchmark && autoreconf -ivf && ./configure --enable-tls && make -j$(nproc) && sudo make install",
      "memtier_benchmark --version",
      "echo 'memtier_benchmark installed successfully!'"
    ]

    connection {
      host        = aws_instance.client[count.index].public_ip
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.private_key)
      timeout     = "15m"
      agent       = "false"
    }
  }
}

################################################################################
# Copy benchmark scripts to client nodes
################################################################################

resource "null_resource" "benchmark_scripts" {
  count      = var.client_instance_count
  depends_on = [null_resource.client_memtier, null_resource.numa_pinning]

  provisioner "file" {
    source      = "${path.module}/benchmark-fill.sh"
    destination = "/home/ubuntu/benchmark-fill.sh"

    connection {
      host        = aws_instance.client[count.index].public_ip
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.private_key)
      timeout     = "5m"
      agent       = "false"
    }
  }

  provisioner "file" {
    source      = "${path.module}/benchmark-workload.sh"
    destination = "/home/ubuntu/benchmark-workload.sh"

    connection {
      host        = aws_instance.client[count.index].public_ip
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.private_key)
      timeout     = "5m"
      agent       = "false"
    }
  }

  provisioner "file" {
    source      = "${path.module}/benchmark-all.sh"
    destination = "/home/ubuntu/benchmark-all.sh"

    connection {
      host        = aws_instance.client[count.index].public_ip
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.private_key)
      timeout     = "5m"
      agent       = "false"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/benchmark-fill.sh /home/ubuntu/benchmark-workload.sh /home/ubuntu/benchmark-all.sh",
      "echo 'Benchmark scripts deployed successfully!'"
    ]

    connection {
      host        = aws_instance.client[count.index].public_ip
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.private_key)
      timeout     = "5m"
      agent       = "false"
    }
  }
}
