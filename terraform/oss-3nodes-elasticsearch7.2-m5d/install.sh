# exit immediately on error
set -e

USER=ubuntu
PEM=/tmp/benchmarks.redislabs.pem

for IP in "3.12.36.37" "3.144.27.172" "3.141.28.145"; do
    ssh -o "StrictHostKeyChecking no" -i ${PEM} -t ${USER}@${IP} echo $IP
    scp -i ${PEM} ./create-raid.sh ${USER}@${IP}:/tmp/create-raid.sh
    ssh -o "StrictHostKeyChecking no" -i ${PEM} -t ${USER}@${IP} sudo /tmp/create-raid.sh
done
