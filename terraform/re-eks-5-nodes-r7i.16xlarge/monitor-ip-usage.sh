#!/bin/bash

# Script to monitor IP address usage in the subnet

# Get the subnet ID from the check-ips-eni.sh script
SUBNET_ID=$(grep -o 'subnet-[a-z0-9]*' check-ips-eni.sh)

if [ -z "$SUBNET_ID" ]; then
    echo "Error: Could not find subnet ID in check-ips-eni.sh"
    exit 1
fi

echo "Monitoring IP address usage in subnet $SUBNET_ID"
echo "----------------------------------------------"

# Get the ENI information
ENI_INFO=$(aws ec2 describe-network-interfaces --filters "Name=subnet-id,Values=$SUBNET_ID")

# Get the total number of ENIs in the subnet
TOTAL_ENIS=$(echo "$ENI_INFO" | jq '.NetworkInterfaces | length')
echo "Total ENIs in subnet: $TOTAL_ENIS"

# If there are no ENIs, exit early
if [ "$TOTAL_ENIS" -eq 0 ]; then
    echo "No ENIs found in the subnet."
    exit 0
fi

# Get the total number of IP addresses in use
TOTAL_IPS=0
for i in $(seq 0 $(($TOTAL_ENIS-1))); do
    IP_COUNT=$(echo "$ENI_INFO" | jq ".NetworkInterfaces[$i].PrivateIpAddresses | length")
    TOTAL_IPS=$(($TOTAL_IPS + $IP_COUNT))
done
echo "Total IP addresses in use: $TOTAL_IPS"

# Get the average number of IPs per ENI
if [ "$TOTAL_ENIS" -gt 0 ]; then
    AVG_IPS=$(echo "scale=2; $TOTAL_IPS / $TOTAL_ENIS" | bc)
    echo "Average IPs per ENI: $AVG_IPS"
fi

echo ""
echo "Detailed IP usage per ENI:"
echo "-------------------------"
aws ec2 describe-network-interfaces --filters "Name=subnet-id,Values=$SUBNET_ID" --query 'NetworkInterfaces[*].{Id:NetworkInterfaceId,IPCount:PrivateIpAddresses | length(@)}' --output table

echo ""
echo "To continuously monitor IP usage, run:"
echo "watch -n 10 ./monitor-ip-usage.sh"
