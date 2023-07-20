import json
import paramiko
import concurrent.futures


public_ips = [
    "18.189.185.95",
    "18.222.65.15",
    "3.22.42.181",
    "3.139.87.105",
    "3.144.4.13",
    "3.138.67.228",
    "18.118.166.68",
    "3.133.154.135",
    "18.191.147.2",
    "18.223.210.115",
    "18.119.162.19",
    "52.15.114.142",
    "3.133.134.138",
    "3.23.101.147",
    "3.144.89.139",
    "3.137.182.138",
]

public_ips = {
    "18.189.185.95": "10.3.0.130",
    "18.222.65.15": "10.3.0.241",
    "3.22.42.181": "10.3.0.136",
    "3.139.87.105": "10.3.0.28",
    "3.144.4.13": "10.3.0.251",
    "3.138.67.228": "10.3.0.17",
    "18.118.166.68": "10.3.0.34",
    "3.133.154.135": "10.3.0.124",
    "18.191.147.2": "10.3.0.194",
    "18.223.210.115": "10.3.0.145",
    "18.119.162.19": "10.3.0.131",
    "52.15.114.142": "10.3.0.24",
    "3.133.134.138": "10.3.0.112",
    "3.23.101.147": "10.3.0.178",
    "3.144.89.139": "10.3.0.31",
    "3.137.182.138": "10.3.0.227",
}

pkey = "/home/fco/redislabs/pems/perf-ci.pem"


def host_work(public_ip, cmds_array, pkey):
    print("connecting to {}".format(public_ip))
    # Create an SSH client
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    # Load the .pem file
    pem = paramiko.RSAKey.from_private_key_file(pkey)

    # Connect to the host
    client.connect(public_ip, username="ubuntu", pkey=pem)
    print(public_ip)
    for cmd in cmds_array:

        # Run the command
        stdin, stdout, stderr = client.exec_command(cmd)

        # Print the command output
        print(stderr.read().decode())
        # Print the command output
        print(stdout.read().decode())

    # Close the connection
    client.close()


# cmds = """sudo apt update -y
# sudo apt install python3-pip -y
# sudo pip3 install --upgrade pip
# sudo pip3 install pyopenssl --upgrade
# sudo apt install docker.io -y"""
# cmds = """docker --version
# pip3 install redis-benchmarks-specification
# cmd = "/home/ubuntu/.local/bin/redis-benchmarks-spec-client-runner --preserve_temporary_client_dirs --flushall_on_every_test_start --dry-run --db_server_port {}  --db_server_port 16379 --tests-priority-upper-limit 10"


# cmds_array = cmds.split("\n")

cmds = {}
for h, db_ip in public_ips.items():
    cmd_1 = "sudo /home/ubuntu/.local/bin/redis-benchmarks-spec-client-runner --preserve_temporary_client_dirs --flushall_on_every_test_start --db_server_host {}  --db_server_port 16379 --tests-priority-upper-limit 10 > /home/ubuntu/benchmark.log".format(
        db_ip
    )
    cmd = []
    cmd.append("sudo rm -rf /home/ubuntu/tmp*")
    cmd.append("sudo pkill -9 redis-server")
    cmd.append("sudo rm /home/ubuntu/benchmark.log")
    cmd.append(cmd_1)
    cmd.append("echo done running benchmarks!")
    cmds[h] = cmd


# Use a concurrent.futures.ThreadPoolExecutor to run the commands concurrently
with concurrent.futures.ThreadPoolExecutor() as executor:
    # Submit the run_command function for each host and command
    futures = [
        executor.submit(host_work, host, cmds[host], pkey) for host in public_ips.keys()
    ]

    # Wait for all the tasks to complete
    concurrent.futures.wait(futures)
