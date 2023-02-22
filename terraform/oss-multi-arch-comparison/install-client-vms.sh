#!/bin/bash
source ips.sh

# exit immediately on error
set -e

USER=ubuntu
PEM=${PEM:-"~/redislabs/pems/perf-ci.pem"}

mkdir -p ./results-final

for CLIENT_N in `seq 1 16`; do 
    eip=B_M$CLIENT_N\_E
    db_ip=REDIS_$CLIENT_N\_INTERNAL_IP
    vmtype=REDIS_VM_$CLIENT_N

    IP="${!eip}"
    DB_HOST="${!db_ip}"
    VM_TYPE="${!vmtype}"
    LOGNAME="$VM_TYPE-priority-10.log"
    echo "*************************************************************************************"
    # --override-memtier-test-time 10  
    CMD="redis-benchmarks-spec-client-runner --override-test-runs 3 --flushall_on_every_test_start --tests-priority-upper-limit 10 --db_server_host $DB_HOST --db_server_port 16379 --db_server_password performance.redis  2>&1 > /home/ubuntu/$LOGNAME"
    echo "Working on host: $IP"
    echo "Benchmark will be done on DB host ($VM_TYPE): $DB_HOST"
    echo "logname: $LOGNAME"
    echo "command to run: $CMD"
    echo "/////////////////////////////////////////////////////////////////////////////////////"
    # ssh -o "StrictHostKeyChecking no" -i ${PEM} -t ${USER}@${IP} sudo redis-benchmarks-spec-client-runner --help
    # scp -o "StrictHostKeyChecking no" -i ${PEM} install-redisbench.sh ${USER}@${IP}:/tmp/i.sh
    # ssh -o "StrictHostKeyChecking no" -i ${PEM} -t ${USER}@${IP} sudo /tmp/i.sh
    # ssh -tt -i ${PEM} ${USER}@${IP} sudo "echo $CMD > /home/ubuntu/run.sh"
    # ssh -tt -i ${PEM} ${USER}@${IP} sudo chmod 755 /home/ubuntu/run.sh
    # ssh -t -i ${PEM} ${USER}@${IP} sudo docker ps 
   # ssh -t -i ${PEM} ${USER}@${IP} sudo gpasswd -a ubuntu docker
    # ssh -t -i ${PEM} ${USER}@${IP} sudo usermod -a -G docker ubuntu
    # ssh -t -i ${PEM} ${USER}@${IP} sudo pip3 install redis-benchmarks-specification==0.1.66

    # ssh -t -i ${PEM} ${USER}@${IP} sudo rm -rf /home/ubuntu/tmp*
    # ssh -t -i ${PEM} ${USER}@${IP} sudo docker ps 
    # ssh -t -i ${PEM} ${USER}@${IP} rm -rf /home/ubuntu/$LOGNAME
    # ssh -f -i ${PEM} ${USER}@${IP} sudo $CMD &
    scp -i ${PEM} ${USER}@${IP}:/home/ubuntu/$LOGNAME ./results-final/$LOGNAME
    # ssh -t -i ${PEM} ${USER}@${IP} cat /home/ubuntu/$LOGNAME
    echo "*************************************************************************************"
#    ssh -o "StrictHostKeyChecking no" -i ${PEM} -tt ${USER}@${IP} sudo screen -S benchmark "'$CMD'" &
    #ssh -o "StrictHostKeyChecking no" -i ${PEM} -t ${USER}@${IP} sudo redis-benchmarks-spec-client-runner --flushall_on_every_test_start --flushall_on_every_test_end --dry-run --tests-priority-upper-limit 1 --db_server_host $DB_HOST --db_server_port 16379 --db_server_password performance.redis --override-memtier-test-time 1 
done

# wait

