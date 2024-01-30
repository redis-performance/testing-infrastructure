import subprocess
import json

# Run the "terraform output json" command
output = subprocess.run(["terraform", "output", "-json"], stdout=subprocess.PIPE)

output_json = json.loads(output.stdout.decode())
total_nodes = len(output_json["server_private_ip"]["value"])
ssh_user = output_json["server_ssh_user"]["value"]
setup_name = (
    output_json["setup_name"]["value"][len("perf-cto-RE-") :]
    .replace(".", "_")
    .replace("-", "_")
)

print("#!/bin/bash\n")
print("TOTAL_NODES={}\n".format(total_nodes))
print("USER={}\n".format(ssh_user))
print('CLUSTER_NAME="{}"\n'.format(setup_name))
print("\n#internal IP addresses")
cleaned_json = {}
for keyn, v in enumerate(output_json["server_private_ip"]["value"], start=1):
    print("B_M{}_I={}".format(keyn, v))

print("\n#external IP addresses")
for keyn, v in enumerate(output_json["server_public_ip"]["value"], start=1):
    print("B_M{}_E={}".format(keyn, v))
