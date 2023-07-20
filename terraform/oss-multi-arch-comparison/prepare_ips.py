import subprocess
import json

# Run the "terraform output json" command
output = subprocess.run(["terraform", "output", "-json"], stdout=subprocess.PIPE)

output_json = json.loads(output.stdout.decode())
cleaned_json = {}
for keyn, keyv in output_json.items():
    v = keyv["value"][0]
    if "public_ip" in keyn and "client" not in keyn:
        f = keyn.find("_")
        s = keyn[f + 1 :].find("_")
        vm = keyn[: s + f + 1].replace("_", ".")
        # Print the command output
        print(vm, v)
        cleaned_json[vm] = v

print("Total distinct VMs {}".format(len(cleaned_json.keys())))
with open("public_ips.json", "w") as json_fd:
    json.dump(cleaned_json, json_fd, indent=" ")
