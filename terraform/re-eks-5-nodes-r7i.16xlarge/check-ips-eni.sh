#!/bin/bash

aws ec2 describe-network-interfaces --filters "Name=subnet-id,Values=subnet-0597ccd9e8d2a050e" --query 'NetworkInterfaces[*].{Id:NetworkInterfaceId,IPCount:PrivateIpAddresses | length(@)}'