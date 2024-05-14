import subprocess
import json

# Run the "terraform output json" command
output = subprocess.run(["terraform", "output", "-json"], stdout=subprocess.PIPE)

output_json = json.loads(output.stdout.decode())
total_nodes = len(output_json['server_private_ip']['value'])
search_threads = output_json['search_threads']['value']
setup_name = output_json["setup_name"]["value"].replace(".", "_").replace("-", "_")
prefix = "perf-cto-RE-"
setup_name = setup_name[len(prefix) :]

print("#!/bin/bash\n")
print("TOTAL_NODES={}\n".format(total_nodes))
print("SEARCH_THREADS={}\n".format(search_threads))
print('CLUSTER_NAME="{}"\n'.format(setup_name))

print("\n#internal IP addresses")
cleaned_json = {}
for keyn, v in enumerate(output_json['server_private_ip']['value'],start=1):
    print("B_M{}_I={}".format(keyn,v))

print("\n#external IP addresses")
for keyn, v in enumerate(output_json['server_public_ip']['value'],start=1):
    print("B_M{}_E={}".format(keyn,v))
