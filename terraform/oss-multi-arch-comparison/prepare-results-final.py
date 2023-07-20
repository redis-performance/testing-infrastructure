aws = {'m5.large': 745, 'r5.4xlarge': 236, 'c5.xlarge': 761, 'm5.xlarge': 281, 'i3.8xlarge': 90, 'r5.2xlarge': 346, 'm5.24xlarge': 27, 'c5.2xlarge': 168, 'm4.10xlarge': 2, 'r5.8xlarge': 139, 'm5.2xlarge': 86, 'r5.xlarge': 144, 'r5.12xlarge': 16, 'm5.16xlarge': 16, 'm5.4xlarge': 38, 'c5.4xlarge': 137, 'r5.16xlarge': 52, 'm5.12xlarge': 6, 'i3.4xlarge': 121, 'r5n.4xlarge': 2, 'm5.8xlarge': 9, 'm4.large': 9, 'i3.2xlarge': 62, 'r5.24xlarge': 35, 'c5n.4xlarge': 20, 'c4.xlarge': 16, 'c5.9xlarge': 37, 'r5n.24xlarge': 14, 'c5n.9xlarge': 12, 'm4.xlarge': 2, 'r5n.12xlarge': 5, 'c5n.2xlarge': 9, 'r5n.8xlarge': 2, 'c5.12xlarge': 37, 'r4.8xlarge': 5, 'r4.2xlarge': 5, 'c5.18xlarge': 10, 'c4.4xlarge': 2}

for vm,count in aws.items():
    if "5." in vm:
        print("{},{}".format(vm,count))

vms = [
    "c4.2xlarge",
    "c5.2xlarge",
    "c6i.2xlarge",
    "c6a.2xlarge",
    "c6g.2xlarge",
    "c7g.2xlarge",
    "r4.2xlarge",
    "r5.2xlarge",
    "r6i.2xlarge",
    "r6a.2xlarge",
    "r6g.2xlarge",
    "m4.2xlarge",
    "m5.2xlarge",
    "m6i.2xlarge",
    "m6a.2xlarge",
    "m6g.2xlarge",
]


tests = [
    "memtier_benchmark-1key-zset-1M-elements-zcard-pipeline-10",
"memtier_benchmark-1Mkeys-load-hash-5-fields-with-1000B-values-pipeline-10",
"memtier_benchmark-1key-zset-100-elements-zrangebyscore-all-elements",
"memtier_benchmark-1Mkeys-string-get-100B",
"memtier_benchmark-1Mkeys-string-get-10B-pipeline-10",
"memtier_benchmark-10Mkeys-load-hash-5-fields-with-10B-values-pipeline-10",
"memtier_benchmark-1key-zset-1M-elements-zrevrange-5-elements",
"memtier_benchmark-10Mkeys-load-hash-5-fields-with-10B-values",
"memtier_benchmark-1Mkeys-string-get-100B-pipeline-10",
"memtier_benchmark-1Mkeys-string-get-1KiB",
"memtier_benchmark-1Mkeys-load-hash-5-fields-with-1000B-values",
"memtier_benchmark-1Mkeys-hash-hmget-5-fields-with-100B-values-pipeline-10",
"memtier_benchmark-10Mkeys-load-hash-5-fields-with-100B-values-pipeline-10",
"memtier_benchmark-1Mkeys-string-get-10B",
"memtier_benchmark-10Mkeys-load-hash-5-fields-with-100B-values",
"memtier_benchmark-1Mkeys-string-get-1KiB-pipeline-10"
]

for test in tests:
    for vm in vms:
        filename = "{}-priority-10.log".format(vm)
        with open ("./results-final-cleaned/"+filename,"r") as fd:
            lines = fd.readlines()
            for line in lines:
                if test in line:
                    v = line.split("|")[3].strip()
                    #print("{},{},{}".format (test,vm,v) )
                    break