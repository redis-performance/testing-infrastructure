import subprocess
import json

# Run the "ls" command
output = subprocess.run(["terraform", "output", "-json"], stdout=subprocess.PIPE)

output_json = json.loads(output.stdout.decode())
cleaned_json = {}
db_json = {}
for keyn, keyv in output_json.items():
    v = keyv["value"][0]
    f = keyn.find("_")
    s = keyn[f + 1 :].find("_")
    vm = keyn[: s + f + 1].replace("_", ".")

    if "public_ip" in keyn and "client" in keyn:
        cleaned_json[vm] = v

    if "client" not in keyn:
        if vm not in db_json:
            db_json[vm] = {}
        
        if "private_ip" in keyn:
            db_json[vm]["private_ip"] = v
        if "public_ip" in keyn:
            db_json[vm]["public_ip"] = v
        # Print the command output


print("Total distinct VMs {}".format(len(cleaned_json.keys())))

db_list = list(db_json.items())
print(db_list)

client_ips = cleaned_json["client.public"]
print(client_ips)

final_json = {}
for pos, client_ip in enumerate(client_ips,1) :
    db_host = db_list[pos-1]
    print(pos,client_ip, db_host[1]['private_ip'])
    final_json[client_ip]=db_host[1]['private_ip']

with open("client_public_ips.json", "w") as json_fd:
    json.dump(final_json, json_fd, indent=" ")
