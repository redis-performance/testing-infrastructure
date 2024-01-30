import subprocess
import json

# Run the "terraform output json" command
output = subprocess.run(["terraform", "output", "-json"], stdout=subprocess.PIPE)

output_json = json.loads(output.stdout.decode())
producer_total_nodes = len(output_json['producer_public_ips']['value'])
consumer_total_nodes = len(output_json['consumer_public_ips']['value'])
ssh_user = output_json['server_ssh_user']['value']

print("#!/bin/bash\n")
print("CONSUMER_TOTAL_NODES={}\n".format(consumer_total_nodes))
print("PRODUCER_TOTAL_NODES={}\n".format(producer_total_nodes))
print("USER={}\n".format(ssh_user))

print("\n#CONSUMERS external IP addresses")
for keyn, v in enumerate(output_json['consumer_public_ips']['value'],start=1):
    print("CONSUMER_{}_E={}".format(keyn,v))

print("\n#PRODUCERS external IP addresses")
for keyn, v in enumerate(output_json['producer_public_ips']['value'],start=1):
    print("PRODUCER_{}_E={}".format(keyn,v))
