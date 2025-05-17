#!/bin/bash
#
# enable-oss-api-with-restart.sh - Enable OSS Cluster API for Redis Enterprise Database with restart
#
# This script enables the OSS Cluster API for a Redis Enterprise Database
# using the Redis Enterprise REST API and restarts the database if needed.
#

# AWS credentials should be provided as environment variables
# export AWS_ACCESS_KEY_ID="your-access-key"
# export AWS_SECRET_ACCESS_KEY="your-secret-key"
# export AWS_SESSION_TOKEN="your-session-token"
# export AWS_REGION="us-east-2"

# Update kubeconfig
aws eks update-kubeconfig --region us-east-2 --name re-eks-cluster-5-nodes-r7i-16xlarge

# Set namespace
NAMESPACE="rec-large-scale"

# Get Redis Enterprise Cluster admin credentials
USERNAME=$(kubectl get secret rec-large-scale-5nodes -n $NAMESPACE -o jsonpath="{.data.username}" | base64 --decode)
PASSWORD=$(kubectl get secret rec-large-scale-5nodes -n $NAMESPACE -o jsonpath="{.data.password}" | base64 --decode)

echo "Redis Enterprise Cluster admin credentials:"
echo "Username: $USERNAME"
echo "Password: $PASSWORD"

# Get the database UID
DB_UID=$(kubectl get redb primary -n $NAMESPACE -o jsonpath="{.status.databaseUID}")
echo "Database UID: $DB_UID"

# Get one of the Redis Enterprise Cluster pods
POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=redis-enterprise -o jsonpath="{.items[0].metadata.name}")
echo "Using Redis Enterprise pod: $POD_NAME"

# Set up port forwarding to the Redis Enterprise Cluster API
echo "Setting up port forwarding to the Redis Enterprise Cluster API..."
kubectl port-forward $POD_NAME -n $NAMESPACE 9443:9443 &
PORT_FORWARD_PID=$!

# Wait for port forwarding to be established
sleep 5

