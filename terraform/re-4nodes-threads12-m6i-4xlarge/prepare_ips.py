import subprocess
import json

# Run the "terraform output json" command
output = subprocess.run(["terraform", "output", "-json"], stdout=subprocess.PIPE)

output_json = json.loads(output.stdout.decode())
total_nodes = len(output_json['server_private_ip']['value'])
search_threads = output_json['search_threads']['value']

print("#!/bin/bash\n")
print("TOTAL_NODES={}\n".format(total_nodes))
print("SEARCH_THREADS={}\n".format(search_threads))

print("CLUSTER_NAME=\"{}_nodes_{}_{}_threads\"\n".format(total_nodes,output_json['server_instance_type']['value'].replace(".","_"),search_threads))

print("\n#client external IP addresses")
if 'client_public_ip' in output_json:
    print("CLIENT_E={}\n".format(output_json['client_public_ip']['value']))

print("\n#internal IP addresses")
cleaned_json = {}
for keyn, v in enumerate(output_json['server_private_ip']['value'],start=1):
    print("B_M{}_I={}".format(keyn,v))

print("\n#external IP addresses")
for keyn, v in enumerate(output_json['server_public_ip']['value'],start=1):
    print("B_M{}_E={}".format(keyn,v))