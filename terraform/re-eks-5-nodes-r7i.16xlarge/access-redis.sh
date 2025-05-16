#!/bin/bash

# Comprehensive script for accessing Redis Enterprise Cluster and databases

# Function to display usage information
show_usage() {
    echo "Usage: $0 [OPTION]"
    echo "Access Redis Enterprise Cluster UI and databases."
    echo ""
    echo "Options:"
    echo "  ui          Set up port forwarding for Redis Enterprise Cluster UI"
    echo "  db NAME     Set up port forwarding for a specific Redis database"
    echo "  list        List all Redis databases"
    echo "  creds       Show Redis Enterprise Cluster credentials"
    echo "  help        Display this help message"
    echo ""
    echo "Examples:"
    echo "  $0 ui       # Access the Redis Enterprise Cluster UI"
    echo "  $0 db mydb  # Access the Redis database named 'mydb'"
    echo "  $0 list     # List all Redis databases"
    echo "  $0 creds    # Show Redis Enterprise Cluster credentials"
}

# Function to set up port forwarding for Redis Enterprise Cluster UI
forward_ui() {
    # Check if the Redis Enterprise Cluster UI service exists
    if ! kubectl get service rec-large-scale-5nodes-ui &>/dev/null; then
        echo "Error: Redis Enterprise Cluster UI service not found."
        echo "Make sure the Redis Enterprise Cluster is deployed and running."
        exit 1
    fi

    # Get the service type
    SERVICE_TYPE=$(kubectl get service rec-large-scale-5nodes-ui -o jsonpath='{.spec.type}')

    if [ "$SERVICE_TYPE" == "LoadBalancer" ]; then
        # Get the LoadBalancer hostname
        LB_HOSTNAME=$(kubectl get service rec-large-scale-5nodes-ui -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
        
        if [ -n "$LB_HOSTNAME" ]; then
            echo "Redis Enterprise Cluster UI is accessible via LoadBalancer at:"
            echo "https://$LB_HOSTNAME:8443"
            echo ""
            echo "You can access it directly without port forwarding."
            return
        else
            echo "LoadBalancer hostname not available yet. Falling back to port forwarding."
        fi
    fi

    # Set up port forwarding
    echo "Setting up port forwarding for Redis Enterprise Cluster UI..."
    echo "The UI will be accessible at: https://localhost:8443"
    echo ""
    echo "Press Ctrl+C to stop port forwarding when you're done."
    echo ""

    # Start port forwarding
    kubectl port-forward service/rec-large-scale-5nodes-ui 8443:8443
}

# Function to list all Redis databases
list_databases() {
    echo "Listing Redis databases..."
    echo ""
    
    # Check if the Redis Enterprise Cluster is running
    if ! kubectl get rec rec-large-scale-5nodes &>/dev/null; then
        echo "Error: Redis Enterprise Cluster not found."
        echo "Make sure the Redis Enterprise Cluster is deployed and running."
        exit 1
    fi
    
    # List all Redis Enterprise Databases
    kubectl get redb
}

# Function to set up port forwarding for a specific Redis database
forward_database() {
    DB_NAME=$1
    
    if [ -z "$DB_NAME" ]; then
        echo "Error: Database name not specified."
        echo "Usage: $0 db DATABASE_NAME"
        exit 1
    fi
    
    # Check if the database exists
    if ! kubectl get redb "$DB_NAME" &>/dev/null; then
        echo "Error: Redis database '$DB_NAME' not found."
        echo "Available databases:"
        list_databases
        exit 1
    fi
    
    # Get the database service name
    DB_SERVICE="$DB_NAME"
    
    # Get the database port
    DB_PORT=$(kubectl get redb "$DB_NAME" -o jsonpath='{.spec.port}')
    if [ -z "$DB_PORT" ]; then
        DB_PORT=12000  # Default port if not specified
    fi
    
    echo "Setting up port forwarding for Redis database '$DB_NAME'..."
    echo "The database will be accessible at: redis://localhost:$DB_PORT"
    echo ""
    echo "Connection string: redis://localhost:$DB_PORT"
    echo ""
    echo "Press Ctrl+C to stop port forwarding when you're done."
    echo ""
    
    # Start port forwarding
    kubectl port-forward service/"$DB_SERVICE" "$DB_PORT:$DB_PORT"
}

# Function to show Redis Enterprise Cluster credentials
show_credentials() {
    # Get the username and password from the Kubernetes secret
    REC_USERNAME=$(kubectl get secret rec-large-scale-5nodes -o jsonpath='{.data.username}' | base64 --decode)
    REC_PASSWORD=$(kubectl get secret rec-large-scale-5nodes -o jsonpath='{.data.password}' | base64 --decode)
    
    echo "Redis Enterprise Cluster credentials:"
    echo "Username: $REC_USERNAME"
    echo "Password: $REC_PASSWORD"
    echo ""
    echo "To set these as environment variables, run:"
    echo "export REC_USERNAME='$REC_USERNAME'"
    echo "export REC_PASSWORD='$REC_PASSWORD'"
}

# Main script logic
case "$1" in
    ui)
        forward_ui
        ;;
    db)
        forward_database "$2"
        ;;
    list)
        list_databases
        ;;
    creds)
        show_credentials
        ;;
    help)
        show_usage
        ;;
    *)
        show_usage
        exit 1
        ;;
esac
