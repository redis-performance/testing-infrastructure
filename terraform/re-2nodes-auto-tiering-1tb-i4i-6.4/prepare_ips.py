import subprocess
import json

# Run the "terraform output json" command
output = subprocess.run(["terraform", "output", "-json"], stdout=subprocess.PIPE)

output_json = json.loads(output.stdout.decode())
total_nodes = len(output_json["server_private_ip"]["value"])
proxy_threads = output_json["proxy_threads"]["value"]

print("#!/bin/bash\n")
print("TOTAL_NODES={}\n".format(total_nodes))


suffix_len = len("perf-cto-RE-")
setup_name = output_json["setup_name"]["value"].replace(".", "_").replace("-", "_")
setup_name = setup_name[suffix_len:]
server_instance_type = output_json["server_instance_type"]["value"].replace(".", "_")

print('CLUSTER_NAME="{}"\n'.format(setup_name))
print("\n#internal IP addresses")
cleaned_json = {}
for keyn, v in enumerate(output_json["server_private_ip"]["value"], start=1):
    print("B_M{}_I={}".format(keyn, v))

print("\n#external IP addresses")
for keyn, v in enumerate(output_json["server_public_ip"]["value"], start=1):
    print("B_M{}_E={}".format(keyn, v))

print("\nPROXY_THREADS={}\n".format(proxy_threads))