# Get the current OSS Cluster API settings
echo "Getting current OSS Cluster API settings..."
DB_CONFIG=$(curl -k -s -u "$USERNAME:$PASSWORD" https://localhost:9443/v1/bdbs/$DB_UID)
OSS_CLUSTER=$(echo "$DB_CONFIG" | jq -r '.oss_cluster')
OSS_ENDPOINT_TYPE=$(echo "$DB_CONFIG" | jq -r '.oss_cluster_api_preferred_endpoint_type')
OSS_IP_TYPE=$(echo "$DB_CONFIG" | jq -r '.oss_cluster_api_preferred_ip_type')

echo "OSS Cluster API: $OSS_CLUSTER"
echo "OSS Cluster API Preferred Endpoint Type: $OSS_ENDPOINT_TYPE"
echo "OSS Cluster API Preferred IP Type: $OSS_IP_TYPE"

# Check if the database needs to be updated
if [ "$OSS_CLUSTER" == "true" ] && [ "$OSS_ENDPOINT_TYPE" == "ip" ] && [ "$OSS_IP_TYPE" == "external" ]; then
    echo "OSS Cluster API is already enabled with the correct settings."
    kill $PORT_FORWARD_PID
    exit 0
fi

# Enable OSS Cluster API
echo "Enabling OSS Cluster API..."
curl -k -s -X PUT -u "$USERNAME:$PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"oss_cluster":true,"oss_cluster_api_preferred_endpoint_type":"ip","oss_cluster_api_preferred_ip_type":"external"}' \
  https://localhost:9443/v1/bdbs/$DB_UID > /dev/null

# Get the updated OSS Cluster API settings
echo "Getting updated OSS Cluster API settings..."
DB_CONFIG=$(curl -k -s -u "$USERNAME:$PASSWORD" https://localhost:9443/v1/bdbs/$DB_UID)
OSS_CLUSTER=$(echo "$DB_CONFIG" | jq -r '.oss_cluster')
OSS_ENDPOINT_TYPE=$(echo "$DB_CONFIG" | jq -r '.oss_cluster_api_preferred_endpoint_type')
OSS_IP_TYPE=$(echo "$DB_CONFIG" | jq -r '.oss_cluster_api_preferred_ip_type')

echo "OSS Cluster API: $OSS_CLUSTER"
echo "OSS Cluster API Preferred Endpoint Type: $OSS_ENDPOINT_TYPE"
echo "OSS Cluster API Preferred IP Type: $OSS_IP_TYPE"

# Check if the database needs to be restarted
if [ "$OSS_CLUSTER" != "true" ] || [ "$OSS_ENDPOINT_TYPE" != "ip" ] || [ "$OSS_IP_TYPE" != "external" ]; then
    echo "OSS Cluster API settings were not updated. The database might need to be restarted."

    # Ask for confirmation before restarting the database
    read -p "Do you want to restart the database to apply the changes? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Restarting the database..."

        # Get the current database configuration
        DB_CONFIG=$(curl -k -s -u "$USERNAME:$PASSWORD" https://localhost:9443/v1/bdbs/$DB_UID)

        # Create a temporary file with the database configuration
        TMP_FILE=$(mktemp)
        echo "$DB_CONFIG" > $TMP_FILE

        # Update the OSS Cluster API settings in the configuration
        jq '.oss_cluster = true | .oss_cluster_api_preferred_endpoint_type = "ip" | .oss_cluster_api_preferred_ip_type = "external"' $TMP_FILE > ${TMP_FILE}.new
        mv ${TMP_FILE}.new $TMP_FILE

        # Delete the database
        echo "Deleting the database..."
        curl -k -s -X DELETE -u "$USERNAME:$PASSWORD" https://localhost:9443/v1/bdbs/$DB_UID

        # Wait for the database to be deleted
        echo "Waiting for the database to be deleted..."
        while curl -k -s -u "$USERNAME:$PASSWORD" https://localhost:9443/v1/bdbs/$DB_UID | jq -e '.uid' > /dev/null 2>&1; do
            echo -n "."
            sleep 5
        done
        echo

        # Create the database with the updated configuration
        echo "Creating the database with the updated configuration..."
        curl -k -s -X POST -u "$USERNAME:$PASSWORD" \
          -H "Content-Type: application/json" \
          -d @$TMP_FILE \
          https://localhost:9443/v1/bdbs

        # Wait for the database to be created
        echo "Waiting for the database to be created..."
        while ! curl -k -s -u "$USERNAME:$PASSWORD" https://localhost:9443/v1/bdbs/$DB_UID | jq -e '.uid' > /dev/null 2>&1; do
            echo -n "."
            sleep 5
        done
        echo

        # Wait for the database to be active
        echo "Waiting for the database to be active..."
        while [ "$(curl -k -s -u "$USERNAME:$PASSWORD" https://localhost:9443/v1/bdbs/$DB_UID | jq -r '.status')" != "active" ]; do
            echo -n "."
            sleep 5
        done
        echo

        # Get the updated OSS Cluster API settings
        echo "Getting updated OSS Cluster API settings..."
        DB_CONFIG=$(curl -k -s -u "$USERNAME:$PASSWORD" https://localhost:9443/v1/bdbs/$DB_UID)
        OSS_CLUSTER=$(echo "$DB_CONFIG" | jq -r '.oss_cluster')
        OSS_ENDPOINT_TYPE=$(echo "$DB_CONFIG" | jq -r '.oss_cluster_api_preferred_endpoint_type')
        OSS_IP_TYPE=$(echo "$DB_CONFIG" | jq -r '.oss_cluster_api_preferred_ip_type')

        echo "OSS Cluster API: $OSS_CLUSTER"
        echo "OSS Cluster API Preferred Endpoint Type: $OSS_ENDPOINT_TYPE"
        echo "OSS Cluster API Preferred IP Type: $OSS_IP_TYPE"

        # Clean up
        rm $TMP_FILE
    else
        echo "Database restart cancelled."
    fi
fi

# Kill the port forwarding process
kill $PORT_FORWARD_PID

echo "Done."
