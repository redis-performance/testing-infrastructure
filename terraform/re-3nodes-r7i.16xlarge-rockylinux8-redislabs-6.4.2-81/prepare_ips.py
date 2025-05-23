import subprocess
import json

# Run the "terraform output json" command
output = subprocess.run(["terraform", "output", "-json"], stdout=subprocess.PIPE)

output_json = json.loads(output.stdout.decode())
total_nodes = len(output_json["server_private_ip"]["value"])

print("#!/bin/bash\n")
print("TOTAL_NODES={}\n".format(total_nodes))
suffix_len = len("perf-cto-RE-")
setup_name = output_json["setup_name"]["value"].replace(".", "-").replace("-", "-")
setup_name = setup_name[suffix_len:]
server_instance_type = output_json["server_instance_type"]["value"].replace(".", "-")
ssh_user = output_json["ssh_user"]["value"]


print('USER="{}"\n'.format(ssh_user))
print("PEM=/tmp/benchmarks.redislabs.pem\n")
print('CLUSTER_NAME="{}"\n'.format(setup_name))

print("\n#internal IP addresses")
cleaned_json = {}
for keyn, v in enumerate(output_json["server_private_ip"]["value"], start=1):
    print("B_M{}_I={}".format(keyn, v))

print("\n#external IP addresses")
for keyn, v in enumerate(output_json["server_public_ip"]["value"], start=1):
    print("B_M{}_E={}".format(keyn, v))
