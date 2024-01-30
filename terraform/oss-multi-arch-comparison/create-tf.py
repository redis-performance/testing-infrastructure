def retrieve_text(instance_type):
    resource_name = instance_type.replace(".", "_")
    ami_type = """${var.instance_ami}"""
    if resource_name[:4].find("g") > 0:
        ami_type = """${var.instance_ami_arm64}"""
    res = (
        '''
resource "aws_instance" "'''
        + resource_name
        + '''" {
  count                  = "${var.db_instance_count}"
  ami                    = "'''
        + ami_type
        + '''"
  instance_type          = "'''
        + instance_type
        + """"
  subnet_id              = data.terraform_remote_state.shared_resources.outputs.subnet_public_id
  vpc_security_group_ids = ["${data.terraform_remote_state.shared_resources.outputs.performance_cto_sg_id}"]
  key_name               = "${var.key_name}"
  associate_public_ip_address = "true"
    availability_zone           = "us-east-2a"


  root_block_device {
    volume_size           = "${var.instance_volume_size}"
    volume_type           = "${var.instance_volume_type}"
    encrypted             = "${var.instance_volume_encrypted}"
    delete_on_termination = true
  }

  volume_tags = {
    Environment = "${var.environment}"
    Name        = "ebs_block_device-${var.setup_name}-"""
        + instance_type
        + """"
    setup        = "${var.setup_name}"
    triggering_env = "${var.triggering_env}"
    github_actor = "${var.github_actor}"
    github_org = "${var.github_org}"
    github_repo  = "${var.github_repo}"
    github_sha   = "${var.github_sha}"
    timeout_secs = "${var.timeout_secs}"
  }

  tags = {
    Environment = "${var.environment}"
    Name         = "${var.setup_name}-"""
        + instance_type
        + """"
    triggering_env = "${var.triggering_env}"
    github_actor = "${var.github_actor}"
    github_org = "${var.github_org}"
    github_repo  = "${var.github_repo}"
    github_sha   = "${var.github_sha}"
  }
}
"""
    )
    return res


def prepare_output_tf(vms):
    res = """
    output "client_public_ip" {
      value = ["${aws_instance.client[0].public_ip}"]
    }

    output "client_private_ip" {
      value = ["${aws_instance.client[0].private_ip}"]
    }
    """
    for vm in vms:
        vm = vm.replace(".", "_")
        res = (
            res
            + '''
        output "'''
            + vm
            + """_public_ip" {
        value = ["${aws_instance."""
            + vm
            + '''[0].public_ip}"]
        }

        output "'''
            + vm
            + """_private_ip" {
        value = ["${aws_instance."""
            + vm
            + """[0].private_ip}"]
        }
        """
        )
    return res


vms = [
    "c4.2xlarge",
    "c5.2xlarge",
    "c6i.2xlarge",
    "c6a.2xlarge",
    "c6g.2xlarge",
    "c7g.2xlarge",
    "r4.2xlarge",
    "r5.2xlarge",
    "r6i.2xlarge",
    "r6a.2xlarge",
    "r6g.2xlarge",
    # "r7iz.2xlarge", currently not supported
    "m4.2xlarge",
    "m5.2xlarge",
    "m6i.2xlarge",
    "m6a.2xlarge",
    "m6g.2xlarge",
]

with open("output.tf", "w") as fd:
    ouptut = prepare_output_tf(vms)
    fd.write(ouptut)

for vm in vms:
    ouptut = retrieve_text(vm)
    resource_name = vm.replace(".", "_")

    with open(resource_name + ".tf", "w") as fd:
        fd.write(ouptut)
