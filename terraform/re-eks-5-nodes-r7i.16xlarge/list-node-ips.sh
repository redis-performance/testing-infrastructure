#!/bin/bash

# Get all instance IDs for EKS worker nodes
INSTANCE_IDS=$(aws ec2 describe-instances \
  --filters "Name=tag:eks:nodegroup-name,Values=*" \
  --query "Reservations[*].Instances[*].InstanceId" \
  --output text)

echo -e "\nInstanceID\t\tPrivateDNS\t\tENI-ID\t\t\tIP-Count\tIPs"
echo "------------------------------------------------------------------------------------------------------"

for INSTANCE_ID in $INSTANCE_IDS; do
  # Get the node's private DNS name (e.g. ip-10-3-0-174)
  INFO=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query "Reservations[*].Instances[*].[InstanceId,PrivateDnsName]" \
    --output text)

  INSTANCE=$(echo "$INFO" | awk '{print $1}')
  DNS=$(echo "$INFO" | awk '{print $2}')

  # Get all ENIs attached to this instance and list IPs
  aws ec2 describe-network-interfaces \
    --filters Name=attachment.instance-id,Values="$INSTANCE_ID" \
    --query 'NetworkInterfaces[*].[NetworkInterfaceId,length(PrivateIpAddresses),join(`,`,PrivateIpAddresses[*].PrivateIpAddress)]' \
    --output text | while read ENI COUNT IPS; do
      echo -e "$INSTANCE\t$DNS\t$ENI\t$COUNT\t$IPS"
    done
done
