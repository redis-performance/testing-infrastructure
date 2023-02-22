import json
import paramiko
import concurrent.futures


pkey = "/home/fco/redislabs/pems/perf-ci.pem"
public_ips = {}

with open("public_ips.json", "r") as json_fd:
    public_ips = json.load(json_fd)


def host_work(public_ip, cmds_array, pkey):

    print("connecting to {}".format(public_ip))
    try:
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
    except paramiko.ssh_exception.SSHException as e:
     print("Error on {}. {}".format(public_ip,e))


cmds = """sudo apt update -y
sudo apt install build-essential tcl pkg-config -y
gcc --version
rm -rf redis-stable.tar.gz
rm -rf redis-stable
curl -O http://download.redis.io/redis-stable.tar.gz
tar xzvf redis-stable.tar.gz
cd redis-stable && make -j && sudo make install
taskset -c 0 redis-server --save '' --requirepass performance.redis --port 16379 --daemonize yes --protected-mode no
redis-cli -p 16379 -a performance.redis ping"""

cmds = """redis-cli -p 16379 -a performance.redis ping"""

cmds = """pkill -9 redis-server
taskset -c 0 redis-server --save '' --port 16379 --daemonize yes --protected-mode no --requirepass performance.redis 
redis-cli -p 16379 -a performance.redis ping"""

cmds = """sudo pkill -9 redis-server"""

cmds_array = cmds.split("\n")

# Use a concurrent.futures.ThreadPoolExecutor to run the commands concurrently
with concurrent.futures.ThreadPoolExecutor() as executor:
    # Submit the run_command function for each host and command
    futures = [
        executor.submit(host_work, host, cmds_array, pkey)
        for host in public_ips.values()
    ]

    # Wait for all the tasks to complete
    concurrent.futures.wait(futures)
