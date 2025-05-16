#!/bin/bash
#
# update-license.sh - Redis Enterprise Cluster License Update Script
#
# Description:
#   This script automates the process of updating the Redis Enterprise Cluster license.
#   It provides two methods:
#   1. Using a Kubernetes secret (recommended)
#   2. Directly in the REC custom resource (not recommended)
#
# Usage:
#   ./update-license.sh [OPTION]
#
# Options:
#   --secret    Update the license using a Kubernetes secret (recommended)
#   --inline    Update the license directly in the REC custom resource (not recommended)
#   --help      Display help information
#
# Author: Redis Labs
# Date: 2023
#
# For detailed documentation, see README-license.md

# Exit immediately if a command exits with a non-zero status
set -e

# Configuration variables
# These can be modified to match your environment if needed
REC_NAME="rec-large-scale-5nodes"          # Name of the Redis Enterprise Cluster
LICENSE_FILE="license.txt"                 # Path to the license file
LICENSE_SECRET_NAME="redis-enterprise-license"  # Name of the Kubernetes secret
NAMESPACE="rec-large-scale"                # Kubernetes namespace

# Function to display usage information
show_usage() {
    echo "Usage: $0 [OPTION]"
    echo "Update the Redis Enterprise Cluster license."
    echo ""
    echo "Options:"
    echo "  --secret    Update the license using a Kubernetes secret (recommended)"
    echo "  --inline    Update the license directly in the REC custom resource (not recommended)"
    echo "  --help      Display this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --secret    # Update the license using a Kubernetes secret"
    echo "  $0 --inline    # Update the license directly in the REC custom resource"
}

# Function to check if the license file exists
check_license_file() {
    if [ ! -f "$LICENSE_FILE" ]; then
        echo "Error: License file '$LICENSE_FILE' not found."
        echo "Please place your Redis Enterprise license in a file named '$LICENSE_FILE' in the current directory."
        exit 1
    fi

    # Warn about not committing the license file
    echo "WARNING: Do not commit the license.txt file to Git!"
    echo "The license file contains sensitive information and should not be stored in version control."
    echo "The .gitignore file is configured to ignore *.txt files, so license.txt should be excluded automatically."
    echo ""
}

# Function to update the license using a Kubernetes secret
update_license_secret() {
    check_license_file

    echo "Reading license from $LICENSE_FILE..."
    LICENSE_CONTENT=$(cat "$LICENSE_FILE")

    # Check if the secret already exists
    if kubectl get secret "$LICENSE_SECRET_NAME" -n "$NAMESPACE" &>/dev/null; then
        echo "Updating existing license secret '$LICENSE_SECRET_NAME'..."
        kubectl delete secret "$LICENSE_SECRET_NAME" -n "$NAMESPACE"
    else
        echo "Creating new license secret '$LICENSE_SECRET_NAME'..."
    fi

    # Create the secret with the license content
    kubectl create secret generic "$LICENSE_SECRET_NAME" \
        --from-file=license="$LICENSE_FILE" \
        -n "$NAMESPACE"

    echo "License secret created/updated successfully."

    # Check if the REC already has the licenseSecretName field
    if kubectl get rec "$REC_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.licenseSecretName}' | grep -q "$LICENSE_SECRET_NAME"; then
        echo "Redis Enterprise Cluster is already configured to use license secret '$LICENSE_SECRET_NAME'."
    else
        echo "Updating Redis Enterprise Cluster to use license secret '$LICENSE_SECRET_NAME'..."

        # Create a patch to update the licenseSecretName field
        cat <<EOF > /tmp/rec-license-patch.yaml
spec:
  licenseSecretName: $LICENSE_SECRET_NAME
EOF

        # Apply the patch
        kubectl patch rec "$REC_NAME" -n "$NAMESPACE" --patch-file /tmp/rec-license-patch.yaml --type=merge

        # Clean up
        rm /tmp/rec-license-patch.yaml
    fi

    echo "License update completed successfully."
    echo "The Redis Enterprise Cluster will use the new license after a few moments."
}

# Function to update the license directly in the REC custom resource
update_license_inline() {
    check_license_file

    echo "Reading license from $LICENSE_FILE..."
    LICENSE_CONTENT=$(cat "$LICENSE_FILE")

    echo "Updating Redis Enterprise Cluster with inline license..."

    # Create a patch to update the license field
    cat <<EOF > /tmp/rec-license-patch.yaml
spec:
  license: |
$(sed 's/^/    /' "$LICENSE_FILE")
EOF

    # Apply the patch
    kubectl patch rec "$REC_NAME" -n "$NAMESPACE" --patch-file /tmp/rec-license-patch.yaml --type=merge

    # Clean up
    rm /tmp/rec-license-patch.yaml

    echo "License update completed successfully."
    echo "The Redis Enterprise Cluster will use the new license after a few moments."
}

# Main script logic
case "$1" in
    --secret)
        update_license_secret
        ;;
    --inline)
        update_license_inline
        ;;
    --help)
        show_usage
        ;;
    *)
        echo "Error: Invalid option."
        show_usage
        exit 1
        ;;
esac

# Provide instructions for verifying the license
echo ""
echo "To verify the license update, you can:"
echo "1. Check the Redis Enterprise Cluster status:"
echo "   kubectl get rec $REC_NAME -n $NAMESPACE"
echo ""
echo "2. Access the Redis Enterprise Cluster UI and check the license information:"
echo "   ./port-forward-rec-ui.sh"
echo "   Then open https://localhost:8443 in your browser and navigate to the license page."
