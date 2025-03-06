import subprocess
import json

# Run the "terraform output json" command
output = subprocess.run(["terraform", "output", "-json"], stdout=subprocess.PIPE)

output_json = json.loads(output.stdout.decode())
total_nodes = len(output_json["server_private_ip"]["value"])
server_instance_type = output_json["server_instance_type"]["value"].replace(".", "_")
pem = output_json["pem"]["value"]


print("#!/bin/bash\n")
print("TOTAL_NODES={}\n".format(total_nodes))
print("PEM={}\n".format(pem))

print(f'CLUSTER_NAME="{server_instance_type}_{total_nodes}nodes"\n')

print("\n#internal IP addresses")
cleaned_json = {}
for keyn, v in enumerate(output_json["server_private_ip"]["value"], start=1):
    print("B_M{}_I={}".format(keyn, v))

print("\n#external IP addresses")
for keyn, v in enumerate(output_json["server_public_ip"]["value"], start=1):
    print("B_M{}_E={}".format(keyn, v))
