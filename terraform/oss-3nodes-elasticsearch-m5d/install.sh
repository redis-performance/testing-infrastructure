# exit immediately on error
set -e

USER=ubuntu
PEM=/tmp/benchmarks.redislabs.pem

for IP in "3.128.199.113" "3.144.12.156" "3.140.198.193"; do
    ssh -o "StrictHostKeyChecking no" -i ${PEM} -t ${USER}@${IP} echo $IP
    scp -i ${PEM} ./create-raid.sh ${USER}@${IP}:/tmp/create-raid.sh
    ssh -o "StrictHostKeyChecking no" -i ${PEM} -t ${USER}@${IP} sudo /tmp/create-raid.sh
done
